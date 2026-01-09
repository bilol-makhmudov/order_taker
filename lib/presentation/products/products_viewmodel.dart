import 'package:flutter/foundation.dart';

import '../../data/repositories/order_repository.dart';
import '../../domain/models/product.dart';

class ProductsViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final List<Product> _allProducts;

  String _query = '';

  ProductsViewModel({required OrderRepository orderRepository, required List<Product> products})
      : _orderRepo = orderRepository,
        _allProducts = products {
    _orderRepo.addListener(_onRepoChanged);
  }

  String get query => _query;

  List<Product> get products {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _allProducts;

    return _allProducts.where((p) {
      final name = p.canonicalName.toLowerCase();
      if (name.contains(q)) return true;

      for (final a in p.aliases) {
        if (a.toLowerCase().contains(q)) return true;
      }
      for (final k in p.keywords) {
        if (k.toLowerCase().contains(q)) return true;
      }
      return false;
    }).toList();
  }

  int get currentDraftItemCount {
    final items = _orderRepo.currentOrder.items;
    return items.fold(0, (sum, x) => sum + x.quantity);
  }

  void setQuery(String value) {
    _query = value;
    notifyListeners();
  }

  void addToOrder(Product product, {int quantity = 1}) {
    _orderRepo.addProduct(product, quantity: quantity);
  }

  void _onRepoChanged() => notifyListeners();

  @override
  void dispose() {
    _orderRepo.removeListener(_onRepoChanged);
    super.dispose();
  }
}
