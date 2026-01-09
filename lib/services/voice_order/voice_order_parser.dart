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

  bool get hasAdditions => action == VoiceOrderActionType.addItems && lines.isNotEmpty;

  bool get hasAmbiguity => lines.any((x) => x.product == null && x.match.candidates.isNotEmpty);
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

    final chunks = _splitIntoChunks(normalized);

    final lines = <VoiceOrderLine>[];
    for (final chunk in chunks) {
      final trimmed = chunk.trim();
      if (trimmed.isEmpty) continue;

      final extracted = _extractQuantityAndPhrase(trimmed);
      final qty = extracted.quantity;
      final phrase = extracted.phrase;

      if (phrase.isEmpty) continue;

      final match = _matcher.matchOne(phrase, products, topN: 3);

      final selected = match.isConfident ? match.best?.product : null;

      lines.add(VoiceOrderLine(quantity: qty, product: selected, match: match));
    }

    if (lines.isEmpty) {
      return VoiceOrderParseResult(action: VoiceOrderActionType.none, normalizedText: normalized, lines: const []);
    }

    return VoiceOrderParseResult(action: VoiceOrderActionType.addItems, normalizedText: normalized, lines: lines);
  }

  bool _isUndo(String text) {
    // Common Turkish undo phrases
    return text == 'iptal' ||
        text == 'geri al' ||
        text == 'son ekleneni sil' ||
        text == 'sonuncuyu sil' ||
        text == 'sonu sil';
  }

  bool _isClear(String text) {
    // Clear draft order
    return text == 'temizle' ||
        text == 'siparişi temizle' ||
        text == 'siparis temizle' ||
        text == 'hepsini sil' ||
        text == 'tümünü sil' ||
        text == 'tumunu sil';
  }

  List<String> _splitIntoChunks(String normalized) {
    final replaced = normalized
        .replaceAll(' ile ', ' ve ')
        .replaceAll(' artı ', ' ve ')
        .replaceAll(' arti ', ' ve ')
        .replaceAll(' ayrıca ', ' ve ')
        .replaceAll(' ayrica ', ' ve ');

    return replaced.split(' ve ');
  }

  _QtyPhrase _extractQuantityAndPhrase(String chunk) {
    // Patterns supported:
    // - "2 su"
    // - "2 tane su"
    // - "su 2 tane" (limited support)
    // - default quantity = 1

    final parts = chunk.split(RegExp(r'\s+')).where((x) => x.isNotEmpty).toList();
    if (parts.isEmpty) return const _QtyPhrase(quantity: 1, phrase: '');

    // If first token is digit => quantity
    final first = parts.first;
    final q1 = int.tryParse(first);
    if (q1 != null && q1 > 0) {
      // Remove optional filler words after quantity
      final rest = parts.skip(1).where((x) => !_isFiller(x)).toList();
      return _QtyPhrase(quantity: q1, phrase: rest.join(' '));
    }

    // If chunk contains "... 2 tane" at end
    if (parts.length >= 2) {
      final last = parts.last;
      final q2 = int.tryParse(last);
      if (q2 != null && q2 > 0) {
        final before = parts.take(parts.length - 1).where((x) => !_isFiller(x)).toList();
        return _QtyPhrase(quantity: q2, phrase: before.join(' '));
      }
    }

    // default
    final phrase = parts.where((x) => !_isFiller(x)).join(' ');
    return _QtyPhrase(quantity: 1, phrase: phrase);
  }

  bool _isFiller(String token) {
    // Turkish filler words that often appear in speech commands
    return token == 'tane' || token == 'adet' || token == 'bir' || token == 'lütfen' || token == 'lutfen';
  }
}

class _QtyPhrase {
  final int quantity;
  final String phrase;

  const _QtyPhrase({required this.quantity, required this.phrase});
}
