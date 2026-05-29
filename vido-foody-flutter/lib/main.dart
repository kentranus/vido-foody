import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const VidoFoodyApp());

const brand = Color(0xFFF59E0B);
const brand2 = Color(0xFFFFCC00);
const danger = Color(0xFFEF4444);
const success = Color(0xFF22C55E);

String money(num value) => '\$${value.toStringAsFixed(2)}';

class Palette {
  const Palette({
    required this.dark,
    required this.bg,
    required this.panel,
    required this.card,
    required this.border,
    required this.text,
    required this.muted,
  });

  final bool dark;
  final Color bg;
  final Color panel;
  final Color card;
  final Color border;
  final Color text;
  final Color muted;

  static const darkMode = Palette(
    dark: true,
    bg: Color(0xFF0F172A),
    panel: Color(0xFF172033),
    card: Color(0xFF1E293B),
    border: Color(0xFF334155),
    text: Color(0xFFF8FAFC),
    muted: Color(0xFF94A3B8),
  );

  static const lightMode = Palette(
    dark: false,
    bg: Color(0xFFF3F4F6),
    panel: Color(0xFFFFFFFF),
    card: Color(0xFFF8FAFC),
    border: Color(0xFFE5E7EB),
    text: Color(0xFF111827),
    muted: Color(0xFF6B7280),
  );
}

class MenuCategory {
  const MenuCategory({required this.id, required this.name, required this.icon});
  final String id;
  final String name;
  final String icon;
}

class MenuItemData {
  const MenuItemData({
    required this.id,
    required this.category,
    required this.name,
    required this.price,
    required this.icon,
    this.available = true,
    this.popular = false,
    this.addon = false,
  });

  final String id;
  final String category;
  final String name;
  final double price;
  final String icon;
  final bool available;
  final bool popular;
  final bool addon;
}

class CartLine {
  CartLine({required this.item, this.qty = 1, this.size = 'R'});
  final MenuItemData item;
  int qty;
  String size;
  double get unitPrice => item.price + (size == 'L' ? 0.75 : 0);
  double get total => unitPrice * qty;
}

class OrderRecord {
  OrderRecord({
    required this.number,
    required this.items,
    required this.subtotal,
    required this.tax,
    required this.tip,
    required this.total,
    required this.paymentMethod,
    this.source = 'POS',
    this.status = 'completed',
    this.authCode,
    this.cardLast4,
  }) : completedAt = DateTime.now();

  final int number;
  final List<CartLine> items;
  final double subtotal;
  final double tax;
  final double tip;
  final double total;
  final String paymentMethod;
  final String source;
  final String status;
  final String? authCode;
  final String? cardLast4;
  final DateTime completedAt;

  Map<String, dynamic> toJson() => {
        'number': number,
        'subtotal': subtotal,
        'tax': tax,
        'tip': tip,
        'total': total,
        'paymentMethod': paymentMethod,
        'source': source,
        'status': status,
        'authCode': authCode,
        'cardLast4': cardLast4,
        'completedAt': completedAt.toIso8601String(),
        'items': [
          for (final line in items)
            {
              'id': line.item.id,
              'name': line.item.name,
              'qty': line.qty,
              'size': line.size,
              'price': line.unitPrice,
              'total': line.total,
            }
        ],
      };
}

class OnlineOrder {
  OnlineOrder({
    required this.id,
    required this.customer,
    required this.total,
    required this.status,
    required this.paymentStatus,
    required this.source,
    required this.items,
  });

  final String id;
  final String customer;
  final double total;
  final String status;
  final String paymentStatus;
  final String source;
  final List<String> items;

  OnlineOrder copyWith({String? status}) => OnlineOrder(
        id: id,
        customer: customer,
        total: total,
        status: status ?? this.status,
        paymentStatus: paymentStatus,
        source: source,
        items: items,
      );
}

const defaultCategories = [
  MenuCategory(id: 'milk-tea', name: 'Milk Tea', icon: '🧋'),
  MenuCategory(id: 'fruit-tea', name: 'Fruit Tea', icon: '🍑'),
  MenuCategory(id: 'coffee', name: 'Coffee', icon: '☕'),
  MenuCategory(id: 'smoothie', name: 'Smoothies', icon: '🥤'),
  MenuCategory(id: 'snack', name: 'Snacks', icon: '🥐'),
  MenuCategory(id: 'topping', name: 'Toppings', icon: '🟤'),
];

