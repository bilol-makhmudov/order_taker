import 'package:flutter/material.dart';

import '../presentation/orders/orders_page.dart';
import 'app_scope.dart';
import '../presentation/products/products_page.dart';

class OrderTakerApp extends StatelessWidget {
  const OrderTakerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScope.create(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Order Taker',
        theme: ThemeData(useMaterial3: true),
        home: const _HomeShell(),
      ),
    );
  }
}

class _HomeShell extends StatefulWidget {
  const _HomeShell();

  @override
  State<_HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<_HomeShell> {
  int _index = 0;
  bool _voskInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_voskInit) return;
    _voskInit = true;

    final scope = AppScope.of(context);
    scope.voskService.init(modelAssetDir: 'assets/models/vosk-tr', sampleRate: 16000);
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const ProductsPage(),
      const OrdersPage(),
    ];

    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.storefront), label: 'Products'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long), label: 'My Orders'),
        ],
      ),
    );
  }
}
