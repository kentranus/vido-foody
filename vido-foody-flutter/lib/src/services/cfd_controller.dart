import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../state/cart.dart';
import '../state/catalog.dart';
import 'customer_display_service.dart';

/// Owns the lifecycle of the secondary display:
///   - Auto-pushes cart changes when CFD is enabled
///   - Exposes imperative APIs the payment flow can call
class CustomerDisplayController {
  CustomerDisplayController(this._ref) {
    // Auto-sync cart → CFD
    _ref.listen<Cart>(cartProvider, (_, next) => _pushCart(next));

    // React to enable/disable + display selection
    _ref.listen<bool>(cfdEnabledProvider, (prev, next) async {
      if (next && !(prev ?? false)) {
        await customerDisplayService.show(
          displayId: _ref.read(cfdDisplayIdProvider),
        );
        _pushCart(_ref.read(cartProvider));
      } else if (!next && (prev ?? false)) {
        await customerDisplayService.hide();
      }
    });
    _ref.listen<int?>(cfdDisplayIdProvider, (prev, next) async {
      if (!_ref.read(cfdEnabledProvider)) return;
      await customerDisplayService.hide();
      await customerDisplayService.show(displayId: next);
      _pushCart(_ref.read(cartProvider));
    });

    _dismissSub = customerDisplayService.dismissed$.listen((_) {
      if (_ref.read(cfdEnabledProvider)) {
        _ref.read(cfdEnabledProvider.notifier).state = false;
      }
    });
  }

  final Ref _ref;
  StreamSubscription<void>? _dismissSub;
  String _displayState = 'order';

  Map<String, dynamic> _shopMap() => {
    'name': 'Vido Foody',
    'currencySymbol': kCurrencySymbol,
  };

  void _pushCart(Cart cart) {
    if (!_ref.read(cfdEnabledProvider)) return;
    if (_displayState == 'payment' || _displayState == 'done') return;
    if (cart.isEmpty) {
      _displayState = 'idle';
      customerDisplayService.update({'state': 'idle', 'shop': _shopMap()});
      return;
    }
    _displayState = 'order';
    customerDisplayService.update({
      'state': 'order',
      'shop': _shopMap(),
      'orderNumber': cart.number,
      'items': [
        for (final l in cart.lines) {
          'name': l.product.name,
          'emoji': l.product.emoji,
          'details': '',
          'qty': l.qty,
          'total': l.lineTotal,
        },
      ],
      'subtotal': cart.sub,
      'discount': 0,
      'tax': cart.tax,
      'total': cart.total,
    });
  }

  void enterPayment({required Cart cart, required String method}) {
    if (!_ref.read(cfdEnabledProvider)) return;
    _displayState = 'payment';
    customerDisplayService.update({
      'state': 'payment',
      'shop': _shopMap(),
      'orderNumber': cart.number,
      'total': cart.total,
      'method': method,
    });
  }

  void markCompleted({required Cart cart}) {
    if (!_ref.read(cfdEnabledProvider)) return;
    _displayState = 'done';
    customerDisplayService.update({
      'state': 'done',
      'shop': _shopMap(),
      'total': cart.total,
    });
    Future.delayed(const Duration(seconds: 5), () {
      if (_displayState == 'done') _displayState = 'order';
    });
  }

  void dispose() {
    _dismissSub?.cancel();
  }
}

final cfdControllerProvider = Provider<CustomerDisplayController>((ref) {
  final c = CustomerDisplayController(ref);
  ref.onDispose(c.dispose);
  return c;
});
