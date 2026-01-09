class Product {
  final int id;
  final String canonicalName;
  final String category;
  final List<String> aliases;
  final List<String> keywords;
  final double price;

  const Product({
    required this.id,
    required this.canonicalName,
    required this.category,
    required this.aliases,
    required this.keywords,
    required this.price,
  });
}
