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
                onAdd: () => ref.read(cartProvider.notifier).add(visible[i]),
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
