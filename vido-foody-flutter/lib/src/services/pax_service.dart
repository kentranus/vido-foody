import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provider exposing the singleton PAX payment service.
final paxServiceProvider = Provider<PaxService>((_) => PaxService._());

/// Connection settings — usually persisted in SharedPreferences (later)
/// and re-applied on app start. For now they live in memory; the settings
/// sheet writes them via [PaxService.configure].
class PaxConfig {
  final String commType;       // TCP | USB | BT | AIDL | UART
  final String destIp;
  final String destPort;
  final String serialPort;
  final String baudRate;
  final String timeoutMs;
  final bool enableProxy;       // E-series USB → Q20 forwarding
  const PaxConfig({
    this.commType = 'TCP',
    this.destIp = '192.168.1.100',
    this.destPort = '10009',
    this.serialPort = 'COM1',
    this.baudRate = '115200',
    this.timeoutMs = '60000',
    this.enableProxy = true,
  });

  Map<String, dynamic> toMap() => {
    'commType': commType, 'destIp': destIp, 'destPort': destPort,
    'serialPort': serialPort, 'baudRate': baudRate,
    'timeoutMs': timeoutMs, 'enableProxy': enableProxy,
  };
}

class PaxInitResult {
  final bool ok;
  final bool mock;
  final String? sn, model, osVersion, macAddress;
  final String? resultCode, resultText;
  PaxInitResult.fromMap(Map m)
    : ok = m['ok'] == true,
      mock = m['mock'] == true,
      sn = m['sn'] as String?,
      model = m['model'] as String?,
      osVersion = m['osVersion'] as String?,
      macAddress = m['macAddress'] as String?,
      resultCode = m['resultCode'] as String?,
      resultText = m['resultText'] as String?;
}

class PaxSaleResult {
  final bool ok;
  final bool mock;
  final String resultCode, resultText;
  final String hostCode, hostText;
  final String? authCode, refNum, transNum;
  final String? cardType, last4, entryMode;
  final int approvedAmountCents;
  final bool signatureRequired;

  PaxSaleResult.fromMap(Map m)
    : ok = m['ok'] == true,
      mock = m['mock'] == true,
      resultCode = (m['resultCode'] ?? '') as String,
      resultText = (m['resultText'] ?? '') as String,
      hostCode = (m['hostCode'] ?? '') as String,
      hostText = (m['hostText'] ?? '') as String,
      authCode = m['authCode'] as String?,
      refNum = m['refNum'] as String?,
      transNum = m['transNum'] as String?,
      cardType = m['cardType'] as String?,
      last4 = m['last4'] as String?,
      entryMode = m['entryMode'] as String?,
      approvedAmountCents = (m['approvedAmountCents'] ?? 0) as int,
      signatureRequired = m['signatureRequired'] == true;
}

class PaxService {
  PaxService._();
  static const _ch = MethodChannel('com.vido.pos.dual/pax_payment');

  PaxConfig _config = const PaxConfig();
  PaxConfig get config => _config;

  Future<bool> isMockMode() async {
    try {
      final r = await _ch.invokeMethod<Map>('isMockMode');
      return r?['mock'] == true;
    } catch (_) { return true; }
  }

  Future<void> configure(PaxConfig c) async {
    _config = c;
    try {
      await _ch.invokeMethod('configure', c.toMap());
    } on PlatformException { /* surface to UI via initialize() */ }
  }

  Future<PaxInitResult> initialize() async {
    try {
      final r = await _ch.invokeMethod<Map>('initialize');
      return PaxInitResult.fromMap(r ?? const {});
    } on PlatformException catch (e) {
      return PaxInitResult.fromMap({
        'ok': false, 'resultCode': e.code, 'resultText': e.message ?? 'error',
      });
    }
  }

  /// Charge the customer's card via the connected PAX terminal.
  /// Amounts are in cents (USD) — 10.50 USD → 1050.
  Future<PaxSaleResult> sale({
    required int amountCents,
    int tipCents = 0,
    int taxCents = 0,
    required String ecrRefNum,
    String invoiceNum = '',
    String clerkId = '',
  }) async {
    try {
      final r = await _ch.invokeMethod<Map>('sale', {
        'amountCents': amountCents,
        'tipCents': tipCents,
        'taxCents': taxCents,
        'ecrRefNum': ecrRefNum,
        'invoiceNum': invoiceNum,
        'clerkId': clerkId,
      });
      return PaxSaleResult.fromMap(r ?? const {});
    } on PlatformException catch (e) {
      return PaxSaleResult.fromMap({
        'ok': false,
        'resultCode': e.code,
        'resultText': e.message ?? 'error',
        'hostCode': '', 'hostText': '',
      });
    }
  }

  Future<PaxSaleResult> voidSale({
    required String ecrRefNum,
    String transNum = '',
  }) async {
    try {
      final r = await _ch.invokeMethod<Map>('voidSale', {
        'ecrRefNum': ecrRefNum, 'transNum': transNum,
      });
      return PaxSaleResult.fromMap(r ?? const {});
    } on PlatformException catch (e) {
      return PaxSaleResult.fromMap({
        'ok': false,
        'resultCode': e.code,
        'resultText': e.message ?? 'error',
        'hostCode': '', 'hostText': '',
      });
    }
  }
}
