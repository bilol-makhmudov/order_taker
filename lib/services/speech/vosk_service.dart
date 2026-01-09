import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/enums/speech_status.dart';
import 'speech_result.dart';

abstract class VoskService {
  SpeechStatus get status;
  Stream<SpeechResult> get results;

  Future<void> init({required String modelAssetDir, int sampleRate = 16000});
  Future<void> start();
  Future<void> stop();
  Future<void> dispose();
}

class VoskServiceImpl implements VoskService {
  static const MethodChannel _method = MethodChannel('order_taker/vosk');
  static const EventChannel _events = EventChannel('order_taker/vosk_events');

  final StreamController<SpeechResult> _controller = StreamController<SpeechResult>.broadcast();
  StreamSubscription<dynamic>? _eventSub;

  SpeechStatus _status = SpeechStatus.idle;

  @override
  SpeechStatus get status => _status;

  @override
  Stream<SpeechResult> get results => _controller.stream;

  @override
  Future<void> init({required String modelAssetDir, int sampleRate = 16000}) async {
    final modelPath = await _ensureModelExtracted(modelAssetDir);
    await _method.invokeMethod('init', {'modelPath': modelPath, 'sampleRate': sampleRate});

    _eventSub ??= _events.receiveBroadcastStream().listen(
          (event) {
        if (event is Map) {
          final text = (event['text'] as String?) ?? '';
          final isFinal = (event['isFinal'] as bool?) ?? false;
          final raw = (event['raw'] is Map) ? Map<String, dynamic>.from(event['raw'] as Map) : null;
          _controller.add(SpeechResult(text: text, isFinal: isFinal, raw: raw));
        }
      },
      onError: (_) {
        _status = SpeechStatus.error;
      },
    );

    _status = SpeechStatus.stopped;
  }

  @override
  Future<void> start() async {
    await _method.invokeMethod('start');
    _status = SpeechStatus.listening;
  }

  @override
  Future<void> stop() async {
    await _method.invokeMethod('stop');
    _status = SpeechStatus.stopped;
  }

  @override
  Future<void> dispose() async {
    await _method.invokeMethod('dispose');
    await _eventSub?.cancel();
    _eventSub = null;
    await _controller.close();
    _status = SpeechStatus.idle;
  }

  Future<String> _ensureModelExtracted(String modelAssetDir) async {
    final manifestAssetPath = '$modelAssetDir/manifest.txt';
    final manifest = await rootBundle.loadString(manifestAssetPath);
    final manifestHash = _hashString(manifest);

    final supportDir = await getApplicationSupportDirectory();
    final targetDir = Directory('${supportDir.path}/$modelAssetDir');
    final hashFile = File('${targetDir.path}/.manifest_hash');

    final needsExtract = !(await targetDir.exists()) ||
        !(await hashFile.exists()) ||
        (await hashFile.readAsString()) != manifestHash;

    if (needsExtract) {
      if (await targetDir.exists()) {
        await targetDir.delete(recursive: true);
      }
      await targetDir.create(recursive: true);

      final files = manifest
          .split('\n')
          .map((x) => x.trim())
          .where((x) => x.isNotEmpty && !x.startsWith('#'))
          .toList();

      for (final rel in files) {
        final data = await rootBundle.load('$modelAssetDir/$rel');
        final out = File('${targetDir.path}/$rel');
        await out.parent.create(recursive: true);
        await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
      }

      await hashFile.writeAsString(manifestHash, flush: true);
    }

    return targetDir.path;
  }

  String _hashString(String input) {
    final bytes = utf8.encode(input);
    var hash = 2166136261;
    for (final b in bytes) {
      hash ^= b;
      hash = (hash * 16777619) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16);
  }
}
