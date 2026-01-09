import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../data/repositories/order_repository.dart';
import '../../domain/models/order.dart';
import '../../domain/models/order_item.dart';
import '../../domain/models/product.dart';
import '../../services/speech/speech_result.dart';
import '../../services/speech/vosk_service.dart';
import '../../services/voice_order/voice_order_parser.dart';

sealed class OrdersUiEvent {}

class OrdersShowMessage extends OrdersUiEvent {
  final String message;

  OrdersShowMessage(this.message);
}

class OrdersNeedDisambiguation extends OrdersUiEvent {
  final VoiceOrderLine line;

  OrdersNeedDisambiguation(this.line);
}

class OrdersViewModel extends ChangeNotifier {
  final OrderRepository _orderRepo;
  final VoskService _vosk;
  final VoiceOrderParser _parser;
  final List<Product> _products;

  final StreamController<OrdersUiEvent> _events = StreamController<OrdersUiEvent>.broadcast();
  Stream<OrdersUiEvent> get events => _events.stream;

  StreamSubscription<SpeechResult>? _speechSub;

  String _lastPartial = '';
  String _lastFinal = '';
  bool _isListening = false;

  OrdersViewModel({
    required OrderRepository orderRepository,
    required VoskService voskService,
    required VoiceOrderParser voiceOrderParser,
    required List<Product> products,
  })  : _orderRepo = orderRepository,
        _vosk = voskService,
        _parser = voiceOrderParser,
        _products = products {
    _orderRepo.addListener(_onRepoChanged);
    _speechSub = _vosk.results.listen(_onSpeechResult);
  }

  Order get currentOrder => _orderRepo.currentOrder;
  List<Order> get orders => _orderRepo.orders;

  bool get isListening => _isListening;
  String get lastPartial => _lastPartial;
  String get lastFinal => _lastFinal;

  void add(Product p) => _orderRepo.addProduct(p, quantity: 1);
  void inc(OrderItem item) => _orderRepo.addProduct(item.product, quantity: 1);
  void dec(OrderItem item) => _orderRepo.removeProduct(item.product.id, quantity: 1);

  void clearDraft() => _orderRepo.clearCurrentOrder();

  void submitDraft() {
    final created = _orderRepo.submitCurrentOrder();
    if (created.items.isEmpty) {
      _events.add(OrdersShowMessage('Draft is empty.'));
    } else {
      _events.add(OrdersShowMessage('Order #${created.id} submitted.'));
    }
  }

  Future<void> startVoice() async {
    if (_isListening) return;

    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      _events.add(OrdersShowMessage('Microphone permission is required.'));
      return;
    }

    _lastPartial = '';
    _lastFinal = '';
    _isListening = true;
    notifyListeners();

    try {
      await _vosk.start();
    } catch (e) {
      _isListening = false;
      notifyListeners();
      _events.add(OrdersShowMessage('Voice start failed: $e'));
    }
  }

  Future<void> stopVoice() async {
    if (!_isListening) return;
    try {
      await _vosk.stop();
    } finally {
      _isListening = false;
      notifyListeners();
    }
  }

  void applyDisambiguation(VoiceOrderLine line, Product selected) {
    _orderRepo.addProduct(selected, quantity: line.quantity);
    _events.add(OrdersShowMessage('Added: ${line.quantity} × ${selected.canonicalName}'));
  }

  void undoLastLineItem() {
    final items = _orderRepo.currentOrder.items;
    if (items.isEmpty) {
      _events.add(OrdersShowMessage('Nothing to undo.'));
      return;
    }
    final last = items.last;
    _orderRepo.removeProduct(last.product.id, quantity: last.quantity);
    _events.add(OrdersShowMessage('Removed: ${last.product.canonicalName}'));
  }

  void _onSpeechResult(SpeechResult r) {
    if (!_isListening) return;

    if (!r.isFinal) {
      _lastPartial = r.text;
      notifyListeners();
      return;
    }

    _lastFinal = r.text;
    _lastPartial = '';
    notifyListeners();

    final parsed = _parser.parse(r.text, _products);

    switch (parsed.action) {
      case VoiceOrderActionType.undoLast:
        undoLastLineItem();
        break;
      case VoiceOrderActionType.clearDraft:
        clearDraft();
        _events.add(OrdersShowMessage('Draft cleared.'));
        break;
      case VoiceOrderActionType.addItems:
        for (final line in parsed.lines) {
          if (line.product != null) {
            _orderRepo.addProduct(line.product!, quantity: line.quantity);
          } else if (line.match.candidates.isNotEmpty) {
            _events.add(OrdersNeedDisambiguation(line));
          } else {
            _events.add(OrdersShowMessage('No match for: "${line.match.query}"'));
          }
        }
        break;
      case VoiceOrderActionType.none:
        _events.add(OrdersShowMessage('Could not understand.'));
        break;
    }
  }

  void _onRepoChanged() => notifyListeners();

  @override
  void dispose() {
    _orderRepo.removeListener(_onRepoChanged);
    _speechSub?.cancel();
    _events.close();
    super.dispose();
  }
}