const defaultMenu = [
  MenuItemData(id: 'classic', category: 'milk-tea', name: 'Classic Milk Tea', price: 5.50, icon: '🧋'),
  MenuItemData(id: 'brown-sugar', category: 'milk-tea', name: 'Brown Sugar Boba', price: 6.75, icon: '🧋', popular: true),
  MenuItemData(id: 'oolong', category: 'milk-tea', name: 'Oolong Milk Tea', price: 5.75, icon: '🧋'),
  MenuItemData(id: 'matcha', category: 'milk-tea', name: 'Matcha Latte', price: 6.25, icon: '🍵'),
  MenuItemData(id: 'thai', category: 'milk-tea', name: 'Thai Milk Tea', price: 5.75, icon: '🧋', popular: true),
  MenuItemData(id: 'taro', category: 'milk-tea', name: 'Taro Milk Tea', price: 6.25, icon: '🧋'),
  MenuItemData(id: 'jasmine', category: 'milk-tea', name: 'Jasmine Milk Tea', price: 5.75, icon: '🌼'),
  MenuItemData(id: 'honeydew', category: 'milk-tea', name: 'Honeydew Milk Tea', price: 6.00, icon: '🍈'),
  MenuItemData(id: 'mango', category: 'fruit-tea', name: 'Mango Green Tea', price: 5.75, icon: '🥭'),
  MenuItemData(id: 'strawberry', category: 'fruit-tea', name: 'Strawberry Tea', price: 6.25, icon: '🍓'),
  MenuItemData(id: 'passion', category: 'fruit-tea', name: 'Passion Fruit', price: 5.95, icon: '🍊'),
  MenuItemData(id: 'lychee', category: 'fruit-tea', name: 'Lychee Tea', price: 5.95, icon: '🌸'),
  MenuItemData(id: 'latte', category: 'coffee', name: 'Latte', price: 5.50, icon: '☕'),
  MenuItemData(id: 'iced-coffee', category: 'coffee', name: 'Iced Coffee', price: 4.95, icon: '☕'),
  MenuItemData(id: 'viet-coffee', category: 'coffee', name: 'Vietnamese Coffee', price: 5.25, icon: '☕', popular: true),
  MenuItemData(id: 'mango-sm', category: 'smoothie', name: 'Mango Smoothie', price: 6.50, icon: '🥤'),
  MenuItemData(id: 'straw-sm', category: 'smoothie', name: 'Strawberry Smoothie', price: 6.50, icon: '🥤'),
  MenuItemData(id: 'waffle', category: 'snack', name: 'Bubble Waffle', price: 5.50, icon: '🧇'),
  MenuItemData(id: 'mochi', category: 'snack', name: 'Mochi (3 pcs)', price: 4.25, icon: '🍡'),
  MenuItemData(id: 'tapioca', category: 'topping', name: 'Tapioca Pearls', price: 0.75, icon: '⚫', addon: true),
  MenuItemData(id: 'cheese-foam', category: 'topping', name: 'Cheese Foam', price: 1.25, icon: '🧀', addon: true),
  MenuItemData(id: 'aloe', category: 'topping', name: 'Aloe Vera', price: 0.75, icon: '🟢', addon: true),
  MenuItemData(id: 'jelly', category: 'topping', name: 'Lychee Jelly', price: 0.75, icon: '🟣', addon: true),
  MenuItemData(id: 'pudding', category: 'topping', name: 'Egg Pudding', price: 0.95, icon: '🟡', addon: true),
];

enum AppPage { sell, operations, online, history, reports, settings }

enum TipMode { customerDisplay, paxTerminal, off }

class PaymentSettings {
  String backendUrl = 'http://127.0.0.1:8787';
  String connectionMode = 'tcp';
  String terminalIp = '192.168.68.59';
  int terminalPort = 10009;
  int timeoutMs = 60000;
  bool useNativePosLink = true;
  TipMode tipMode = TipMode.customerDisplay;
  List<int> tipPercents = [15, 18, 20, 25];
  bool autoSettlement = true;
  TimeOfDay settlementTime = const TimeOfDay(hour: 3, minute: 0);
  String settlementMode = 'pax_auto';
}

class KioskTerminalSettings {
  KioskTerminalSettings({
    required this.deviceId,
    required this.name,
    this.enabled = true,
    this.connectionMode = 'tcp',
    this.terminalIp = '192.168.68.59',
    this.terminalPort = 10009,
    this.timeoutMs = 60000,
    this.requirePaymentBeforeSend = true,
  });

  String deviceId;
  String name;
  bool enabled;
  String connectionMode;
  String terminalIp;
  int terminalPort;
  int timeoutMs;
  bool requirePaymentBeforeSend;

  Map<String, dynamic> toJson() => {
        'deviceId': deviceId,
        'name': name,
        'enabled': enabled,
        'connectionMode': connectionMode,
        'terminalIp': terminalIp,
        'terminalPort': terminalPort,
        'timeoutMs': timeoutMs,
        'requirePaymentBeforeSend': requirePaymentBeforeSend,
      };
}

class VidoFoodyApp extends StatefulWidget {
  const VidoFoodyApp({super.key});

  @override
  State<VidoFoodyApp> createState() => _VidoFoodyAppState();
}

class _VidoFoodyAppState extends State<VidoFoodyApp> {
  bool dark = true;

  @override
  Widget build(BuildContext context) {
    final palette = dark ? Palette.darkMode : Palette.lightMode;
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Vido Foody',
      theme: ThemeData(
        brightness: dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: palette.bg,
        colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: dark ? Brightness.dark : Brightness.light),
        useMaterial3: true,
      ),
      home: PosHome(
        palette: palette,
        dark: dark,
        onToggleTheme: () => setState(() => dark = !dark),
      ),
    );
  }
}

class PosHome extends StatefulWidget {
  const PosHome({super.key, required this.palette, required this.dark, required this.onToggleTheme});

  final Palette palette;
  final bool dark;
  final VoidCallback onToggleTheme;

  @override
  State<PosHome> createState() => _PosHomeState();
}

class _PosHomeState extends State<PosHome> {
  final payment = PaymentSettings();
  final kioskTerminals = <KioskTerminalSettings>[
    KioskTerminalSettings(deviceId: 'KIOSK-1', name: 'Front Kiosk 1'),
  ];
  final cart = <CartLine>[];
  final completed = <OrderRecord>[];
  final onlineOrders = <OnlineOrder>[
    OnlineOrder(
      id: 'WEB-104',
      customer: 'Online Customer',
      total: 18.92,
      status: 'new',
      paymentStatus: 'paid online',
      source: 'Website',
      items: ['Brown Sugar Boba x2', 'Mochi (3 pcs) x1'],
    ),
  ];

  AppPage page = AppPage.sell;
  String category = 'milk-tea';
  String orderType = 'Dine In';
  int orderNumber = 1044;
  bool paymentOnline = false;
  bool busy = false;
  String lastBatch = 'Not recorded yet';

  static const nativeChannel = MethodChannel('vido.foody/poslink');

  Palette get p => widget.palette;
  double get subtotal => cart.fold(0, (sum, line) => sum + line.total);
  double get tax => subtotal * 0.0875;
  double get total => subtotal + tax;

