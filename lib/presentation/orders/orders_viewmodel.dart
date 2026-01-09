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

  bool _isListening = false;
  bool get isListening => _isListening;

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

  void add(Product p) => _orderRepo.addProduct(p, quantity: 1);
  void inc(OrderItem item) => _orderRepo.addProduct(item.product, quantity: 1);
  void dec(OrderItem item) => _orderRepo.removeProduct(item.product.id, quantity: 1);

  Future<void> startVoice() async {
    if (_isListening) return;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _events.add(OrdersShowMessage('Microphone permission is required.'));
      return;
    }

    _isListening = true;
    notifyListeners();

    try {
      await _vosk.start();
    } catch (e) {
      _isListening = false;
      notifyListeners();
      _events.add(OrdersShowMessage('Voice start failed.'));
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

  void _onSpeechResult(SpeechResult r) {
    if (!_isListening) return;
    if (!r.isFinal) return;

    final parsed = _parser.parse(r.text, _products);

    if (parsed.action != VoiceOrderActionType.addItems) return;

    var addedAny = false;
    var ambiguousAny = false;

    for (final line in parsed.lines) {
      final match = line.match;

      if (line.product != null) {
        _orderRepo.addProduct(line.product!, quantity: line.quantity);
        addedAny = true;
        continue;
      }

      if (match.candidates.isEmpty) continue;

      final best = match.best;
      if (best == null) continue;

      if (match.isConfident) {
        _orderRepo.addProduct(best.product, quantity: line.quantity);
        addedAny = true;
        continue;
      }

      if (best.score >= 55) {
        ambiguousAny = true;
        _events.add(OrdersNeedDisambiguation(line));
      }
    }

    if (!addedAny && !ambiguousAny) {
      _events.add(OrdersShowMessage('Could not confidently match any product.'));
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
