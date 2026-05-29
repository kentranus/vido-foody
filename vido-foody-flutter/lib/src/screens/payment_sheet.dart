import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../state/cart.dart';
import '../state/catalog.dart';
import '../services/cfd_controller.dart';
import '../services/pax_service.dart';

class PaymentSheet extends ConsumerStatefulWidget {
  final Cart cart;
  final String method;
  const PaymentSheet({super.key, required this.cart, required this.method});
  @override
  ConsumerState<PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<PaymentSheet> {
  bool _processing = false;
  String? _statusMsg;
  bool _failed = false;
  PaxSaleResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(cfdControllerProvider).enterPayment(
        cart: widget.cart, method: widget.method,
      );
    });
  }

  Future<void> _confirm() async {
    setState(() { _processing = true; _statusMsg = null; _failed = false; });

    if (widget.method == 'card') {
      await _runCardPayment();
    } else {
      setState(() => _statusMsg = 'Printing customer receipt and kitchen ticket…');
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      ref.read(cfdControllerProvider).markCompleted(cart: widget.cart);
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _runCardPayment() async {
    final pax = ref.read(paxServiceProvider);
    final cart = widget.cart;
    final amountCents = (cart.total * 100).round();
    final taxCents    = (cart.tax * 100).round();
    final ecrRefNum   = 'V${DateTime.now().millisecondsSinceEpoch}';

    setState(() => _statusMsg = 'Connecting to terminal…');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted && _processing) {
        setState(() => _statusMsg = 'Follow prompts on the card terminal');
      }
    });

    final res = await pax.sale(
      amountCents: amountCents,
      taxCents: taxCents,
      ecrRefNum: ecrRefNum,
      invoiceNum: cart.number.toString(),
    );

    if (!mounted) return;
    setState(() { _result = res; });

    if (res.ok) {
      ref.read(cfdControllerProvider).markCompleted(cart: cart);
      setState(() => _statusMsg = 'Approved. Printing receipt + kitchen/drink ticket…');
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _processing = false;
        _failed = true;
        _statusMsg = _humanError(res);
      });
    }
  }

  String _humanError(PaxSaleResult r) {
    if (r.resultCode == 'INVALID_AMOUNT') return 'Invalid amount';
    if (r.resultCode == '100001' || r.resultText.contains('TIMEOUT')) {
      return 'Terminal did not respond. Check connection.';
    }
    if (r.hostText.isNotEmpty) return '${r.hostText} (${r.hostCode})';
    if (r.resultText.isNotEmpty) return '${r.resultText} (${r.resultCode})';
    return 'Payment failed';
  }

  @override
  Widget build(BuildContext context) {
    final methodLabel = {
      'cash': 'Cash', 'card': 'Card Payment', 'giftcard': 'Gift Card',
    }[widget.method] ?? widget.method;
    final methodIcon = {
      'cash': Icons.attach_money,
      'card': Icons.credit_card,
      'giftcard': Icons.card_giftcard,
    }[widget.method] ?? Icons.payment;
    final isCard = widget.method == 'card';

    return Container(
      decoration: const BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 18, 20, MediaQuery.of(context).padding.bottom + 18,
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          margin: const EdgeInsets.only(bottom: 14),
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: FC.border, borderRadius: BorderRadius.circular(4),
          ),
        )),
        const Text('Payment',
          style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: FC.primaryGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('AMOUNT TO PAY',
              style: TextStyle(
                color: Color(0xCC000000), fontWeight: FontWeight.w900,
                fontSize: 11, letterSpacing: 0.8)),
            const SizedBox(height: 4),
            Text('$kCurrencySymbol${widget.cart.total.toStringAsFixed(2)}',
              style: const TextStyle(color: FC.bg, fontWeight: FontWeight.w900, fontSize: 36)),
            const SizedBox(height: 4),
            Text('${widget.cart.lines.length} items · Order #${widget.cart.number}',
              style: const TextStyle(color: Color(0xCC000000), fontWeight: FontWeight.w700, fontSize: 12)),
          ]),
        ),
        const SizedBox(height: 14),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FC.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FC.border),
          ),
          child: Row(children: [
            Icon(methodIcon, color: FC.primary, size: 22),
            const SizedBox(width: 10),
            Text(methodLabel,
              style: const TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 14)),
            const Spacer(),
            if (isCard) _PaxBadge(),
          ]),
        ),

        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: FC.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: FC.border),
          ),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Print after complete',
              style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 12)),
            SizedBox(height: 5),
            Text('Customer receipt + kitchen/drink ticket. Route can be set to same receipt printer, kitchen printer, or drink label printer.',
              style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 11, height: 1.35)),
          ]),
        ),

        if (_statusMsg != null) Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _failed
                ? FC.red.withOpacity(0.12)
                : (_result?.ok == true ? FC.green.withOpacity(0.12) : FC.primaryA),
              border: Border.all(color: _failed
                ? FC.red.withOpacity(0.5)
                : (_result?.ok == true ? FC.green : FC.primary)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(_failed ? Icons.error_outline
                   : (_result?.ok == true ? Icons.check_circle : Icons.payment),
                color: _failed ? FC.red
                   : (_result?.ok == true ? FC.green : FC.primary), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_statusMsg!,
                style: TextStyle(
                  color: _failed ? FC.red : FC.text,
                  fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          ),
        ),
        if (_result?.ok == true && _result?.last4 != null && _result!.last4!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${_result!.cardType ?? "Card"} ending in ${_result!.last4} · '
              'Auth ${_result!.authCode ?? "-"}',
              style: const TextStyle(
                color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 11),
            ),
          ),

        const SizedBox(height: 16),

        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: FC.primary, foregroundColor: FC.bg,
              disabledBackgroundColor: FC.card,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: _processing ? null : _confirm,
            child: _processing
              ? const SizedBox(width: 20, height: 20, child:
                  CircularProgressIndicator(strokeWidth: 2, color: FC.bg))
              : Text(_failed ? 'Retry payment'
                     : (isCard ? 'Charge card' : 'Confirm payment'),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _processing ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel',
            style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w800)),
        ),
      ]),
    );
  }
}

class _PaxBadge extends ConsumerStatefulWidget {
  @override
  ConsumerState<_PaxBadge> createState() => _PaxBadgeState();
}

class _PaxBadgeState extends ConsumerState<_PaxBadge> {
  bool? _mock;
  @override
  void initState() {
    super.initState();
    ref.read(paxServiceProvider).isMockMode().then((m) {
      if (mounted) setState(() => _mock = m);
    });
  }
  @override
  Widget build(BuildContext context) {
    if (_mock == null) return const SizedBox.shrink();
    final mock = _mock!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: mock ? FC.orange.withOpacity(0.15) : FC.green.withOpacity(0.15),
        border: Border.all(color: mock ? FC.orange : FC.green),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(mock ? 'MOCK' : 'LIVE',
        style: TextStyle(
          color: mock ? FC.orange : FC.green,
          fontWeight: FontWeight.w900, fontSize: 9, letterSpacing: 0.5)),
    );
  }
}