  @override
  void initState() {
    super.initState();
    checkPayment();
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final url = Uri.parse('${payment.backendUrl}$path');
    final res = await http.post(url, headers: {'content-type': 'application/json'}, body: jsonEncode(body)).timeout(const Duration(seconds: 70));
    final data = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 400) throw Exception(data['error'] ?? 'Request failed');
    return data;
  }

  Map<String, dynamic> paymentPayload() => {
        'connectionMode': payment.connectionMode,
        'ip': payment.terminalIp,
        'port': payment.terminalPort,
        'timeoutMs': payment.timeoutMs,
        'tipMode': payment.tipMode.name,
      };

  Future<Map<String, dynamic>> sale(double amount, String ref, {double tip = 0}) async {
    if (payment.useNativePosLink) {
      try {
        return Map<String, dynamic>.from(await nativeChannel.invokeMethod('sale', {
          'amount': amount,
          'refNum': ref,
          'tipAmount': tip,
          'payment': paymentPayload(),
        }));
      } catch (_) {
        // During web/dev review or before Android channel is implemented, use Node fallback.
      }
    }
    return post('/api/payment/sale', {
      'amount': amount,
      'refNum': ref,
      'tipAmount': tip,
      'payment': paymentPayload(),
    });
  }

  Future<void> checkPayment() async {
    try {
      if (payment.useNativePosLink) {
        try {
          final r = await nativeChannel.invokeMethod('testConnection', {'payment': paymentPayload()});
          setState(() => paymentOnline = Map<String, dynamic>.from(r)['ok'] == true);
          return;
        } catch (_) {}
      }
      final r = await post('/api/payment/test-connection', {'payment': paymentPayload()});
      setState(() => paymentOnline = r['ok'] == true);
    } catch (_) {
      setState(() => paymentOnline = false);
    }
  }

  void addItem(MenuItemData item) {
    if (!item.available) return;
    setState(() {
      final existing = cart.where((line) => line.item.id == item.id).cast<CartLine?>().firstOrNull;
      if (existing == null) {
        cart.add(CartLine(item: item));
      } else {
        existing.qty += 1;
      }
    });
  }

  Future<void> saveOrder(OrderRecord record) async {
    completed.insert(0, record);
    try {
      await post('/api/orders', record.toJson());
    } catch (_) {}
  }

  Future<void> completeSale({
    required String method,
    double tip = 0,
    String? authCode,
    String? last4,
    String source = 'POS',
  }) async {
    final record = OrderRecord(
      number: orderNumber,
      items: cart.map((line) => CartLine(item: line.item, qty: line.qty, size: line.size)).toList(),
      subtotal: subtotal,
      tax: tax,
      tip: tip,
      total: total + tip,
      paymentMethod: method,
      source: source,
      authCode: authCode,
      cardLast4: last4,
    );
    await saveOrder(record);
    setState(() {
      cart.clear();
      orderNumber += 1;
    });
  }

  void showSnack(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> openDrawer() async {
    try {
      await post('/api/hardware/open-drawer', {});
      showSnack('Cash drawer command sent');
    } catch (err) {
      showSnack('Cash drawer not configured: $err');
    }
  }

  Future<void> runBatchClose() async {
    setState(() => busy = true);
    try {
      Map<String, dynamic> r;
      if (payment.useNativePosLink) {
        try {
          r = Map<String, dynamic>.from(await nativeChannel.invokeMethod('batchClose', {'payment': paymentPayload()}));
        } catch (_) {
          r = await post('/api/payment/batch-close', {'payment': paymentPayload()});
        }
      } else {
        r = await post('/api/payment/batch-close', {'payment': paymentPayload()});
      }
      setState(() => lastBatch = 'Batch ${r['batchNum'] ?? '-'} · ${DateTime.now().toLocal()}');
      showSnack(r['ok'] == true ? 'Batch close complete' : 'Batch close failed');
    } catch (err) {
      showSnack('Batch close failed: $err');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            TopBar(
              palette: p,
              page: page,
              paymentOnline: paymentOnline,
              dark: widget.dark,
              onToggleTheme: widget.onToggleTheme,
              onPage: (next) => setState(() => page = next),
              onRefreshPayment: checkPayment,
            ),
            Expanded(child: body()),
          ],
        ),
      ),
    );
  }

  Widget body() {
    return switch (page) {
      AppPage.sell => Row(children: [
          Expanded(
            flex: 7,
            child: SellPanel(
              palette: p,
              category: category,
              onCategory: (id) => setState(() => category = id),
              onAdd: addItem,
            ),
          ),
          SizedBox(
            width: 410,
            child: CartPanel(
              palette: p,
              orderNumber: orderNumber,
              orderType: orderType,
              cart: cart,
              subtotal: subtotal,
              tax: tax,
              total: total,
              onOrderType: (type) => setState(() => orderType = type),
              onQty: (line, delta) => setState(() {
                line.qty += delta;
                if (line.qty <= 0) cart.remove(line);
              }),
              onSize: (line, size) => setState(() => line.size = size),
              onClear: () => setState(cart.clear),
              onPay: cart.isEmpty ? null : showPaymentSheet,
              onOpenDrawer: openDrawer,
            ),
          ),
        ]),
      AppPage.operations => OperationsPanel(
          palette: p,
          orders: completed,
          onlineOrders: onlineOrders,
          paymentOnline: paymentOnline,
          lastBatch: lastBatch,
          onBatchClose: busy ? null : runBatchClose,
          onOpenDrawer: openDrawer,
        ),
      AppPage.online => OnlineOrdersPanel(
          palette: p,
          orders: onlineOrders,
          onStatus: (order, status) => setState(() {
            final index = onlineOrders.indexWhere((o) => o.id == order.id);
            if (index >= 0) onlineOrders[index] = order.copyWith(status: status);
          }),
        ),
      AppPage.history => HistoryPanel(palette: p, orders: completed),
      AppPage.reports => ReportsPanel(palette: p, orders: completed),
      AppPage.settings => SettingsPanel(
          palette: p,
          payment: payment,
          kiosks: kioskTerminals,
          paymentOnline: paymentOnline,
          lastBatch: lastBatch,
          onChanged: () {
            setState(() {});
            checkPayment();
          },
          onTestSale: () async {
            setState(() => busy = true);
            try {
              final r = await sale(0.01, 'TEST${DateTime.now().millisecondsSinceEpoch % 1000000}');
              showSnack(r['ok'] == true ? 'Test sale approved' : 'Test sale declined');
            } catch (err) {
              showSnack('Test sale failed: $err');
            } finally {
              if (mounted) setState(() => busy = false);
            }
          },
          onBatchClose: runBatchClose,
        ),
    };
  }

  void showPaymentSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: p.panel,
      builder: (_) => PaymentSheet(
        palette: p,
        total: total,
        payment: payment,
        busy: busy,
        onCash: () async {
          Navigator.pop(context);
          await completeSale(method: 'cash');
        },
        onGiftCard: () async {
          Navigator.pop(context);
          await completeSale(method: 'giftcard');
        },
        onCard: (tip) async {
          setState(() => busy = true);
          try {
            final amount = total + tip;
            final response = await sale(amount, 'VF$orderNumber', tip: tip);
            final result = Map<String, dynamic>.from(response['result'] ?? response);
            if (!mounted) return;
            if (response['ok'] == true || result['approved'] == true || result['status'] == 'approved') {
              Navigator.pop(context);
              await completeSale(
                method: 'card',
                tip: (result['tipAmount'] as num? ?? tip).toDouble(),
                authCode: result['authCode']?.toString(),
                last4: last4(result['maskedCard']?.toString() ?? result['cardLast4']?.toString()),
              );
            } else {
              showSnack(result['responseMessage']?.toString() ?? 'Card declined');
            }
          } catch (err) {
            showSnack('Card payment failed: $err');
          } finally {
            if (mounted) setState(() => busy = false);
          }
        },
      ),
    );
  }
}

