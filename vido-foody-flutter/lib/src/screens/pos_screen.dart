import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../state/cart.dart';
import '../state/catalog.dart';
import '../services/cfd_controller.dart';
import '../widgets/top_bar.dart';
import '../widgets/sidebar.dart';
import '../widgets/category_bar.dart';
import '../widgets/product_card.dart';
import '../widgets/cart_panel.dart';
import 'cfd_settings_sheet.dart';
import 'payment_sheet.dart';

class PosScreen extends ConsumerStatefulWidget {
  final VoidCallback? onLogout;
  const PosScreen({super.key, this.onLogout});
  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  String _activeCat = 'all';

  @override
  Widget build(BuildContext context) {
    // Bootstrap CFD controller — registers ref.listen on cart, payments etc.
    ref.watch(cfdControllerProvider);

    return LayoutBuilder(builder: (ctx, c) {
      final isWide = c.maxWidth >= 900;
      return Scaffold(
        backgroundColor: FC.bg,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: TopBar(
            isWide: isWide,
            onOpenCfdSettings: _openCfdSheet,
            onLogout: widget.onLogout,
          ),
        ),
        body: SafeArea(
          top: false,
          child: isWide ? _wide() : _narrow(),
        ),
      );
    });
  }

  Widget _wide() => Row(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Sidebar(onOpenFeature: _openFeatureSheet),
      Expanded(child: _productArea()),
      SizedBox(width: 340, child: _cartPanel()),
    ],
  );

  Widget _narrow() => Column(children: [
    Expanded(child: _productArea()),
    SizedBox(height: 320, child: _cartPanel()),
  ]);

  Widget _productArea() {
    final visible = kProducts.where(
      (p) => _activeCat == 'all' || p.category == _activeCat,
    ).toList();
    final cart = ref.watch(cartProvider);
    final inCart = cart.lines.map((l) => l.product.id).toSet();

    return Column(children: [
      CategoryBar(
        active: _activeCat,
        onSelect: (id) => setState(() => _activeCat = id),
      ),
      Expanded(
        child: visible.isEmpty
          ? const Center(child: Text('No items',
              style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w700)))
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200,
                mainAxisSpacing: 12, crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: visible.length,
              itemBuilder: (_, i) => ProductCard(
                product: visible[i],
                inCart: inCart.contains(visible[i].id),
                onAdd: () => _addProduct(visible[i]),
              ),
            ),
      ),
    ]);
  }

  Widget _cartPanel() => CartPanel(
    onCharge: () => _openPayment(),
  );

  void _openCfdSheet() => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const CfdSettingsSheet(),
  );

  void _openFeatureSheet(String title) => showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => _FeatureSheet(title: title),
  );

  Future<void> _addProduct(Product product) async {
    if (!product.hasOptions) {
      ref.read(cartProvider.notifier).add(product);
      return;
    }
    final line = await showModalBottomSheet<CartLine>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProductOptionsSheet(product: product),
    );
    if (line == null) return;
    ref.read(cartProvider.notifier).add(
      product,
      size: line.size,
      sugar: line.sugar,
      addons: line.addons,
    );
  }

  Future<void> _openPayment() async {
    final cart = ref.read(cartProvider);
    if (cart.isEmpty) return;
    final method = ref.read(paymentMethodProvider);
    if (method == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Chọn phương thức thanh toán trước'),
        backgroundColor: FC.panel,
      ));
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => PaymentSheet(cart: cart, method: method),
    );
    if (ok == true) {
      ref.read(cartProvider.notifier).reset();
      ref.read(paymentMethodProvider.notifier).state = null;
    }
  }
}

class _ProductOptionsSheet extends StatefulWidget {
  final Product product;
  const _ProductOptionsSheet({required this.product});

  @override
  State<_ProductOptionsSheet> createState() => _ProductOptionsSheetState();
}

class _ProductOptionsSheetState extends State<_ProductOptionsSheet> {
  String _size = 'M';
  String _sugar = '100%';
  final Set<String> _addonNames = {};

  static const _addons = [
    LineAddon('Boba', 0.75),
    LineAddon('Crystal Boba', 0.85),
    LineAddon('Pudding', 0.75),
    LineAddon('Less Ice', 0.00),
    LineAddon('No Ice', 0.00),
    LineAddon('Extra Sweet', 0.00),
  ];

  double get _sizePrice => switch (_size) {
    'S' => -0.50,
    'L' => 1.00,
    _ => 0.00,
  };

  List<LineAddon> get _selectedAddons =>
      _addons.where((a) => _addonNames.contains(a.name)).toList();

