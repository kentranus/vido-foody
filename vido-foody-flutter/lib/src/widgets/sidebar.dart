import 'package:flutter/material.dart';
import '../theme.dart';

class Sidebar extends StatelessWidget {
  final ValueChanged<String>? onOpenFeature;
  final String activeLabel;
  const Sidebar({super.key, this.onOpenFeature, this.activeLabel = 'Order'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      decoration: const BoxDecoration(
        color: FC.panel,
        border: Border(right: BorderSide(color: FC.border)),
      ),
      child: Column(children: [
        const SizedBox(height: 16),
        ClipOval(
          child: SizedBox(
            width: 70,
            height: 70,
            child: Image.asset('assets/vido-foody-logo.png', fit: BoxFit.contain),
          ),
        ),
        const SizedBox(height: 8),
        const Text('Krishna',
          style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const Text("I'm a cashier",
          style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w700, fontSize: 10)),
        const SizedBox(height: 16),
        Expanded(child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.05,
            children: [
              _NavTile(icon: Icons.shopping_bag, label: 'Order',
                active: activeLabel == 'Order',
                onTap: () => onOpenFeature?.call('Order')),
              _NavTile(icon: Icons.receipt_long, label: 'Bills',
                active: activeLabel == 'Bills',
                onTap: () => onOpenFeature?.call('Bills')),
              _NavTile(icon: Icons.bar_chart, label: 'Reports',
                active: activeLabel == 'Reports',
                onTap: () => onOpenFeature?.call('Reports')),
              _NavTile(icon: Icons.settings, label: 'Setting',
                active: activeLabel == 'Settings',
                onTap: () => onOpenFeature?.call('Settings')),
              _NavTile(icon: Icons.public, label: 'Online',
                active: activeLabel == 'Online Orders',
                onTap: () => onOpenFeature?.call('Online Orders')),
              _NavTile(icon: Icons.storefront, label: 'Kiosk',
                active: activeLabel == 'Kiosk',
                onTap: () => onOpenFeature?.call('Kiosk')),
            ],
          ),
        )),
        Container(
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          padding: const EdgeInsets.all(12),
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: FC.primaryGradient,
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Column(children: [
            Text('🧑‍🍳', style: TextStyle(fontSize: 32)),
            SizedBox(height: 4),
            Text('Have a great\nshift today!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: FC.bg, fontWeight: FontWeight.w900, fontSize: 10, height: 1.3)),
          ]),
        ),
      ]),
    );
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;
  const _NavTile({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        backgroundColor: active ? Color.lerp(FC.card, FC.primary, 0.12) : FC.card,
      ),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? FC.primary : FC.border, width: active ? 2 : 1),
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 20, color: active ? FC.primary : FC.text),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            color: active ? FC.primary : FC.text,
            fontWeight: FontWeight.w900, fontSize: 11,
          )),
        ]),
      ),
    );
  }
}