String? last4(String? value) {
  if (value == null) return null;
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length < 4) return null;
  return digits.substring(digits.length - 4);
}

class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.palette,
    required this.page,
    required this.paymentOnline,
    required this.dark,
    required this.onToggleTheme,
    required this.onPage,
    required this.onRefreshPayment,
  });

  final Palette palette;
  final AppPage page;
  final bool paymentOnline;
  final bool dark;
  final VoidCallback onToggleTheme;
  final ValueChanged<AppPage> onPage;
  final VoidCallback onRefreshPayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(color: palette.panel, border: Border(bottom: BorderSide(color: palette.border))),
      child: Row(
        children: [
          Image.asset('assets/vido-foody-logo.png', width: 170, height: 46, fit: BoxFit.contain),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  NavButton(palette: palette, label: 'Sell', selected: page == AppPage.sell, onTap: () => onPage(AppPage.sell)),
                  NavButton(palette: palette, label: 'Operations', selected: page == AppPage.operations, onTap: () => onPage(AppPage.operations)),
                  NavButton(palette: palette, label: 'Online Orders', selected: page == AppPage.online, onTap: () => onPage(AppPage.online)),
                  NavButton(palette: palette, label: 'History', selected: page == AppPage.history, onTap: () => onPage(AppPage.history)),
                  NavButton(palette: palette, label: 'Reports', selected: page == AppPage.reports, onTap: () => onPage(AppPage.reports)),
                  NavButton(palette: palette, label: 'Settings', selected: page == AppPage.settings, onTap: () => onPage(AppPage.settings)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onToggleTheme,
            color: palette.text,
            icon: Icon(dark ? Icons.dark_mode : Icons.light_mode),
          ),
          InkWell(
            onTap: onRefreshPayment,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: paymentOnline ? success.withOpacity(0.14) : danger.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                paymentOnline ? 'Payment Online' : 'Payment Offline',
                style: TextStyle(color: paymentOnline ? success : danger, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NavButton extends StatelessWidget {
  const NavButton({super.key, required this.palette, required this.label, required this.selected, required this.onTap});
  final Palette palette;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: FilledButton.tonal(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: selected ? brand : palette.card,
          foregroundColor: selected ? Colors.black : palette.text,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class SellPanel extends StatelessWidget {
  const SellPanel({super.key, required this.palette, required this.category, required this.onCategory, required this.onAdd});
  final Palette palette;
  final String category;
  final ValueChanged<String> onCategory;
  final ValueChanged<MenuItemData> onAdd;

  @override
  Widget build(BuildContext context) {
    final items = defaultMenu.where((item) => item.category == category).toList();
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          SizedBox(
            height: 68,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final c in defaultCategories)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: ChoiceChip(
                      label: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        child: Text('${c.icon} ${c.name}', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                      ),
                      selected: c.id == category,
                      onSelected: (_) => onCategory(c.id),
                      selectedColor: brand,
                      backgroundColor: palette.card,
                      labelStyle: TextStyle(color: c.id == category ? Colors.black : palette.text),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: palette.border)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisExtent: 178,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
              ),
              itemCount: items.length,
              itemBuilder: (_, index) => MenuTile(palette: palette, item: items[index], onTap: () => onAdd(items[index])),
            ),
          ),
        ],
      ),
    );
  }
}