  double get _unitTotal =>
      widget.product.price + _sizePrice + _selectedAddons.fold(0.0, (s, a) => s + a.price);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: FC.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(widget.product.emoji, style: const TextStyle(fontSize: 34)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.product.name,
              style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 22))),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: FC.text),
            ),
          ]),
          const SizedBox(height: 14),
          _section('Size', [
            _choice('S', '-${kCurrencySymbol}0.50', _size == 'S', () => setState(() => _size = 'S')),
            _choice('M', 'Included', _size == 'M', () => setState(() => _size = 'M')),
            _choice('L', '+${kCurrencySymbol}1.00', _size == 'L', () => setState(() => _size = 'L')),
          ]),
          _section('Sugar', [
            for (final s in const ['0%', '25%', '50%', '75%', '100%'])
              _choice(s, '', _sugar == s, () => setState(() => _sugar = s)),
          ]),
          const Text('Toppings & Add-ons',
            style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final addon in _addons)
                _addonChip(addon),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: FC.primary,
                foregroundColor: FC.bg,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: () => Navigator.pop(context, CartLine(
                product: widget.product,
                qty: 1,
                size: _size,
                sugar: _sugar,
                addons: _selectedAddons,
              )),
              child: Text('Add to Order · $kCurrencySymbol${_unitTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: children),
    ]),
  );

  Widget _choice(String title, String sub, bool selected, VoidCallback onTap) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 112,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: selected ? FC.primaryA : FC.card,
        border: Border.all(color: selected ? FC.primary : FC.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: [
        Text(title, style: TextStyle(
          color: selected ? FC.primary : FC.text,
          fontWeight: FontWeight.w900,
          fontSize: 14,
        )),
        if (sub.isNotEmpty) Text(sub, style: const TextStyle(
          color: FC.textMute,
          fontWeight: FontWeight.w700,
          fontSize: 10,
        )),
      ]),
    ),
  );

  Widget _addonChip(LineAddon addon) {
    final selected = _addonNames.contains(addon.name);
    return InkWell(
      onTap: () => setState(() {
        selected ? _addonNames.remove(addon.name) : _addonNames.add(addon.name);
      }),
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? FC.primaryA : FC.card,
          border: Border.all(color: selected ? FC.primary : FC.border),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          addon.price == 0
              ? '${addon.name} · Free'
              : '${addon.name} · +$kCurrencySymbol${addon.price.toStringAsFixed(2)}',
          style: TextStyle(
            color: selected ? FC.primary : FC.text,
            fontWeight: FontWeight.w900,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _FeatureSheet extends StatelessWidget {
  final String title;
  const _FeatureSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    final rows = switch (title) {
      'Online Orders' => const [
        ('Website orders', 'Receive paid orders from vidocenter.com/foody before printing kitchen tickets.'),
        ('Accept / reject queue', 'Staff confirms incoming orders, then POS prints the ticket.'),
        ('Store link', 'Each store account can have its own online ordering URL.'),
      ],
      'Kiosk' => const [
        ('Kiosk devices', 'Register each Vido Foody Kiosk and assign its own PAX terminal.'),
        ('Portrait / landscape', 'Kiosk UI auto adapts to vertical and horizontal screens.'),
        ('Paid kiosk orders', 'After Pay Now succeeds, the order number is sent back to POS.'),
      ],
      'Reports' => const [
        ('Sales summary', 'Daily sales, payment methods, tax, tips, refunds, and voids.'),
        ('Order history', 'Reprint receipt, refund, or review closed tickets.'),
        ('Settlement', 'Track manual and terminal auto batch close status.'),
      ],
      'Bills' => const [
        ('Closed tickets', 'Find past orders by order number, time, or payment method.'),
        ('Reprint receipt', 'Send customer or merchant copy to the receipt printer.'),
        ('Refund / void', 'Refund card payments through PAX when supported by processor setup.'),
      ],
      _ => const [
        ('Payment setting', 'PAX TCP/IP, USB mode, timeout, tips on terminal, and test sale.'),
        ('Hardware', 'Receipt printer, cash drawer kick, and customer-facing display.'),
        ('Staff login', 'PIN roles for cashier, manager, and admin actions.'),
      ],
    };

    return Container(
      margin: const EdgeInsets.all(18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: FC.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(title,
              style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 22)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close, color: FC.text),
            ),
          ]),
          const SizedBox(height: 8),
          for (final row in rows)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: FC.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: FC.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(row.$1,
                    style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(row.$2,
                    style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 12, height: 1.35)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
