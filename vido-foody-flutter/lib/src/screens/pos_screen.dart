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
  String _activeSection = 'Order';

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
      Sidebar(
        activeLabel: _activeSection,
        onOpenFeature: _selectSection,
      ),
      Expanded(child: _mainArea()),
      SizedBox(width: 340, child: _cartPanel()),
    ],
  );

  Widget _narrow() => Column(children: [
    Expanded(child: _mainArea()),
    SizedBox(height: 320, child: _cartPanel()),
  ]);

  Widget _mainArea() {
    if (_activeSection == 'Order') return _productArea();
    return _FeaturePanel(title: _activeSection);
  }

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

  void _selectSection(String title) => setState(() => _activeSection = title);

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

class _FeaturePanel extends StatefulWidget {
  final String title;
  const _FeaturePanel({required this.title});

  @override
  State<_FeaturePanel> createState() => _FeaturePanelState();
}

class _FeaturePanelState extends State<_FeaturePanel> {
  int _selected = 0;
  final _backend = TextEditingController(text: 'http://127.0.0.1:8787');
  final _terminalIp = TextEditingController(text: '192.168.68.59');
  final _terminalPort = TextEditingController(text: '10009');
  final _timeout = TextEditingController(text: '60000');
  final _printerName = TextEditingController(text: 'USB Receipt Printer');
  final _kitchenPrinter = TextEditingController(text: 'Kitchen / Label Printer');
  final _staffName = TextEditingController(text: 'New Cashier');
  final _staffPin = TextEditingController(text: '1234');
  final _staffAvatar = TextEditingController(text: 'Default Vido Foody avatar');
  final _ticketSearch = TextEditingController(text: '#1044');
  final _refundAmount = TextEditingController(text: '6.25');
  final _onlineUrl = TextEditingController(text: 'https://vidocenter.com/foody/vido-foody-demo');
  final _kioskId = TextEditingController(text: 'KIOSK-1');
  final _kioskTerminalIp = TextEditingController(text: '192.168.68.59');
  bool _useUsbPayment = false;
  bool _tipOnTerminal = true;
  bool _autoSettlement = true;
  bool _receiptPrinter = true;
  bool _kitchenTicket = true;
  bool _drinkLabel = true;
  bool _customerDisplay = true;
  bool _requireManagerPin = true;
  bool _onlineOrdering = true;
  bool _autoPrintKiosk = true;
  String _staffRole = 'Cashier';
  String _lastAction = 'Ready';
  final List<(String, String)> _staffRows = [
    ('Krishna · Cashier', 'PIN enabled · Avatar: default logo'),
    ('Manager · Admin', 'Refund, void, settlement, settings'),
  ];