class MenuTile extends StatelessWidget {
  const MenuTile({super.key, required this.palette, required this.item, required this.onTap});
  final Palette palette;
  final MenuItemData item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: item.popular ? brand : palette.border, width: item.popular ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1.75,
              child: Container(
                decoration: BoxDecoration(color: brand.withOpacity(0.14), borderRadius: BorderRadius.circular(8)),
                child: Center(child: Text(item.icon, style: const TextStyle(fontSize: 38))),
              ),
            ),
            const SizedBox(height: 9),
            Row(
              children: [
                Expanded(child: Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: palette.text, fontWeight: FontWeight.w900, fontSize: 16))),
                Text(money(item.price), style: const TextStyle(color: brand2, fontWeight: FontWeight.w900, fontSize: 16)),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('+ Add', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CartPanel extends StatelessWidget {
  const CartPanel({
    super.key,
    required this.palette,
    required this.orderNumber,
    required this.orderType,
    required this.cart,
    required this.subtotal,
    required this.tax,
    required this.total,
    required this.onOrderType,
    required this.onQty,
    required this.onSize,
    required this.onClear,
    required this.onPay,
    required this.onOpenDrawer,
  });

  final Palette palette;
  final int orderNumber;
  final String orderType;
  final List<CartLine> cart;
  final double subtotal;
  final double tax;
  final double total;
  final ValueChanged<String> onOrderType;
  final void Function(CartLine, int) onQty;
  final void Function(CartLine, String) onSize;
  final VoidCallback onClear;
  final VoidCallback? onPay;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: palette.panel, border: Border(left: BorderSide(color: palette.border))),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text('Order #$orderNumber', style: TextStyle(color: palette.text, fontSize: 22, fontWeight: FontWeight.w900))),
              TextButton(onPressed: cart.isEmpty ? null : onClear, child: const Text('Clear')),
            ],
          ),
          Row(
            children: [
              for (final type in ['Dine In', 'To Go', 'Delivery'])
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilledButton.tonal(
                      onPressed: () => onOrderType(type),
                      style: FilledButton.styleFrom(backgroundColor: orderType == type ? brand : palette.card, foregroundColor: orderType == type ? Colors.black : palette.text),
                      child: Text(type, style: const TextStyle(fontWeight: FontWeight.w900)),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onOpenDrawer,
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Open Cash Drawer', style: TextStyle(fontWeight: FontWeight.w900)),
            ),
          ),
          Divider(color: palette.border),
          Expanded(
            child: cart.isEmpty
                ? Center(child: Text('No items yet.\nTap a drink to add it.', textAlign: TextAlign.center, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800)))
                : ListView(
                    children: [
                      for (final line in cart)
                        Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: palette.border)),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(child: Text(line.item.name, style: TextStyle(color: palette.text, fontWeight: FontWeight.w900))),
                                  Text(money(line.total), style: const TextStyle(color: brand2, fontWeight: FontWeight.w900)),
                                ],
                              ),
                              Row(
                                children: [
                                  SegmentedButton<String>(
                                    segments: const [
                                      ButtonSegment(value: 'R', label: Text('R')),
                                      ButtonSegment(value: 'L', label: Text('L +\$0.75')),
                                    ],
                                    selected: {line.size},
                                    onSelectionChanged: (v) => onSize(line, v.first),
                                    style: ButtonStyle(visualDensity: VisualDensity.compact, textStyle: MaterialStateProperty.all(const TextStyle(fontWeight: FontWeight.w900))),
                                  ),
                                  const Spacer(),
                                  IconButton(onPressed: () => onQty(line, -1), icon: const Icon(Icons.remove_circle_outline)),
                                  Text('${line.qty}', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900)),
                                  IconButton(onPressed: () => onQty(line, 1), icon: const Icon(Icons.add_circle_outline)),
                                ],
                              )
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          Totals(palette: palette, subtotal: subtotal, tax: tax, total: total),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onPay,
            style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black, minimumSize: const Size.fromHeight(60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            child: Text('Pay ${money(total)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class Totals extends StatelessWidget {
  const Totals({super.key, required this.palette, required this.subtotal, required this.tax, required this.total});
  final Palette palette;
  final double subtotal;
  final double tax;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      row('Subtotal', subtotal),
      row('Tax (8.75%)', tax),
      Divider(color: palette.border),
      row('Total', total, big: true),
    ]);
  }

  Widget row(String label, double value, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        Text(label, style: TextStyle(color: big ? palette.text : palette.muted, fontWeight: FontWeight.w800, fontSize: big ? 18 : 14)),
        const Spacer(),
        Text(money(value), style: TextStyle(color: big ? brand2 : palette.text, fontWeight: FontWeight.w900, fontSize: big ? 26 : 15)),
      ]),
    );
  }
}

class PaymentSheet extends StatefulWidget {
  const PaymentSheet({
    super.key,
    required this.palette,
    required this.total,
    required this.payment,
    required this.busy,
    required this.onCash,
    required this.onCard,
    required this.onGiftCard,
  });

  final Palette palette;
  final double total;
  final PaymentSettings payment;
  final bool busy;
  final VoidCallback onCash;
  final ValueChanged<double> onCard;
  final VoidCallback onGiftCard;

  @override
  State<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends State<PaymentSheet> {
  double tip = 0;

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 24 + MediaQuery.of(context).padding.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('Payment', style: TextStyle(color: p.text, fontSize: 24, fontWeight: FontWeight.w900)),
            const Spacer(),
            IconButton(onPressed: widget.busy ? null : () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.border)),
            child: Row(children: [
              Text('Total due', style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text(money(widget.total + tip), style: const TextStyle(fontSize: 28, color: brand2, fontWeight: FontWeight.w900)),
            ]),
          ),
          if (widget.payment.tipMode == TipMode.customerDisplay) ...[
            const SizedBox(height: 14),
            Text('Suggested Tips', style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              children: [
                for (final pct in widget.payment.tipPercents)
                  ChoiceChip(
                    label: Text('$pct%  ${money(widget.total * pct / 100)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                    selected: (tip - widget.total * pct / 100).abs() < 0.01,
                    onSelected: (_) => setState(() => tip = (widget.total * pct / 100 * 100).round() / 100),
                    selectedColor: brand,
                  ),
                ChoiceChip(label: const Text('No Tip'), selected: tip == 0, onSelected: (_) => setState(() => tip = 0)),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: payButton('Cash', Icons.payments_outlined, widget.busy ? null : widget.onCash, p)),
            const SizedBox(width: 12),
            Expanded(child: payButton('Card Payment', Icons.credit_card, widget.busy ? null : () => widget.onCard(tip), p, highlight: true)),
            const SizedBox(width: 12),
            Expanded(child: payButton('Gift Card', Icons.card_giftcard, widget.busy ? null : widget.onGiftCard, p)),
          ]),
          if (widget.payment.tipMode == TipMode.paxTerminal)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text('Tip will be collected on the PAX terminal when supported.', style: TextStyle(color: p.muted, fontWeight: FontWeight.w800)),
            ),
          if (widget.busy) ...[
            const SizedBox(height: 20),
            const LinearProgressIndicator(color: brand),
            const SizedBox(height: 10),
            Center(child: Text('Waiting for card terminal...', style: TextStyle(color: p.muted, fontWeight: FontWeight.w800))),
          ],
        ],
      ),
    );
  }

  Widget payButton(String label, IconData icon, VoidCallback? onTap, Palette p, {bool highlight = false}) {
    return FilledButton.tonalIcon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: highlight ? brand : p.card,
        foregroundColor: highlight ? Colors.black : p.text,
        padding: const EdgeInsets.symmetric(vertical: 22),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Icon(icon),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
    );
  }
}

