import '../../core/text/tr_nomalizer.dart';
import '../../domain/models/product.dart';
import 'product_matcher.dart';

enum VoiceOrderActionType { addItems, undoLast, clearDraft, none }

class VoiceOrderLine {
  final int quantity;
  final Product? product;
  final ProductMatchResult match;

  const VoiceOrderLine({required this.quantity, required this.product, required this.match});
}

class VoiceOrderParseResult {
  final VoiceOrderActionType action;
  final String normalizedText;
  final List<VoiceOrderLine> lines;

  const VoiceOrderParseResult({
    required this.action,
    required this.normalizedText,
    required this.lines,
  });
}

class VoiceOrderParser {
  final ProductMatcher _matcher;

  const VoiceOrderParser({ProductMatcher? matcher}) : _matcher = matcher ?? const ProductMatcher();

  VoiceOrderParseResult parse(String rawText, List<Product> products) {
    final normalized = TrNormalizer.normalize(rawText);

    if (_isUndo(normalized)) {
      return VoiceOrderParseResult(action: VoiceOrderActionType.undoLast, normalizedText: normalized, lines: const []);
    }
    if (_isClear(normalized)) {
      return VoiceOrderParseResult(action: VoiceOrderActionType.clearDraft, normalizedText: normalized, lines: const []);
    }

    final extracted = _extractLines(normalized);

    final lines = <VoiceOrderLine>[];
    for (final x in extracted) {
      final phrase = x.phrase.trim();
      if (phrase.isEmpty) continue;

      final match = _matcher.matchOne(phrase, products, topN: 3);
      final selected = match.isConfident ? match.best?.product : null;

      lines.add(VoiceOrderLine(quantity: x.quantity, product: selected, match: match));
    }

    if (lines.isEmpty) {
      return VoiceOrderParseResult(action: VoiceOrderActionType.none, normalizedText: normalized, lines: const []);
    }

    return VoiceOrderParseResult(action: VoiceOrderActionType.addItems, normalizedText: normalized, lines: lines);
  }

  List<_ExtractedLine> _extractLines(String normalized) {
    final cleaned = normalized
        .replaceAll(',', ' ')
        .replaceAll(';', ' ')
        .replaceAll(':', ' ')
        .replaceAll(' ile ', ' ')
        .replaceAll(' ve ', ' ')
        .replaceAll(' artı ', ' ')
        .replaceAll(' arti ', ' ')
        .replaceAll(' ayrıca ', ' ')
        .replaceAll(' ayrica ', ' ');

    final tokens = cleaned.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    if (tokens.isEmpty) return const [];

    final lines = <_ExtractedLine>[];

    int? currentQty;
    final currentPhrase = <String>[];

    void flush() {
      final qty = currentQty ?? 1;
      final phrase = currentPhrase.where((x) => !_isFiller(x)).join(' ').trim();
      if (phrase.isNotEmpty) lines.add(_ExtractedLine(quantity: qty, phrase: phrase));
      currentQty = null;
      currentPhrase.clear();
    }

    for (final t in tokens) {
      final n = int.tryParse(t);
      if (n != null && n > 0) {
        if (currentPhrase.isNotEmpty) flush();
        currentQty = n;
        continue;
      }

      currentPhrase.add(t);
    }

    if (currentPhrase.isNotEmpty) flush();

    return lines;
  }

  bool _isUndo(String text) {
    return text == 'iptal' ||
        text == 'geri al' ||
        text == 'son ekleneni sil' ||
        text == 'sonuncuyu sil' ||
        text == 'sonu sil';
  }

  bool _isClear(String text) {
    return text == 'temizle' ||
        text == 'siparişi temizle' ||
        text == 'siparis temizle' ||
        text == 'hepsini sil' ||
        text == 'tümünü sil' ||
        text == 'tumunu sil';
  }

  bool _isFiller(String token) {
    return token == 'tane' || token == 'adet' || token == 'bir' || token == 'lütfen' || token == 'lutfen';
  }
}

class _ExtractedLine {
  final int quantity;
  final String phrase;

  const _ExtractedLine({required this.quantity, required this.phrase});
}
