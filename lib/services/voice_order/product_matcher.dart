import '../../core/text/tr_nomalizer.dart';
import '../../domain/models/product.dart';

class ProductCandidate {
  final Product product;
  final int score;

  const ProductCandidate({required this.product, required this.score});
}

class ProductMatchResult {
  final String query;
  final ProductCandidate? best;
  final List<ProductCandidate> candidates;

  const ProductMatchResult({required this.query, required this.best, required this.candidates});

  bool get hasMatch => best != null && best!.score > 0;

  /// Confidence heuristic:
  /// - if best is significantly higher than #2, we can auto-pick
  bool get isConfident {
    if (best == null) return false;
    if (candidates.length < 2) return best!.score >= 60;
    return (best!.score - candidates[1].score) >= 20 && best!.score >= 60;
  }
}

class ProductMatcher {
  const ProductMatcher();

  ProductMatchResult matchOne(String rawQuery, List<Product> products, {int topN = 3}) {
    final query = TrNormalizer.normalize(rawQuery);
    final qTokens = _tokens(query);

    final scored = <ProductCandidate>[];

    for (final p in products) {
      final score = _scoreProduct(query, qTokens, p);
      if (score > 0) scored.add(ProductCandidate(product: p, score: score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(topN).toList(growable: false);
    final best = top.isEmpty ? null : top.first;

    return ProductMatchResult(query: query, best: best, candidates: top);
  }

  int _scoreProduct(String query, Set<String> qTokens, Product p) {
    final canonical = TrNormalizer.normalize(p.canonicalName);

    final aliasList = p.aliases.map(TrNormalizer.normalize).toList(growable: false);
    final keywordList = p.keywords.map(TrNormalizer.normalize).toList(growable: false);

    // 1) Exact alias inclusion: "kola" in query
    for (final a in aliasList) {
      if (a.isEmpty) continue;
      if (_containsWholeWord(query, a)) return 100;
    }

    // 2) Canonical inclusion (less strong than alias)
    if (canonical.isNotEmpty && _containsWholeWord(query, canonical)) return 80;

    // 3) Token overlap (query tokens vs product tokens)
    final pTokens = <String>{..._tokens(canonical)};
    for (final a in aliasList) {
      pTokens.addAll(_tokens(a));
    }
    for (final k in keywordList) {
      pTokens.addAll(_tokens(k));
    }

    final overlap = qTokens.intersection(pTokens).length;
    var score = overlap * 10;

    // 4) Keyword boost if query contains any keyword as a whole word
    for (final k in keywordList) {
      if (k.isEmpty) continue;
      if (_containsWholeWord(query, k)) score += 15;
    }

    // 5) Fuzzy similarity for typos / slight variations
    // Use best distance among aliases + canonical.
    final candidates = <String>[canonical, ...aliasList];
    int bestDist = 999;
    String bestStr = canonical;

    for (final s in candidates) {
      if (s.isEmpty) continue;
      final d = _levenshtein(query, s);
      if (d < bestDist) {
        bestDist = d;
        bestStr = s;
      }
    }

    // Convert distance to bonus (lower distance => higher bonus)
    // Clamp so it doesn't dominate overlap scoring.
    final maxLen = bestStr.length > query.length ? bestStr.length : query.length;
    if (maxLen > 0) {
      final similarity = (maxLen - bestDist) / maxLen; // 0..1
      final fuzzyBonus = (similarity * 30).round(); // 0..30
      score += fuzzyBonus;
    }

    return score;
  }

  bool _containsWholeWord(String text, String phrase) {
    final escaped = RegExp.escape(phrase);
    final re = RegExp(r'(^|\s)' + escaped + r'($|\s)');
    return re.hasMatch(text);
  }

  Set<String> _tokens(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^a-z0-9ığüşöçı\s]'), ' ');
    final parts = cleaned.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    return parts.toSet();
  }

  int _levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    final m = a.length;
    final n = b.length;

    final prev = List<int>.generate(n + 1, (j) => j);
    final curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      final ca = a.codeUnitAt(i - 1);

      for (var j = 1; j <= n; j++) {
        final cb = b.codeUnitAt(j - 1);
        final cost = (ca == cb) ? 0 : 1;

        final del = prev[j] + 1;
        final ins = curr[j - 1] + 1;
        final sub = prev[j - 1] + cost;

        curr[j] = _min3(del, ins, sub);
      }

      for (var j = 0; j <= n; j++) {
        prev[j] = curr[j];
      }
    }

    return prev[n];
  }

  int _min3(int a, int b, int c) {
    final ab = a < b ? a : b;
    return ab < c ? ab : c;
  }
}
