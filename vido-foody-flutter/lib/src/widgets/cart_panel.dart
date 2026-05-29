import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../state/cart.dart';
import '../state/catalog.dart';

class CartPanel extends ConsumerWidget {
  final VoidCallback onCharge;
  const CartPanel({super.key, required this.onCharge});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final method = ref.watch(paymentMethodProvider);
    final dateLabel = DateFormat('EEEE d MMM yyyy').format(DateTime.now());

    return Container(
      decoration: const BoxDecoration(
        color: FC.panel,
        border: Border(left: BorderSide(color: FC.border)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FC.border)),
          ),
          child: Row(children: [
            const Text('New Order Bill',
              style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 14)),
            const Spacer(),
            Text(dateLabel,
              style: const TextStyle(
                color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 11)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: FC.primaryA, borderRadius: BorderRadius.circular(999),
              ),
              child: Text('Order #${cart.number}',
                style: const TextStyle(
                  color: FC.primary, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Row(children: [
              for (final t in const [
                {'id':'dinein','label':'Dine In','icon':'🏠'},
                {'id':'togo','label':'To Go','icon':'📦'},
                {'id':'delivery','label':'Delivery','icon':'🚚'},
              ]) Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _TypeChip(
                  label: t['label']!, icon: t['icon']!,
                  selected: cart.type == t['id'],
                  onTap: () => ref.read(cartProvider.notifier).setType(t['id']!),
                ),
              )),
            ])),
          ]),
        ),
        Expanded(
          child: cart.isEmpty
            ? Center(child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.shopping_cart, size: 48, color: FC.textDim),
                  SizedBox(height: 10),
                  Text('Cart is empty',
                    style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Tap items to add',
                    style: TextStyle(color: FC.textDim, fontWeight: FontWeight.w700, fontSize: 11)),
                ],
              ))
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                itemCount: cart.lines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _LineTile(
                  line: cart.lines[i],
                  onPlus:   () => ref.read(cartProvider.notifier).changeQty(cart.lines[i].key,  1),
                  onMinus:  () => ref.read(cartProvider.notifier).changeQty(cart.lines[i].key, -1),
                  onDelete: () => ref.read(cartProvider.notifier).remove(cart.lines[i].key),
                ),
              ),
        ),
        if (!cart.isEmpty) Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          decoration: const BoxDecoration(
            color: FC.panel,
            border: Border(top: BorderSide(color: FC.border)),
          ),
          child: Column(children: [
            _tot('Sub Total', cart.sub),
            _tot('Tax (${(kTaxRate * 100).toStringAsFixed(0)}%)', cart.tax,
              valueColor: FC.primary),
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: _Dashed()),
            _tot('Total', cart.total, labelColor: FC.red, bold: true, fontSize: 14),
            const SizedBox(height: 10),
            _MethodRow(
              selected: method,
              onSelect: (m) => ref.read(paymentMethodProvider.notifier).state = m,
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: FC.primary, foregroundColor: FC.bg,
                  disabledBackgroundColor: FC.card,
                  disabledForegroundColor: FC.textDim,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                onPressed: method == null ? null : onCharge,
                child: const Text('Place Order'),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _tot(String label, double v, {
    Color? labelColor, Color? valueColor, bool bold = false, double fontSize = 12,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: TextStyle(
        color: labelColor ?? FC.text,
        fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
        fontSize: fontSize,
      )),
      Text('${kCurrencySymbol}${v.toStringAsFixed(2)}',
        style: TextStyle(
          color: valueColor ?? FC.text,
          fontWeight: FontWeight.w900, fontSize: fontSize)),
    ]),
  );
}

class _TypeChip extends StatelessWidget {
  final String label, icon;
  final bool selected;
  final VoidCallback onTap;
  const _TypeChip({
    required this.label, required this.icon,
    required this.selected, required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(10),
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        decoration: BoxDecoration(
          color: selected ? FC.primaryA : FC.card,
          border: Border.all(color: selected ? FC.primary : FC.border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(icon, style: const TextStyle(fontSize: 14)),
          Text(label, style: TextStyle(
            color: selected ? FC.primary : FC.text,
            fontWeight: FontWeight.w800, fontSize: 9,
          )),
        ]),
      ),
    );
  }
}

class _LineTile extends StatelessWidget {
  final CartLine line;
  final VoidCallback onPlus, onMinus, onDelete;
  const _LineTile({
    required this.line,
    required this.onPlus, required this.onMinus, required this.onDelete,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: FC.card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: FC.border),
      ),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: FC.panel, borderRadius: BorderRadius.circular(999),
            border: Border.all(color: FC.border),
          ),
          alignment: Alignment.center,
          child: Text(line.product.emoji, style: const TextStyle(fontSize: 20)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(line.product.name,
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FC.text, fontWeight: FontWeight.w900, fontSize: 12)),
            Text(line.optionLabel,
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: FC.textDim, fontWeight: FontWeight.w700, fontSize: 10)),
            Text('${kCurrencySymbol}${line.lineTotal.toStringAsFixed(2)}',
              style: const TextStyle(
                color: FC.textMute, fontWeight: FontWeight.w800, fontSize: 11)),
            InkWell(
              onTap: onDelete,
              child: const Text('Remove', style: TextStyle(
                color: FC.red, fontWeight: FontWeight.w800, fontSize: 10,
                decoration: TextDecoration.underline,
              )),
            ),
          ],
        )),
        _QtyBtn(icon: Icons.remove, color: FC.orange, onTap: onMinus),
        SizedBox(width: 22, child: Center(child: Text('${line.qty}',
          style: const TextStyle(
            color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)))),
        _QtyBtn(icon: Icons.add, color: FC.primary, onTap: onPlus),
      ]),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap, borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 24, height: 24,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: FC.bg, size: 14),
      ),
    );
  }
}

class _MethodRow extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelect;
  const _MethodRow({required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    Widget m(IconData ic, String label, String id) {
      final on = selected == id;
      return Expanded(child: InkWell(
        onTap: () => onSelect(id), borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: on ? FC.primaryA : FC.card,
            border: Border.all(color: on ? FC.primary : FC.border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: [
            Icon(ic, color: on ? FC.primary : FC.text, size: 20),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(
              color: on ? FC.primary : FC.text,
              fontWeight: FontWeight.w800, fontSize: 9)),
          ]),
        ),
      ));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Payment Method',
        style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 11)),
      const SizedBox(height: 6),
      Row(children: [
        m(Icons.attach_money, 'Cash',       'cash'),
        const SizedBox(width: 6),
        m(Icons.credit_card,  'Card Payment', 'card'),
        const SizedBox(width: 6),
        m(Icons.card_giftcard, 'Gift Card', 'giftcard'),
      ]),
    ]);
  }
}

class _Dashed extends StatelessWidget {
  const _Dashed();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, c) {
      final n = (c.maxWidth / 6).floor();
      return SizedBox(height: 1, child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(n, (_) => Container(
          width: 3, height: 1, color: FC.border,
        )),
      ));
    });
  }
}
