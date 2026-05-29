import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog.dart';

@immutable
class CartLine {
  final Product product;
  final int qty;
  const CartLine({required this.product, required this.qty});
  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);
  double get lineTotal => product.price * qty;
}

@immutable
class Cart {
  final List<CartLine> lines;
  final String type;     // 'dinein' | 'togo' | 'delivery'
  final int number;
  const Cart({this.lines = const [], this.type = 'togo', this.number = 1043});

  double get sub   => lines.fold(0.0, (s, l) => s + l.lineTotal);
  double get tax   => sub * kTaxRate;
  double get total => sub + tax;
  bool   get isEmpty => lines.isEmpty;

  Cart copyWith({List<CartLine>? lines, String? type, int? number}) =>
      Cart(lines: lines ?? this.lines, type: type ?? this.type,
           number: number ?? this.number);
}

class CartNotifier extends StateNotifier<Cart> {
  CartNotifier() : super(const Cart());

  void add(Product p) {
    final idx = state.lines.indexWhere((l) => l.product.id == p.id);
    if (idx >= 0) {
      final newLines = [...state.lines];
      newLines[idx] = newLines[idx].copyWith(qty: newLines[idx].qty + 1);
      state = state.copyWith(lines: newLines);
    } else {
      state = state.copyWith(lines: [...state.lines, CartLine(product: p, qty: 1)]);
    }
  }

  void changeQty(String productId, int delta) {
    final idx = state.lines.indexWhere((l) => l.product.id == productId);
    if (idx < 0) return;
    final next = state.lines[idx].qty + delta;
    if (next <= 0) {
      remove(productId);
    } else {
      final newLines = [...state.lines];
      newLines[idx] = newLines[idx].copyWith(qty: next);
      state = state.copyWith(lines: newLines);
    }
  }

  void remove(String productId) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.product.id != productId).toList(),
    );
  }

  void setType(String t) => state = state.copyWith(type: t);

  void reset() {
    state = state.copyWith(lines: [], number: state.number + 1);
  }
}

final cartProvider = StateNotifierProvider<CartNotifier, Cart>(
  (ref) => CartNotifier(),
);

/// Current chosen payment method, or null if none yet.
final paymentMethodProvider = StateProvider<String?>((ref) => null);

/// Whether the customer display feature is enabled in Settings.
final cfdEnabledProvider = StateProvider<bool>((ref) => false);

/// Which secondary display the CFD shows on. Null = first available.
final cfdDisplayIdProvider = StateProvider<int?>((ref) => null);