class OperationsPanel extends StatelessWidget {
  const OperationsPanel({
    super.key,
    required this.palette,
    required this.orders,
    required this.onlineOrders,
    required this.paymentOnline,
    required this.lastBatch,
    required this.onBatchClose,
    required this.onOpenDrawer,
  });
  final Palette palette;
  final List<OrderRecord> orders;
  final List<OnlineOrder> onlineOrders;
  final bool paymentOnline;
  final String lastBatch;
  final VoidCallback? onBatchClose;
  final VoidCallback onOpenDrawer;

  @override
  Widget build(BuildContext context) {
    final cash = orders.where((o) => o.paymentMethod == 'cash').fold<double>(0, (s, o) => s + o.total);
    final card = orders.where((o) => o.paymentMethod == 'card').fold<double>(0, (s, o) => s + o.total);
    return ScreenPad(
      palette: palette,
      title: 'Operations',
      child: Wrap(spacing: 14, runSpacing: 14, children: [
        StatCard(palette: palette, label: 'Open Online Orders', value: '${onlineOrders.where((o) => o.status == 'new').length}'),
        StatCard(palette: palette, label: 'Payment Terminal', value: paymentOnline ? 'Online' : 'Offline', color: paymentOnline ? success : danger),
        StatCard(palette: palette, label: 'Cash Expected', value: money(cash)),
        StatCard(palette: palette, label: 'Card Sales', value: money(card)),
        ActionCard(palette: palette, title: 'Close Batch / Settlement', subtitle: lastBatch, icon: Icons.account_balance, onTap: onBatchClose),
        ActionCard(palette: palette, title: 'Open Cash Drawer', subtitle: 'Sends drawer kick through printer/device bridge', icon: Icons.inventory_2_outlined, onTap: onOpenDrawer),
      ]),
    );
  }
}

class OnlineOrdersPanel extends StatelessWidget {
  const OnlineOrdersPanel({super.key, required this.palette, required this.orders, required this.onStatus});
  final Palette palette;
  final List<OnlineOrder> orders;
  final void Function(OnlineOrder order, String status) onStatus;

  @override
  Widget build(BuildContext context) {
    return ScreenPad(
      palette: palette,
      title: 'Online Orders',
      child: orders.isEmpty
          ? Center(child: Text('No online orders yet', style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800)))
          : ListView(
              children: [
                for (final order in orders)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: palette.border)),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${order.id} · ${order.source}', style: TextStyle(color: palette.text, fontSize: 18, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 4),
                          Text('${order.customer} · ${order.paymentStatus} · ${order.status}', style: TextStyle(color: palette.muted, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 8),
                          Text(order.items.join('  ·  '), style: TextStyle(color: palette.text, fontWeight: FontWeight.w700)),
                        ]),
                      ),
                      Text(money(order.total), style: const TextStyle(color: brand2, fontSize: 22, fontWeight: FontWeight.w900)),
                      const SizedBox(width: 12),
                      FilledButton(onPressed: () => onStatus(order, 'accepted'), child: const Text('Accept')),
                      const SizedBox(width: 8),
                      FilledButton.tonal(onPressed: () => onStatus(order, 'ready'), child: const Text('Ready')),
                      const SizedBox(width: 8),
                      OutlinedButton(onPressed: () => onStatus(order, 'completed'), child: const Text('Complete')),
                    ]),
                  )
              ],
            ),
    );
  }
}

class HistoryPanel extends StatelessWidget {
  const HistoryPanel({super.key, required this.palette, required this.orders});
  final Palette palette;
  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    return ScreenPad(
      palette: palette,
      title: 'Order History',
      child: orders.isEmpty
          ? Center(child: Text('No completed orders yet', style: TextStyle(color: palette.muted)))
          : ListView(children: [
              for (final order in orders)
                ListTile(
                  tileColor: palette.card,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: palette.border)),
                  title: Text('Order #${order.number}', style: TextStyle(color: palette.text, fontWeight: FontWeight.w900)),
                  subtitle: Text('${order.paymentMethod} · ${order.source} · ${order.items.length} item lines'),
                  trailing: Text(money(order.total), style: const TextStyle(color: brand2, fontWeight: FontWeight.w900, fontSize: 18)),
                ),
            ]),
    );
  }
}

class ReportsPanel extends StatelessWidget {
  const ReportsPanel({super.key, required this.palette, required this.orders});
  final Palette palette;
  final List<OrderRecord> orders;

