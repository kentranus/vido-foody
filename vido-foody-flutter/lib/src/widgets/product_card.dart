import 'package:flutter/material.dart';
import '../theme.dart';
import '../state/catalog.dart';

class ProductCard extends StatelessWidget {
  final Product product;
  final bool inCart;
  final VoidCallback onAdd;
  const ProductCard({
    super.key, required this.product,
    required this.inCart, required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: FC.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF333842), Color(0xFF1F242D)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(product.emoji, style: const TextStyle(fontSize: 50)),
              )),
              const SizedBox(height: 8),
              Text(product.name,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FC.text, fontWeight: FontWeight.w900, fontSize: 13)),
              Text('${kCurrencySymbol}${product.price.toStringAsFixed(2)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: FC.primary, fontWeight: FontWeight.w900, fontSize: 12)),
              const SizedBox(height: 8),
              Container(
                height: 26,
                decoration: BoxDecoration(
                  color: FC.panel, borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: FC.border),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text('S', style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w900, fontSize: 11)),
                    Text('|', style: TextStyle(color: FC.border, fontSize: 11)),
                    Text('M', style: TextStyle(color: FC.text,     fontWeight: FontWeight.w900, fontSize: 11)),
                    Text('|', style: TextStyle(color: FC.border, fontSize: 11)),
                    Text('L', style: TextStyle(color: FC.textMute, fontWeight: FontWeight.w900, fontSize: 11)),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: double.infinity,
                  height: 32,
                  decoration: BoxDecoration(
                    color: inCart ? FC.primaryD : FC.primary,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    inCart ? 'Added' : '+ Add',
                    style: TextStyle(
                      color: FC.bg,
                      fontWeight: FontWeight.w900, fontSize: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
