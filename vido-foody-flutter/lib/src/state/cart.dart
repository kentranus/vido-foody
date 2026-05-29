import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'catalog.dart';

@immutable
class CartLine {
  final Product product;
  final int qty;
  final String size;
  final String sugar;
  final List<LineAddon> addons;
  const CartLine({
    required this.product,
    required this.qty,
    this.size = 'M',
    this.sugar = '100%',
    this.addons = const [],
  });
  String get key => [
    product.id,
    size,
    sugar,
    ...addons.map((a) => a.name),
  ].join('|');
  String get optionLabel {
    final extras = addons.isEmpty ? '' : ' · ${addons.map((a) => a.name).join(', ')}';
    return '$size · Sugar $sugar$extras';
  }
  double get addonTotal => addons.fold(0.0, (s, a) => s + a.price);
  double get unitTotal => product.price + addonTotal;
  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty, size: size, sugar: sugar, addons: addons);
  double get lineTotal => unitTotal * qty;
}

@immutable
class LineAddon {
  final String name;
  final double price;
  const LineAddon(this.name, this.price);
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

  void add(Product p, {String size = 'M', String sugar = '100%', List<LineAddon> addons = const []}) {
    final line = CartLine(product: p, qty: 1, size: size, sugar: sugar, addons: addons);
    final idx = state.lines.indexWhere((l) => l.key == line.key);
    if (idx >= 0) {
      final newLines = [...state.lines];
      newLines[idx] = newLines[idx].copyWith(qty: newLines[idx].qty + 1);
      state = state.copyWith(lines: newLines);
    } else {
      state = state.copyWith(lines: [...state.lines, line]);
    }
  }

  void changeQty(String lineKey, int delta) {
    final idx = state.lines.indexWhere((l) => l.key == lineKey);
    if (idx < 0) return;
    final next = state.lines[idx].qty + delta;
    if (next <= 0) {
      remove(lineKey);
    } else {
      final newLines = [...state.lines];
      newLines[idx] = newLines[idx].copyWith(qty: next);
      state = state.copyWith(lines: newLines);
    }
  }

  void remove(String lineKey) {
    state = state.copyWith(
      lines: state.lines.where((l) => l.key != lineKey).toList(),
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