  @override
  Widget build(BuildContext context) {
    final sales = orders.fold<double>(0, (sum, order) => sum + order.total);
    final gross = orders.fold<double>(0, (sum, order) => sum + order.subtotal);
    final tax = orders.fold<double>(0, (sum, order) => sum + order.tax);
    final tips = orders.fold<double>(0, (sum, order) => sum + order.tip);
    final cards = orders.where((order) => order.paymentMethod == 'card').fold<double>(0, (sum, order) => sum + order.total);
    final cash = orders.where((order) => order.paymentMethod == 'cash').fold<double>(0, (sum, order) => sum + order.total);
    final gift = orders.where((order) => order.paymentMethod == 'giftcard').fold<double>(0, (sum, order) => sum + order.total);
    return ScreenPad(
      palette: palette,
      title: 'Reports',
      child: Wrap(spacing: 14, runSpacing: 14, children: [
        StatCard(palette: palette, label: 'Net Sales', value: money(sales)),
        StatCard(palette: palette, label: 'Gross Sales', value: money(gross)),
        StatCard(palette: palette, label: 'Orders', value: '${orders.length}'),
        StatCard(palette: palette, label: 'Tax', value: money(tax)),
        StatCard(palette: palette, label: 'Tips', value: money(tips)),
        StatCard(palette: palette, label: 'Card Payment', value: money(cards)),
        StatCard(palette: palette, label: 'Cash', value: money(cash)),
        StatCard(palette: palette, label: 'Gift Card', value: money(gift)),
      ]),
    );
  }
}

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.palette,
    required this.payment,
    required this.kiosks,
    required this.paymentOnline,
    required this.lastBatch,
    required this.onChanged,
    required this.onTestSale,
    required this.onBatchClose,
  });

  final Palette palette;
  final PaymentSettings payment;
  final List<KioskTerminalSettings> kiosks;
  final bool paymentOnline;
  final String lastBatch;
  final VoidCallback onChanged;
  final Future<void> Function() onTestSale;
  final Future<void> Function() onBatchClose;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late final backend = TextEditingController(text: widget.payment.backendUrl);
  late final ip = TextEditingController(text: widget.payment.terminalIp);
  late final port = TextEditingController(text: widget.payment.terminalPort.toString());
  late final timeout = TextEditingController(text: widget.payment.timeoutMs.toString());

  @override
  void dispose() {
    backend.dispose();
    ip.dispose();
    port.dispose();
    timeout.dispose();
    super.dispose();
  }

  void save() {
    widget.payment.backendUrl = backend.text.trim();
    widget.payment.terminalIp = ip.text.trim();
    widget.payment.terminalPort = int.tryParse(port.text.trim()) ?? 10009;
    widget.payment.timeoutMs = int.tryParse(timeout.text.trim()) ?? 60000;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return ScreenPad(
      palette: p,
      title: 'Settings',
      child: ListView(children: [
        SettingsCard(palette: p, title: 'Payment Settings', children: [
          field('Backend URL', backend),
          DropdownButtonFormField<String>(
            value: widget.payment.connectionMode,
            decoration: inputDecoration('Connection Type', p),
            items: const [
              DropdownMenuItem(value: 'tcp', child: Text('TCP/IP')),
              DropdownMenuItem(value: 'usb', child: Text('USB')),
              DropdownMenuItem(value: 'serial', child: Text('Serial Number')),
            ],
            onChanged: (v) => setState(() => widget.payment.connectionMode = v ?? 'tcp'),
          ),
          const SizedBox(height: 12),
          field('Payment Terminal IP', ip),
          field('Payment Terminal Port', port, keyboard: TextInputType.number),
          field('Timeout (ms)', timeout, keyboard: TextInputType.number),
          SwitchListTile(
            value: widget.payment.useNativePosLink,
            onChanged: (v) => setState(() => widget.payment.useNativePosLink = v),
            title: Text('Use Flutter Android POSLink channel', style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
            subtitle: Text('Fallback is Node.js BroadPOS TCP for review/dev.', style: TextStyle(color: p.muted)),
          ),
          DropdownButtonFormField<TipMode>(
            value: widget.payment.tipMode,
            decoration: inputDecoration('Tip Mode', p),
            items: const [
              DropdownMenuItem(value: TipMode.customerDisplay, child: Text('Customer display / POS screen')),
              DropdownMenuItem(value: TipMode.paxTerminal, child: Text('PAX terminal tip prompt')),
              DropdownMenuItem(value: TipMode.off, child: Text('No tip prompt')),
            ],
            onChanged: (v) => setState(() => widget.payment.tipMode = v ?? TipMode.customerDisplay),
          ),
          const SizedBox(height: 14),
          Wrap(spacing: 12, children: [
            FilledButton(onPressed: save, style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black), child: const Text('Save Settings')),
            FilledButton.tonal(onPressed: widget.onTestSale, child: const Text('Test Sale \$0.01')),
            Text(widget.paymentOnline ? 'Connected' : 'Not connected', style: TextStyle(color: widget.paymentOnline ? success : danger, fontWeight: FontWeight.w900)),
          ])
        ]),
        const SizedBox(height: 14),
        SettingsCard(palette: p, title: 'Settlement / Batch Close', children: [
          SwitchListTile(
            value: widget.payment.autoSettlement,
            onChanged: (v) => setState(() => widget.payment.autoSettlement = v),
            title: Text('Auto Settlement', style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
          ),
          DropdownButtonFormField<String>(
            value: widget.payment.settlementMode,
            decoration: inputDecoration('Settlement Control', p),
            items: const [
              DropdownMenuItem(value: 'pax_auto', child: Text('PAX/BroadPOS auto batch')),
              DropdownMenuItem(value: 'pos_controlled', child: Text('POS sends batch close')),
            ],
            onChanged: (v) => setState(() => widget.payment.settlementMode = v ?? 'pax_auto'),
          ),
          const SizedBox(height: 12),
          Text('Last Batch Close: ${widget.lastBatch}', style: TextStyle(color: p.muted, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          FilledButton.tonal(onPressed: widget.onBatchClose, child: const Text('Manual Batch Close')),
        ]),
        const SizedBox(height: 14),
        SettingsCard(palette: p, title: 'Kiosk Devices', children: [
          Text(
            'Manage Vido Foody Kiosk devices here. Each kiosk should have its own Device ID and its own assigned PAX terminal.',
            style: TextStyle(color: p.muted, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          ...[
            for (final kiosk in widget.kiosks)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: KioskDeviceEditor(
                  palette: p,
                  kiosk: kiosk,
                  onChanged: () {
                    widget.onChanged();
                    setState(() {});
                  },
                ),
              ),
          ],
          FilledButton.tonalIcon(
            onPressed: () {
              setState(() {
                final next = widget.kiosks.length + 1;
                widget.kiosks.add(KioskTerminalSettings(deviceId: 'KIOSK-$next', name: 'Kiosk $next'));
              });
              widget.onChanged();
            },
            icon: const Icon(Icons.add),
            label: const Text('Add Kiosk'),
          ),
        ]),
        const SizedBox(height: 14),
        SettingsCard(palette: p, title: 'Customer Display', children: [
          Text('Welcome text, logo, font size, auto on/off for second screen should be connected to Android DisplayManager via Flutter platform channel.', style: TextStyle(color: p.muted, fontWeight: FontWeight.w800)),
        ]),
      ]),
    );
  }

  Widget field(String label, TextEditingController controller, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, keyboardType: keyboard, decoration: inputDecoration(label, widget.palette)),
    );
  }
}

class KioskDeviceEditor extends StatefulWidget {
  const KioskDeviceEditor({super.key, required this.palette, required this.kiosk, required this.onChanged});
  final Palette palette;
  final KioskTerminalSettings kiosk;
  final VoidCallback onChanged;

  @override
  State<KioskDeviceEditor> createState() => _KioskDeviceEditorState();
}

class _KioskDeviceEditorState extends State<KioskDeviceEditor> {
  late final deviceId = TextEditingController(text: widget.kiosk.deviceId);
  late final name = TextEditingController(text: widget.kiosk.name);
  late final ip = TextEditingController(text: widget.kiosk.terminalIp);
  late final port = TextEditingController(text: widget.kiosk.terminalPort.toString());
  late final timeout = TextEditingController(text: widget.kiosk.timeoutMs.toString());

  @override
  void dispose() {
    deviceId.dispose();
    name.dispose();
    ip.dispose();
    port.dispose();
    timeout.dispose();
    super.dispose();
  }

  void save() {
    widget.kiosk.deviceId = deviceId.text.trim();
    widget.kiosk.name = name.text.trim();
    widget.kiosk.terminalIp = ip.text.trim();
    widget.kiosk.terminalPort = int.tryParse(port.text.trim()) ?? 10009;
    widget.kiosk.timeoutMs = int.tryParse(timeout.text.trim()) ?? 60000;
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: p.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: widget.kiosk.enabled,
          onChanged: (v) {
            setState(() => widget.kiosk.enabled = v);
            widget.onChanged();
          },
          title: Text(widget.kiosk.name, style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
          subtitle: Text('${widget.kiosk.deviceId} • ${widget.kiosk.connectionMode.toUpperCase()} • ${widget.kiosk.terminalIp}:${widget.kiosk.terminalPort}', style: TextStyle(color: p.muted)),
        ),
        Row(children: [
          Expanded(child: kioskField('Device ID', deviceId, p)),
          const SizedBox(width: 12),
          Expanded(child: kioskField('Kiosk Name', name, p)),
        ]),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: widget.kiosk.connectionMode,
              decoration: inputDecoration('PAX Connection', p),
              items: const [
                DropdownMenuItem(value: 'tcp', child: Text('TCP/IP')),
                DropdownMenuItem(value: 'usb', child: Text('USB via Android POSLink')),
              ],
              onChanged: (v) {
                setState(() => widget.kiosk.connectionMode = v ?? 'tcp');
                widget.onChanged();
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: kioskField('PAX Terminal IP', ip, p)),
        ]),
        Row(children: [
          Expanded(child: kioskField('Port', port, p, keyboard: TextInputType.number)),
          const SizedBox(width: 12),
          Expanded(child: kioskField('Timeout (ms)', timeout, p, keyboard: TextInputType.number)),
        ]),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: widget.kiosk.requirePaymentBeforeSend,
          onChanged: (v) {
            setState(() => widget.kiosk.requirePaymentBeforeSend = v);
            widget.onChanged();
          },
          title: Text('Require payment before sending order', style: TextStyle(color: p.text, fontWeight: FontWeight.w900)),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton(onPressed: save, style: FilledButton.styleFrom(backgroundColor: brand, foregroundColor: Colors.black), child: const Text('Save Kiosk')),
        ),
      ]),
    );
  }

  Widget kioskField(String label, TextEditingController controller, Palette p, {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: controller, keyboardType: keyboard, decoration: inputDecoration(label, p)),
    );
  }
}

