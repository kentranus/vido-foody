import 'package:flutter/material.dart';
import '../theme.dart';

class Sidebar extends StatelessWidget {
  final ValueChanged<String>? onOpenFeature;
  const Sidebar({super.key, this.onOpenFeature});

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
        Container(
          width: 70, height: 70,
          decoration: BoxDecoration(
            color: FC.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: FC.border),
            boxShadow: [
              BoxShadow(color: FC.primary.withOpacity(0.3),
                blurRadius: 18, offset: const Offset(0, 6)),
            ],
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(12),
          child: Image.asset('assets/vido-foody-logo.png', fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        const Text('Krishna',
          style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
        const Text("I'm a cashier 👋",
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
              const _NavTile(icon: Icons.shopping_bag, label: 'Order', active: true),
              _NavTile(icon: Icons.receipt_long, label: 'Bills',
                onTap: () => onOpenFeature?.call('Bills')),
              _NavTile(icon: Icons.bar_chart, label: 'Reports',
                onTap: () => onOpenFeature?.call('Reports')),
              _NavTile(icon: Icons.settings, label: 'Setting',
                onTap: () => onOpenFeature?.call('Settings')),
              _NavTile(icon: Icons.public, label: 'Online',
                onTap: () => onOpenFeature?.call('Online Orders')),
              _NavTile(icon: Icons.storefront, label: 'Kiosk',
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          color: active ? FC.primaryA : FC.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: active ? FC.primary : FC.border),
          boxShadow: active ? [
            BoxShadow(color: FC.primary.withOpacity(0.35),
              blurRadius: 14, offset: const Offset(0, 4)),
          ] : null,
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
