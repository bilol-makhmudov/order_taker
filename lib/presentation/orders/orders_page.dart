import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/product.dart';
import '../../services/voice_order/voice_order_parser.dart';
import 'orders_viewmodel.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  OrdersViewModel? _vm;
  StreamSubscription<OrdersUiEvent>? _sub;
  bool _initialized = false;
  bool _pressed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;

    final scope = AppScope.of(context);

    final vm = OrdersViewModel(
      orderRepository: scope.orderRepository,
      voskService: scope.voskService,
      voiceOrderParser: scope.voiceOrderParser,
      products: scope.products,
    );

    _sub = vm.events.listen((e) async {
      if (!mounted) return;

      if (e is OrdersShowMessage) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } else if (e is OrdersNeedDisambiguation) {
        await _showDisambiguationSheet(vm, e.line);
      }
    });

    _vm = vm;
    _initialized = true;
  }

  @override
  void dispose() {
    _sub?.cancel();
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
        final draft = vm.currentOrder;
        final items = draft.items;

        return Scaffold(
          appBar: AppBar(title: const Text('My Orders')),
          floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
          floatingActionButton: _HoldToTalkButton(
            isListening: vm.isListening,
            pressed: _pressed,
            onPressStart: () async {
              setState(() => _pressed = true);
              await vm.startVoice();
            },
            onPressEnd: () async {
              setState(() => _pressed = false);
              await vm.stopVoice();
            },
          ),
          body: Column(
            children: [
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Draft is empty. Add items from Products or hold mic to speak.'))
                    : ListView.separated(
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _OrderItemTile(
                    item: items[i],
                    onInc: () => vm.inc(items[i]),
                    onDec: () => vm.dec(items[i]),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showDisambiguationSheet(OrdersViewModel vm, VoiceOrderLine line) async {
    final candidates = line.match.candidates;
    if (candidates.isEmpty) return;

    final selected = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Which product did you mean?', style: Theme.of(ctx).textTheme.titleMedium),
                const SizedBox(height: 6),
                Text('Heard: "${line.match.query}"  •  Qty: ${line.quantity}'),
                const SizedBox(height: 12),
                ...candidates.map((c) {
                  final p = c.product;
                  return ListTile(
                    title: Text(p.canonicalName),
                    subtitle: Text('${p.category} • score ${c.score}'),
                    onTap: () => Navigator.of(ctx).pop(p),
                  );
                }),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) vm.applyDisambiguation(line, selected);
  }
}

class _HoldToTalkButton extends StatelessWidget {
  final bool isListening;
  final bool pressed;
  final Future<void> Function() onPressStart;
  final Future<void> Function() onPressEnd;

  const _HoldToTalkButton({
    required this.isListening,
    required this.pressed,
    required this.onPressStart,
    required this.onPressEnd,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onPressStart(),
      onTapUp: (_) => onPressEnd(),
      onTapCancel: () => onPressEnd(),
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        scale: pressed ? 0.92 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: pressed ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.secondaryContainer,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                blurRadius: pressed ? 10 : 16,
                spreadRadius: pressed ? 0 : 2,
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.mic : Icons.mic_none,
            color: pressed ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSecondaryContainer,
            size: 30,
          ),
        ),
      ),
    );
  }
}

class _OrderItemTile extends StatelessWidget {
  final OrderItem item;
  final VoidCallback onInc;
  final VoidCallback onDec;

  const _OrderItemTile({required this.item, required this.onInc, required this.onDec});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(item.product.canonicalName),
      subtitle: Text('${item.product.price.toStringAsFixed(0)} each'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: onDec),
          Text('${item.quantity}', style: Theme.of(context).textTheme.titleMedium),
          IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: onInc),
        ],
      ),
    );
  }
}
