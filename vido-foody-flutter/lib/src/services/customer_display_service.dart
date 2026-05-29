import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Customer-Facing Display service. Backed by `CustomerDisplayPlugin.kt`.
///
/// On non-Android platforms all methods are no-ops so the rest of the app
/// continues to work in `flutter run -d chrome` / other targets.
class CustomerDisplayService {
  static const _channel = MethodChannel('com.vido.pos.dual/customer_display');
  final _displaysCtrl = StreamController<List<CfdDisplay>>.broadcast();
  final _dismissCtrl  = StreamController<void>.broadcast();

  Stream<List<CfdDisplay>> get displays$ => _displaysCtrl.stream;
  Stream<void>             get dismissed$ => _dismissCtrl.stream;

  CustomerDisplayService() {
    if (_native) {
      _channel.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'onDisplaysChanged':
            final raw = (call.arguments as Map?)?['displays'] as List? ?? [];
            _displaysCtrl.add(raw
                .map((e) => CfdDisplay.fromMap(Map<String, dynamic>.from(e as Map)))
                .toList());
            break;
          case 'onDismissed':
            _dismissCtrl.add(null);
            break;
        }
      });
    }
  }

  bool get _native => !kIsWeb && Platform.isAndroid;

  Future<List<CfdDisplay>> listDisplays() async {
    if (!_native) return const [];
    try {
      final r = await _channel.invokeMethod<Map>('listDisplays');
      final list = (r?['displays'] as List?) ?? [];
      return list
          .map((e) => CfdDisplay.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e) {
      debugPrint('CFD listDisplays: $e');
      return const [];
    }
  }

  Future<bool> show({int? displayId}) async {
    if (!_native) return false;
    try {
      final r = await _channel.invokeMethod<Map>('show', {
        if (displayId != null) 'displayId': displayId,
      });
      return r?['ok'] == true;
    } catch (e) {
      debugPrint('CFD show: $e');
      return false;
    }
  }

  Future<void> hide() async {
    if (!_native) return;
    try { await _channel.invokeMethod('hide'); } catch (_) {}
  }

  Future<bool> isShowing() async {
    if (!_native) return false;
    try {
      final r = await _channel.invokeMethod<Map>('isShowing');
      return r?['showing'] == true;
    } catch (_) { return false; }
  }

  Future<void> update(Map<String, dynamic> payload) async {
    if (!_native) return;
    try {
      await _channel.invokeMethod('update', {'json': jsonEncode(payload)});
    } catch (e) {
      debugPrint('CFD update: $e');
    }
  }

  void dispose() {
    _displaysCtrl.close();
    _dismissCtrl.close();
  }
}

class CfdDisplay {
  final int id;
  final String name;
  final bool isPrimary;
  final bool isPresentation;
  final int width, height;

  const CfdDisplay({
    required this.id, required this.name,
    required this.isPrimary, required this.isPresentation,
    this.width = 0, this.height = 0,
  });

  factory CfdDisplay.fromMap(Map<String, dynamic> m) => CfdDisplay(
    id: (m['id'] as num).toInt(),
    name: (m['name'] ?? '') as String,
    isPrimary: m['isPrimary'] == true,
    isPresentation: m['isPresentation'] == true,
    width: (m['width'] as num?)?.toInt() ?? 0,
    height: (m['height'] as num?)?.toInt() ?? 0,
  );

  String get sizeLabel => (width > 0 && height > 0) ? '${width}×$height' : '';
}

final customerDisplayService = CustomerDisplayService();
