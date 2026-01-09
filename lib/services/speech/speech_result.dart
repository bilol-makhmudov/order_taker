class SpeechResult {
  final String text;
  final bool isFinal;
  final Map<String, dynamic>? raw;

  const SpeechResult({required this.text, required this.isFinal, this.raw});
}