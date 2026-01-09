import 'order_item.dart';

class Order {
  final int id;
  final DateTime createdAt;
  final List<OrderItem> items;

  Order({required this.id, required this.createdAt, required this.items});

  double get total => items.fold(0, (sum, x) => sum + (x.product.price * x.quantity));
}