InputDecoration inputDecoration(String label, Palette p) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: p.card,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: p.border)),
  );
}

class ScreenPad extends StatelessWidget {
  const ScreenPad({super.key, required this.palette, required this.title, required this.child});
  final Palette palette;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: palette.text, fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        Expanded(child: child),
      ]),
    );
  }
}

class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.palette, required this.title, required this.children});
  final Palette palette;
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: palette.panel, borderRadius: BorderRadius.circular(8), border: Border.all(color: palette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(color: palette.text, fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 14),
        ...children,
      ]),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.palette, required this.label, required this.value, this.color = brand2});
  final Palette palette;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: palette.card, borderRadius: BorderRadius.circular(8), border: Border.all(color: palette.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(color: palette.muted, fontSize: 12, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(fontSize: 25, color: color, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.palette, required this.title, required this.subtitle, required this.icon, required this.onTap});
  final Palette palette;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: FilledButton.tonalIcon(
        onPressed: onTap,
        style: FilledButton.styleFrom(backgroundColor: palette.card, foregroundColor: palette.text, padding: const EdgeInsets.all(18), alignment: Alignment.centerLeft),
        icon: Icon(icon, color: brand),
        label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(color: palette.muted, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}

extension FirstOrNull<T> on Iterable<T?> {
  T? get firstOrNull => isEmpty ? null : first;
}
