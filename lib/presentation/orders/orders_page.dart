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
          appBar: AppBar(
            title: const Text('My Orders'),
            actions: [
              IconButton(
                tooltip: vm.isListening ? 'Stop voice' : 'Start voice',
                icon: Icon(vm.isListening ? Icons.mic_off : Icons.mic),
                onPressed: () => vm.isListening ? vm.stopVoice() : vm.startVoice(),
              ),
            ],
          ),
          body: Column(
            children: [
              if (vm.isListening || vm.lastPartial.isNotEmpty || vm.lastFinal.isNotEmpty)
                _VoicePanel(
                  isListening: vm.isListening,
                  partial: vm.lastPartial,
                  finalText: vm.lastFinal,
                ),
              Expanded(
                child: items.isEmpty
                    ? const Center(child: Text('Draft is empty. Add items from Products or use voice.'))
                    : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _OrderItemTile(
                    item: items[i],
                    onInc: () => vm.inc(items[i]),
                    onDec: () => vm.dec(items[i]),
                  ),
                ),
              ),
              _BottomBar(
                total: draft.total,
                hasItems: items.isNotEmpty,
                onClear: vm.clearDraft,
                onSubmit: vm.submitDraft,
                onUndo: vm.undoLastLineItem,
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

    if (selected != null) {
      vm.applyDisambiguation(line, selected);
    }
  }
}

class _VoicePanel extends StatelessWidget {
  final bool isListening;
  final String partial;
  final String finalText;

  const _VoicePanel({required this.isListening, required this.partial, required this.finalText});

  @override
  Widget build(BuildContext context) {
    final show = partial.isNotEmpty ? partial : finalText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(isListening ? Icons.mic : Icons.mic_none),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              show.isEmpty ? (isListening ? 'Listening...' : '') : show,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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

class _BottomBar extends StatelessWidget {
  final double total;
  final bool hasItems;
  final VoidCallback onClear;
  final VoidCallback onSubmit;
  final VoidCallback onUndo;

  const _BottomBar({
    required this.total,
    required this.hasItems,
    required this.onClear,
    required this.onSubmit,
    required this.onUndo,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text('Total: ${total.toStringAsFixed(0)}', style: Theme.of(context).textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'Undo last',
              onPressed: hasItems ? onUndo : null,
              icon: const Icon(Icons.undo),
            ),
            TextButton(onPressed: hasItems ? onClear : null, child: const Text('Clear')),
            const SizedBox(width: 8),
            FilledButton(onPressed: hasItems ? onSubmit : null, child: const Text('Submit')),
          ],
        ),
      ),
    );
  }
}
