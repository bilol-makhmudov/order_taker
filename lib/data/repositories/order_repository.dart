import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/product.dart';

abstract class OrderRepository {
  Order get currentOrder;
  List<Order> get orders;

  void addProduct(Product product, {int quantity = 1});
  void removeProduct(int productId, {int quantity = 1});
  void clearCurrentOrder();

  /// Creates a new order from current draft and resets draft.
  /// Returns the created order.
  Order submitCurrentOrder();

  /// Simple listener pattern for MVVM without extra packages.
  void addListener(void Function() listener);
  void removeListener(void Function() listener);
}

class InMemoryOrderRepository implements OrderRepository {
  final List<void Function()> _listeners = [];
  final List<Order> _orders = [];

  int _nextOrderId = 1;
  Order _currentOrder = Order(id: 0, createdAt: DateTime.now(), items: []);

  @override
  Order get currentOrder => _currentOrder;

  @override
  List<Order> get orders => List.unmodifiable(_orders);

  @override
  void addProduct(Product product, {int quantity = 1}) {
    if (quantity <= 0) return;

    final existing = _currentOrder.items.where((x) => x.product.id == product.id).toList();
    if (existing.isNotEmpty) {
      existing.first.quantity += quantity;
    } else {
      _currentOrder.items.add(OrderItem(product: product, quantity: quantity));
    }

    _notify();
  }

  @override
  void removeProduct(int productId, {int quantity = 1}) {
    if (quantity <= 0) return;

    final index = _currentOrder.items.indexWhere((x) => x.product.id == productId);
    if (index < 0) return;

    final item = _currentOrder.items[index];
    item.quantity -= quantity;

    if (item.quantity <= 0) {
      _currentOrder.items.removeAt(index);
    }

    _notify();
  }

  @override
  void clearCurrentOrder() {
    _currentOrder = Order(id: 0, createdAt: DateTime.now(), items: []);
    _notify();
  }

  @override
  Order submitCurrentOrder() {
    if (_currentOrder.items.isEmpty) {
      return _currentOrder;
    }

    final created = Order(
      id: _nextOrderId++,
      createdAt: DateTime.now(),
      items: _currentOrder.items
          .map((x) => OrderItem(product: x.product, quantity: x.quantity))
          .toList(),
    );

    _orders.insert(0, created);
    _currentOrder = Order(id: 0, createdAt: DateTime.now(), items: []);

    _notify();
    return created;
  }

  @override
  void addListener(void Function() listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notify() {
    for (final l in List<void Function()>.from(_listeners)) {
      l();
    }
  }
}