  @override
  void dispose() {
    _backend.dispose();
    _terminalIp.dispose();
    _terminalPort.dispose();
    _timeout.dispose();
    _printerName.dispose();
    _kitchenPrinter.dispose();
    _staffName.dispose();
    _staffPin.dispose();
    _staffAvatar.dispose();
    _ticketSearch.dispose();
    _refundAmount.dispose();
    _onlineUrl.dispose();
    _kioskId.dispose();
    _kioskTerminalIp.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _FeaturePanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) _selected = 0;
  }

  @override
  Widget build(BuildContext context) {
    final rows = switch (widget.title) {
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
    final current = rows[_selected];

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FC.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(widget.title,
              style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 24)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: FC.primaryA,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FC.primary),
              ),
              child: const Text('Active',
                style: TextStyle(color: FC.primary, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 14),
          Expanded(
            child: Row(children: [
              SizedBox(
                width: 230,
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final row = rows[i];
                    final selected = _selected == i;
                    return InkWell(
                      onTap: () => setState(() => _selected = i),
                      borderRadius: BorderRadius.circular(14),
                      child: Ink(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: selected ? FC.primaryA : FC.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: selected ? FC.primary : FC.border),
                        ),
                        child: Row(children: [
                          Icon(_featureIcon(row.$1), color: selected ? FC.primary : FC.text, size: 20),
                          const SizedBox(width: 10),
                          Expanded(child: Text(row.$1,
                            style: TextStyle(
                              color: selected ? FC.primary : FC.text,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ))),
                        ]),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 14),
              Expanded(child: _detailFor(current.$1, current.$2)),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _detailFor(String title, String description) {
    final key = '${widget.title} $title'.toLowerCase();
    if (key.contains('payment setting')) return _paymentSettings(title, description);
    if (key.contains('hardware')) return _hardwareSettings(title, description);
    if (key.contains('staff')) return _staffSettings(title, description);
    if (key.contains('bills') || key.contains('closed tickets') || key.contains('reprint') || key.contains('refund')) {
      return _billTools(title, description);
    }
    if (key.contains('reports') || key.contains('sales summary') || key.contains('settlement')) {
      return _reports(title, description);
    }
    if (key.contains('online')) return _onlineOrders(title, description);
    if (key.contains('kiosk')) return _kioskSettings(title, description);
    return _genericDetail(title, description);
  }

  Widget _paymentSettings(String title, String description) => _detailShell(
    title,
    description,
    children: [
      _sectionTitle('Terminal connection'),
      Row(children: [
        Expanded(child: _select('Connection mode', _useUsbPayment ? 'USB' : 'TCP/IP', const ['TCP/IP', 'USB'], (v) => setState(() => _useUsbPayment = v == 'USB'))),
      ]),
      Row(children: [
        Expanded(child: _field('Terminal IP', _terminalIp, enabled: !_useUsbPayment)),
        const SizedBox(width: 12),
        SizedBox(width: 150, child: _field('Port', _terminalPort, keyboard: TextInputType.number, enabled: !_useUsbPayment)),
        const SizedBox(width: 12),
        SizedBox(width: 190, child: _field('Timeout (ms)', _timeout, keyboard: TextInputType.number)),
      ]),
      _switchTile('Ask tip on terminal', 'If off, suggested tip appears on customer display before card payment.', _tipOnTerminal, (v) => setState(() => _tipOnTerminal = v)),
      _switchTile('Auto settlement', 'Keep BroadPOS auto batch on terminal, POS stores the schedule and last batch status.', _autoSettlement, (v) => setState(() => _autoSettlement = v)),
      _buttonRow([
        _action('Test Connection'),
        _action('Test Sale \$0.01'),
        _action('Manual Batch Close', primary: false),
        _action('Save Payment Settings'),
      ]),
      _statusBox('Ready for PAX POSLink: TCP/IP uses ${_terminalIp.text}:${_terminalPort.text}. USB mode requires Android POSLink SDK/native channel on the tablet.'),
    ],
  );

  Widget _hardwareSettings(String title, String description) => _detailShell(
    title,
    description,
    children: [
      Row(children: [
        Expanded(child: _field('Receipt printer', _printerName)),
        const SizedBox(width: 12),
        Expanded(child: _field('Kitchen / label printer', _kitchenPrinter)),
      ]),
      _switchTile('Print customer receipt', 'Receipt for customer after payment.', _receiptPrinter, (v) => setState(() => _receiptPrinter = v)),
      _switchTile('Print kitchen ticket', 'Ticket for staff to make order.', _kitchenTicket, (v) => setState(() => _kitchenTicket = v)),
      _switchTile('Print drink label', 'Optional sticky label printer for cups.', _drinkLabel, (v) => setState(() => _drinkLabel = v)),
      _switchTile('Customer-facing display', 'Auto off on one-screen tablet; auto on when Android second display exists.', _customerDisplay, (v) => setState(() => _customerDisplay = v)),
      _buttonRow([
        _action('Test Printer', onPressed: () => _markAction('Receipt test queued to ${_printerName.text}')),
        _action('Open Cash Drawer', onPressed: () => _markAction('Cash drawer kick sent through receipt printer')),
        _action('Test Kitchen Ticket', primary: false, onPressed: () => _markAction('Kitchen/drink ticket test queued')),
        _action('Open Customer Display', primary: false, onPressed: () => _markAction('Customer display preview opened / second display synced')),
        _action('Save Hardware', onPressed: () => _markAction('Hardware settings saved')),
      ]),
      _statusBox('$_lastAction\n\nCash drawer is routed through receipt printer kick command. Customer display stays synced with cart, tips, payment status, and completed order number.'),
    ],
  );

  Widget _staffSettings(String title, String description) => _detailShell(
    title,
    description,
    children: [
      Row(children: [
        Expanded(child: _field('Staff name', _staffName)),
        const SizedBox(width: 12),
        Expanded(child: _field('PIN', _staffPin, keyboard: TextInputType.number)),
        const SizedBox(width: 12),
        Expanded(child: _select('Role', _staffRole, const ['Cashier', 'Manager', 'Admin'], (v) => setState(() => _staffRole = v))),
      ]),
      _field('Avatar / profile photo', _staffAvatar),
      _switchTile('Require manager PIN for refund/void', 'Protect refunds, voids, settlement, and settings.', _requireManagerPin, (v) => setState(() => _requireManagerPin = v)),
      _miniTable(_staffRows),
      _miniTable([
        ('Cashier permissions', 'Sell, cash/card/gift card payment, reprint receipt'),
        ('Manager permissions', 'Refund, void, discounts, settlement, edit tickets'),
        ('Admin permissions', 'Staff, hardware, menu, kiosk, payment settings'),
      ]),
      _buttonRow([
        _action('Create Staff', onPressed: _createStaff),
        _action('Reset PIN', primary: false, onPressed: () => _markAction('PIN reset prepared for ${_staffName.text}')),
        _action('Save Staff Login', onPressed: () => _markAction('Staff login policy saved')),
      ]),
      _statusBox('$_lastAction\n\nWhen a staff member logs in, the sidebar profile uses that staff avatar. If no avatar is uploaded, the default Vido Foody logo avatar is used.'),
    ],
  );

  Widget _billTools(String title, String description) => _detailShell(
    title,
    description,
    children: [
      Row(children: [
        Expanded(child: _field('Search ticket/order number', _ticketSearch)),
        const SizedBox(width: 12),
        SizedBox(width: 170, child: _field('Refund amount', _refundAmount, keyboard: TextInputType.number)),
      ]),
      _miniTable([
        ('#1044 · Card Payment', '\$6.25 · Approved · Auth A12345 · Last4 4242'),
        ('#1043 · Cash', '\$18.92 · Paid · Change \$1.08'),
        ('#1042 · Kiosk', '\$12.61 · Paid · Ticket printed'),
      ]),
      _buttonRow([
        _action('Search', onPressed: () => _markAction('Ticket ${_ticketSearch.text} loaded')),
        _action('Reprint Receipt', onPressed: () => _markAction('Customer receipt reprinted')),
        _action('Reprint Kitchen Ticket', primary: false, onPressed: () => _markAction('Kitchen/drink ticket reprinted')),
        _action('Refund', onPressed: () => _markAction('Refund flow opened for ${_refundAmount.text}; manager PIN required')),
        _action('Void', onPressed: () => _markAction('Void flow opened; manager PIN required')),
      ]),
      _statusBox('$_lastAction\n\nRefund calls PAX POSLink return/refund with original ticket ref/auth when available. Reprint can route to receipt, kitchen, or label printer.'),
    ],
  );

  Widget _reports(String title, String description) => _detailShell(
    title,
    description,
    children: [
      Wrap(spacing: 12, runSpacing: 12, children: const [
        _MetricCard(label: 'Gross sales', value: '\$842.31'),
        _MetricCard(label: 'Net sales', value: '\$768.61'),
        _MetricCard(label: 'Orders', value: '104'),
        _MetricCard(label: 'Avg ticket', value: '\$8.10'),
        _MetricCard(label: 'Card', value: '\$603.10'),
        _MetricCard(label: 'Cash', value: '\$178.21'),
        _MetricCard(label: 'Tips', value: '\$61.00'),
        _MetricCard(label: 'Refunds', value: '\$0.00'),
      ]),
      const SizedBox(height: 14),
      _miniTable([
        ('Tender mix', 'Card 72% · Cash 21% · Gift card 7%'),
        ('Top items', 'Brown Sugar Boba · Classic Milk Tea · Taro Milk Tea'),
        ('Channel mix', 'POS 68% · Kiosk 19% · Online 13%'),
        ('Staff performance', 'Krishna \$312.45 · Manager \$529.86'),
        ('Discounts / comps', '\$14.00 · 3 manager approvals'),
        ('Tax collected', '\$73.70'),
        ('Settlement', _autoSettlement ? 'Auto settlement enabled' : 'Manual settlement'),
      ]),
      _buttonRow([
        _action('Today', onPressed: () => _markAction('Showing today report')),
        _action('This Week', primary: false, onPressed: () => _markAction('Showing weekly report')),
        _action('Export CSV', onPressed: () => _markAction('CSV export generated for accounting')),
        _action('Print Report', onPressed: () => _markAction('Report sent to receipt printer')),
      ]),
      _statusBox('$_lastAction\n\nReports are designed for Toast/Square/Clover style operations: sales summary, tender mix, item/category sales, staff, refunds/voids, taxes, settlement, online and kiosk channels.'),
    ],
  );

  Widget _onlineOrders(String title, String description) => _detailShell(
    title,
    description,
    children: [
      _field('Online order link', _onlineUrl),
      _switchTile('Accept online ordering', 'Website/kiosk orders share the same store menu and backend.', _onlineOrdering, (v) => setState(() => _onlineOrdering = v)),
      _miniTable([
        ('WEB-104 · Paid Online', 'Brown Sugar Boba x2 · Mochi x1 · \$18.92'),
        ('DOORDASH-221 · Awaiting Accept', 'Classic Milk Tea x1 · \$6.02'),
      ]),
      _buttonRow([_action('Refresh Orders'), _action('Accept Order'), _action('Reject'), _action('Print Ticket')]),
      _statusBox('Online orders should stay in queue until staff accepts. After accept, POS prints kitchen ticket and optional receipt/label.'),
    ],
  );

  Widget _kioskSettings(String title, String description) => _detailShell(
    title,
    description,
    children: [
      Row(children: [
        Expanded(child: _field('Kiosk Device ID', _kioskId)),
        const SizedBox(width: 12),
        Expanded(child: _field('Assigned terminal IP', _kioskTerminalIp)),
      ]),
      _switchTile('Auto-print paid kiosk orders', 'After Pay Now succeeds, kiosk sends order to POS and POS prints ticket.', _autoPrintKiosk, (v) => setState(() => _autoPrintKiosk = v)),
      _miniTable([
        ('KIOSK-1 · Front counter', 'TCP/IP · ${_kioskTerminalIp.text}:10009 · Active'),
        ('KIOSK-2 · Self order', 'Not assigned · Disabled'),
      ]),
      _buttonRow([_action('Register Kiosk'), _action('Assign Terminal'), _action('Test Kiosk Order'), _action('Save Kiosk')]),
      _statusBox('Kiosk UI supports portrait and landscape. Kiosk menu/options must stay synced from POS menu: sizes, sugar, toppings, add-ons, price rules.'),
    ],
  );

  Widget _genericDetail(String title, String description) => _detailShell(
    title,
    description,
    children: [
      _miniTable([
        ('Status', 'Ready'),
        ('Next action', 'Connect backend API and Android native hardware channel'),
      ]),
      _buttonRow([_action('Open'), _action('Save'), _action('Test')]),
    ],
  );

  Widget _detailShell(String title, String description, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: FC.card, borderRadius: BorderRadius.circular(16), border: Border.all(color: FC.border)),
      child: ListView(children: [
        Text(title, style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 24)),
        const SizedBox(height: 8),
        Text(description, style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 14, height: 1.45)),
        const SizedBox(height: 18),
        ...children,
      ]),
    );
  }

  Widget _field(String label, TextEditingController controller, {TextInputType? keyboard, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: keyboard,
        style: const TextStyle(color: FC.text, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w800),
          filled: true,
          fillColor: enabled ? FC.bg : FC.panel,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FC.border)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FC.border)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FC.primary, width: 2)),
        ),
      ),
    );
  }

  Widget _select(String label, String value, List<String> values, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        dropdownColor: FC.panel,
        style: const TextStyle(color: FC.text, fontWeight: FontWeight.w800),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w800),
          filled: true,
          fillColor: FC.bg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: FC.border)),
        ),
        items: [for (final v in values) DropdownMenuItem(value: v, child: Text(v))],
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
      ),
    );
  }

  Widget _switchTile(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: FC.bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: FC.border)),
      child: SwitchListTile(
        value: value,
        activeColor: FC.primary,
        onChanged: onChanged,
        title: Text(title, style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900)),
        subtitle: Text(subtitle, style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buttonRow(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 14),
      child: Wrap(spacing: 10, runSpacing: 10, children: children),
    );
  }

  void _markAction(String message) {
    setState(() => _lastAction = message);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _createStaff() {
    final name = _staffName.text.trim().isEmpty ? 'New Staff' : _staffName.text.trim();
    final pin = _staffPin.text.trim().isEmpty ? 'No PIN' : 'PIN ${_staffPin.text.trim()}';
    setState(() {
      _staffRows.insert(0, ('$name · $_staffRole', '$pin · Avatar: ${_staffAvatar.text.trim().isEmpty ? 'default logo' : _staffAvatar.text.trim()}'));
      _lastAction = 'Created staff profile for $name';
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created staff profile for $name')));
  }

  Widget _action(String label, {bool primary = true, VoidCallback? onPressed}) {
    return FilledButton(
      onPressed: onPressed ?? () => _markAction('$label completed'),
      style: FilledButton.styleFrom(
        backgroundColor: primary ? FC.primary : FC.panel,
        foregroundColor: primary ? FC.bg : FC.text,
        side: BorderSide(color: primary ? FC.primary : FC.border),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(text, style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 15)),
  );

  Widget _statusBox(String text) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: FC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: FC.border)),
    child: Text(text, style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, height: 1.45)),
  );

  Widget _miniTable(List<(String, String)> rows) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: BoxDecoration(color: FC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: FC.border)),
    child: Column(children: [
      for (var i = 0; i < rows.length; i++)
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(border: i == rows.length - 1 ? null : const Border(bottom: BorderSide(color: FC.border))),
          child: Row(children: [
            Expanded(flex: 2, child: Text(rows[i].$1, style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900))),
            Expanded(flex: 3, child: Text(rows[i].$2, style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w700))),
          ]),
        ),
    ]),
  );

  IconData _featureIcon(String text) {
    if (text.toLowerCase().contains('payment') || text.toLowerCase().contains('pax')) return Icons.credit_card;
    if (text.toLowerCase().contains('printer') || text.toLowerCase().contains('receipt')) return Icons.print;
    if (text.toLowerCase().contains('refund') || text.toLowerCase().contains('void')) return Icons.undo;
    if (text.toLowerCase().contains('settlement')) return Icons.account_balance;
    if (text.toLowerCase().contains('kiosk')) return Icons.storefront;
    if (text.toLowerCase().contains('website')) return Icons.public;
    if (text.toLowerCase().contains('staff')) return Icons.lock_person;
    return Icons.tune;
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: FC.bg, borderRadius: BorderRadius.circular(14), border: Border.all(color: FC.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: const TextStyle(color: FC.textMute, fontWeight: FontWeight.w900, fontSize: 10)),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(color: FC.primary, fontWeight: FontWeight.w900, fontSize: 22)),
      ]),
    );
  }
}
