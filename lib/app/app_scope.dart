import 'package:flutter/widgets.dart';

import '../data/mock/mock_products.dart';
import '../data/repositories/order_repository.dart';
import '../domain/models/product.dart';
import '../services/speech/vosk_service.dart';
import '../services/voice_order/voice_order_parser.dart';
import '../services/voice_order/product_matcher.dart';

class AppScope extends InheritedWidget {
  final OrderRepository orderRepository;
  final VoskService voskService;
  final VoiceOrderParser voiceOrderParser;
  final ProductMatcher productMatcher;
  final List<Product> products;

  const AppScope({
    super.key,
    required this.orderRepository,
    required this.voskService,
    required this.voiceOrderParser,
    required this.productMatcher,
    required this.products,
    required super.child,
  });

  static AppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    if (scope == null) throw StateError('AppScope not found in widget tree.');
    return scope;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return false;
  }

  static AppScope create({required Widget child}) {
    final repo = InMemoryOrderRepository();
    final matcher = const ProductMatcher();
    final parser = VoiceOrderParser(matcher: matcher);

    return AppScope(
      orderRepository: repo,
      voskService: VoskServiceImpl(),
      voiceOrderParser: parser,
      productMatcher: matcher,
      products: MockProducts.items,
      child: child,
    );
  }
}
