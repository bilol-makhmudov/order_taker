import '../../domain/models/product.dart';

class MockProducts {
  static final List<Product> items = [
    Product(
      id: 1,
      canonicalName: 'Su 0.5L',
      category: 'Drink',
      price: 10,
      aliases: [
        'su',
        'küçük su',
        'yarım litre su',
        '0.5 su',
        'pet su',
      ],
      keywords: ['su', 'küçük'],
    ),
    Product(
      id: 2,
      canonicalName: 'Su 1.5L',
      category: 'Drink',
      price: 18,
      aliases: [
        'büyük su',
        '1.5 litre su',
        '1.5 su',
        'litrelik su',
      ],
      keywords: ['su', 'büyük'],
    ),
    Product(
      id: 3,
      canonicalName: 'Coca-Cola',
      category: 'Drink',
      price: 35,
      aliases: [
        'kola',
        'coca cola',
        'coca',
        'kolaa',
      ],
      keywords: ['kola'],
    ),
    Product(
      id: 4,
      canonicalName: 'Fanta',
      category: 'Drink',
      price: 35,
      aliases: [
        'fanta',
        'portakal gazoz',
      ],
      keywords: ['fanta', 'portakal'],
    ),
    Product(
      id: 5,
      canonicalName: 'Ayran',
      category: 'Drink',
      price: 25,
      aliases: [
        'ayran',
        'yayık ayran',
      ],
      keywords: ['ayran'],
    ),
    Product(
      id: 6,
      canonicalName: 'Türk Kahvesi',
      category: 'Hot Drink',
      price: 45,
      aliases: [
        'türk kahvesi',
        'kahve',
        'türk',
      ],
      keywords: ['kahve'],
    ),
    Product(
      id: 7,
      canonicalName: 'Filtre Kahve',
      category: 'Hot Drink',
      price: 55,
      aliases: [
        'filtre kahve',
        'filtre',
        'americano',
      ],
      keywords: ['kahve', 'filtre'],
    ),
    Product(
      id: 8,
      canonicalName: 'Çay',
      category: 'Hot Drink',
      price: 15,
      aliases: [
        'çay',
        'cay',
        'demli çay',
      ],
      keywords: ['çay'],
    ),
  ];
}
