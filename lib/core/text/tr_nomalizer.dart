class TrNormalizer {
  static final Map<String, String> _numberWords = {
    'sıfır': '0',
    'bir': '1',
    'iki': '2',
    'üç': '3',
    'uc': '3',
    'dört': '4',
    'dort': '4',
    'beş': '5',
    'bes': '5',
    'altı': '6',
    'alti': '6',
    'yedi': '7',
    'sekiz': '8',
    'dokuz': '9',
    'on': '10',
  };

  /// Main entry point
  static String normalize(String input) {
    if (input.isEmpty) return input;

    var text = _toTurkishLower(input);
    text = _removePunctuation(text);
    text = _replaceNumberWords(text);
    text = _normalizeWhitespace(text);

    return text.trim();
  }

  /// Turkish-safe lowercase
  static String _toTurkishLower(String input) {
    return input
        .replaceAll('İ', 'i')
        .replaceAll('I', 'ı')
        .toLowerCase();
  }

  /// Removes punctuation but keeps digits and letters
  static String _removePunctuation(String input) {
    return input.replaceAll(RegExp(r'[^\w\s]'), ' ');
  }

  /// Converts "iki", "üç" → "2", "3"
  static String _replaceNumberWords(String input) {
    var words = input.split(' ');
    for (var i = 0; i < words.length; i++) {
      final normalized = words[i]
          .replaceAll('ş', 's')
          .replaceAll('ç', 'c')
          .replaceAll('ğ', 'g')
          .replaceAll('ö', 'o')
          .replaceAll('ü', 'u');

      if (_numberWords.containsKey(words[i])) {
        words[i] = _numberWords[words[i]]!;
      } else if (_numberWords.containsKey(normalized)) {
        words[i] = _numberWords[normalized]!;
      }
    }
    return words.join(' ');
  }

  /// Cleans extra spaces
  static String _normalizeWhitespace(String input) {
    return input.replaceAll(RegExp(r'\s+'), ' ');
  }
}
