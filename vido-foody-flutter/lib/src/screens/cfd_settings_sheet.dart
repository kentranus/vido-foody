import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../state/cart.dart';
import '../services/customer_display_service.dart';

class CfdSettingsSheet extends ConsumerStatefulWidget {
  const CfdSettingsSheet({super.key});
  @override
  ConsumerState<CfdSettingsSheet> createState() => _CfdSettingsSheetState();
}

class _CfdSettingsSheetState extends ConsumerState<CfdSettingsSheet> {
  List<CfdDisplay> _displays = const [];
  bool _loading = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    _refresh();
    customerDisplayService.displays$.listen((list) {
      if (!mounted) return;
      setState(() => _displays = list);
    });
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _lastError = null; });
    final list = await customerDisplayService.listDisplays();
    if (!mounted) return;
    setState(() { _displays = list; _loading = false; });
  }

  Future<void> _tryShow(int? id) async {
    setState(() => _lastError = null);
    final ok = await customerDisplayService.show(displayId: id);
    if (!ok && mounted) {
      setState(() => _lastError = 'Không show được — kiểm tra log adb logcat | grep CFD');
    } else if (ok) {
      // Force "enabled" so cart auto-syncs
      ref.read(cfdEnabledProvider.notifier).state = true;
      if (id != null) ref.read(cfdDisplayIdProvider.notifier).state = id;
      await _demoPush();
    }
  }

  Future<void> _demoPush() async {
    await customerDisplayService.update({
      'state': 'order',
      'shop': {'name': 'Vido Foody', 'currencySymbol': '\$'},
      'orderNumber': 9999,
      'items': [
        {'name':'Bubble Milk Tea','emoji':'🧋','details':'Large · 50% Sugar','qty':2,'total':9.00},
        {'name':'Iced Milk Coffee','emoji':'☕','details':'Medium','qty':1,'total':3.50},
      ],
      'subtotal':12.50,'discount':0,'tax':1.00,'total':13.50,
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = ref.watch(cfdEnabledProvider);
    final displayId = ref.watch(cfdDisplayIdProvider);
    final secondary = _displays.where((d) => !d.isPrimary).toList();
    final hasSecondary = secondary.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        20, 18, 20, MediaQuery.of(context).padding.bottom + 18,
      ),
      child: SingleChildScrollView(child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: FC.border, borderRadius: BorderRadius.circular(4),
            ),
          )),
          Row(children: [
            const Icon(Icons.monitor, color: FC.primary, size: 22),
            const SizedBox(width: 8),
            const Expanded(child: Text('Customer Display',
              style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 16))),
            Switch.adaptive(
              value: enabled, activeColor: FC.primary,
              onChanged: hasSecondary
                ? (v) => ref.read(cfdEnabledProvider.notifier).state = v
                : null,
            ),
          ]),
          const SizedBox(height: 4),

          // === DIAGNOSTIC PANEL ===
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: FC.card, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: FC.border),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_displays.length > 1 ? Icons.check_circle : Icons.info_outline,
                  color: _displays.length > 1 ? FC.green : FC.orange, size: 16),
                const SizedBox(width: 6),
                Text('Android detected: ${_displays.length} display(s)',
                  style: const TextStyle(
                    color: FC.text, fontWeight: FontWeight.w900, fontSize: 12)),
              ]),
              const SizedBox(height: 8),
              ..._displays.map((d) => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '  • ID ${d.id} — ${d.name}'
                  '${d.isPrimary ? "  [PRIMARY]" : "  [secondary]"}'
                  '${d.isPresentation ? "  [Presentation]" : ""}'
                  '${d.sizeLabel.isNotEmpty ? "  ${d.sizeLabel}" : ""}',
                  style: const TextStyle(
                    color: FC.textMute, fontWeight: FontWeight.w700,
                    fontSize: 11, fontFamily: 'monospace'),
                ),
              )),
              if (_lastError != null) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_lastError!, style: const TextStyle(
                  color: FC.red, fontWeight: FontWeight.w700, fontSize: 11)),
              ),
            ]),
          ),

          if (!hasSecondary) Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: FC.orange.withOpacity(0.12),
              border: Border.all(color: FC.orange.withOpacity(0.5)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.warning_amber, color: FC.orange, size: 16),
                SizedBox(width: 6),
                Text('No secondary display detected',
                  style: TextStyle(color: FC.orange, fontWeight: FontWeight.w900, fontSize: 13)),
              ]),
              SizedBox(height: 8),
              Text('On RK3588 POS devices, the customer-facing screen sometimes '
                   'needs to be enabled at the system level. Try:',
                style: TextStyle(color: FC.text, fontWeight: FontWeight.w700, fontSize: 12, height: 1.4)),
              SizedBox(height: 8),
              Text('1.  Settings → Display → Dual screen (if available)\n'
                   '2.  Settings → Display → External display → Extend\n'
                   '3.  Settings → System → Developer options →\n'
                   '       "Simulate secondary displays" → 720p (for testing)\n'
                   '4.  Contact OEM for "dual_screen=1" boot flag',
                style: TextStyle(
                  color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 11,
                  fontFamily: 'monospace', height: 1.5)),
            ]),
          ),

          if (secondary.isNotEmpty) ...[
            const SizedBox(height: 6),
            const Text('SELECT SECONDARY DISPLAY',
              style: TextStyle(
                color: FC.textMute, fontWeight: FontWeight.w800,
                fontSize: 10, letterSpacing: 0.8)),
            const SizedBox(height: 6),
            ...secondary.map((d) {
              final sel = displayId == d.id || (displayId == null && d == secondary.first);
              return InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => ref.read(cfdDisplayIdProvider.notifier).state = d.id,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? FC.primaryA : FC.card,
                    border: Border.all(color: sel ? FC.primary : FC.border),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    Icon(sel ? Icons.check_circle : Icons.radio_button_unchecked,
                      size: 16, color: sel ? FC.primary : FC.textMute),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d.name, style: TextStyle(
                          color: sel ? FC.primary : FC.text,
                          fontWeight: FontWeight.w900, fontSize: 13)),
                        Text('ID ${d.id}${d.sizeLabel.isNotEmpty ? " · ${d.sizeLabel}" : ""}'
                          '${d.isPresentation ? " · Presentation" : ""}',
                          style: const TextStyle(
                            color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 10)),
                      ],
                    )),
                  ]),
                ),
              );
            }),
            const SizedBox(height: 8),
          ],

          Row(children: [
            Expanded(child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(side: const BorderSide(color: FC.border)),
              icon: _loading
                ? const SizedBox(width: 14, height: 14, child:
                    CircularProgressIndicator(strokeWidth: 2, color: FC.text))
                : const Icon(Icons.refresh, size: 14, color: FC.text),
              label: const Text('Refresh',
                style: TextStyle(color: FC.text, fontWeight: FontWeight.w800)),
              onPressed: _loading ? null : _refresh,
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: FC.primary, foregroundColor: FC.bg,
                disabledBackgroundColor: FC.card,
                disabledForegroundColor: FC.textDim,
              ),
              icon: const Icon(Icons.play_arrow, size: 14),
              label: const Text('Test on first secondary',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 11)),
              onPressed: hasSecondary
                ? () => _tryShow(secondary.first.id)
                : null,
            )),
          ]),
        ],
      )),
    );
  }
}
