import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme.dart';
import '../state/cart.dart';

class TopBar extends ConsumerWidget {
  final bool isWide;
  final VoidCallback onOpenCfdSettings;
  final VoidCallback? onLogout;
  const TopBar({
    super.key,
    required this.isWide,
    required this.onOpenCfdSettings,
    this.onLogout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cfdEnabled = ref.watch(cfdEnabledProvider);
    return Material(
      color: FC.panel,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 64,
          padding: EdgeInsets.symmetric(horizontal: isWide ? 20 : 14),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: FC.border)),
          ),
          child: Row(children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Image.asset('assets/vido-foody-logo.png', fit: BoxFit.contain),
            ),
            const SizedBox(width: 16),
            if (isWide) Expanded(child: Container(
              height: 38,
              decoration: BoxDecoration(
                color: FC.card, borderRadius: BorderRadius.circular(999),
                border: Border.all(color: FC.border),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Row(children: [
                Icon(Icons.search, size: 16, color: FC.textMute),
                SizedBox(width: 10),
                Text('Search categories or menu...',
                  style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 13)),
              ]),
            )) else const Spacer(),
            const SizedBox(width: 12),
            InkWell(
              onTap: onOpenCfdSettings,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: cfdEnabled ? FC.primaryA : FC.card,
                  border: Border.all(color: cfdEnabled ? FC.primary : FC.border),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.monitor,
                    color: cfdEnabled ? FC.primary : FC.textMute, size: 16),
                  const SizedBox(width: 6),
                  Text(cfdEnabled ? 'Customer Display ON' : 'Customer Display',
                    style: TextStyle(
                      color: cfdEnabled ? FC.primary : FC.text,
                      fontWeight: FontWeight.w900, fontSize: 11)),
                ]),
              ),
            ),
            if (onLogout != null) ...[
              const SizedBox(width: 10),
              InkWell(
                onTap: onLogout,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: FC.card,
                    border: Border.all(color: FC.border),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.logout, color: FC.textMute, size: 16),
                    SizedBox(width: 6),
                    Text('Logout',
                      style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 11)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}
