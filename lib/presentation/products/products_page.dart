import 'package:flutter/material.dart';
import 'package:order_taker/presentation/products/products_viewmodel.dart';

import '../../app/app_scope.dart';
import '../../domain/models/product.dart';

class ProductsPage extends StatefulWidget {
  const ProductsPage({super.key});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  ProductsViewModel? _vm;
  final TextEditingController _search = TextEditingController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => _vm?.setQuery(_search.text));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final scope = AppScope.of(context);
    _vm = ProductsViewModel(orderRepository: scope.orderRepository, products: scope.products);

    _initialized = true;
  }

  @override
  void dispose() {
    _search.dispose();
    _vm?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = _vm;
    if (vm == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: vm,
      builder: (context, _) {
        final items = vm.products;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Products'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: Badge(
                    label: Text('${vm.currentDraftItemCount}'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search product...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) => _ProductTile(
                    product: items[i],
                    onAdd: (p) {
                      vm.addToOrder(p);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Added: ${p.canonicalName}')),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product product;
  final void Function(Product product) onAdd;

  const _ProductTile({required this.product, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.canonicalName),
      subtitle: Text('${product.category} • ${product.price.toStringAsFixed(0)}'),
      trailing: IconButton(
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => onAdd(product),
      ),
    );
  }
}
