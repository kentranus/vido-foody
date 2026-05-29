import 'package:flutter/material.dart';
import '../theme.dart';
import '../state/catalog.dart';

class CategoryBar extends StatelessWidget {
  final String active;
  final ValueChanged<String> onSelect;
  const CategoryBar({super.key, required this.active, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: FC.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: FC.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('Choose Category',
            style: TextStyle(color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(width: 8),
          Text('${kCategories.length} categories',
            style: const TextStyle(color: FC.primary, fontWeight: FontWeight.w800, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        SizedBox(height: 40, child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _Pill(
              label: 'All Items', icon: '🍱',
              active: active == 'all',
              onTap: () => onSelect('all'),
            ),
            for (final c in kCategories) _Pill(
              label: c.name, icon: c.icon,
              active: active == c.id,
              onTap: () => onSelect(c.id),
            ),
          ],
        )),
      ]),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label, icon;
  final bool active;
  final VoidCallback onTap;
  const _Pill({
    required this.label, required this.icon, required this.active, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? FC.primaryA : FC.card;
    final border = active ? FC.primary : FC.border;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          shape: const StadiumBorder(),
          side: BorderSide(color: border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: active ? Colors.white.withOpacity(0.25) : FC.panel,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          Text(label, style: TextStyle(
            color: active ? FC.primary : FC.text,
            fontWeight: FontWeight.w900, fontSize: 12,
          )),
        ]),
      ),
    );
  }
}
