import 'package:flutter/material.dart';
import 'package:auto_size_text/auto_size_text.dart';

class ProductCard extends StatelessWidget {
  final dynamic product;
  final int heldQty;
  final Function(dynamic) onSelect;
  const ProductCard({super.key, required this.product, required this.heldQty, required this.onSelect});

  Color _categoryColor(String? name, ColorScheme cs) {
    if (name == null || name.isEmpty) return cs.primary;
    final hash = name.hashCode.abs();
    final hues = [210, 260, 330, 170, 30, 190, 290, 140, 350, 50];
    final hue = hues[hash % hues.length].toDouble();
    return HSLColor.fromAHSL(1, hue, 0.5, 0.55).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final units = product['units'] as List? ?? [];
    final hasMultiUnits = units.length > 1;
    final categoryIcon = product['category_icon'] ?? '📦';
    final categoryName = product['category_name'] as String?;
    final accentColor = _categoryColor(categoryName, cs);
    final realStock = (product['stock_quantity'] as num?)?.toDouble() ?? double.infinity;
    final isReallyEmpty = realStock <= 0 && realStock != double.infinity;
    final availableStock = realStock == double.infinity ? double.infinity : (realStock - heldQty).clamp(0.0, double.infinity);
    final isBookedOut = !isReallyEmpty && availableStock <= 0 && heldQty > 0;
    final blocked = isReallyEmpty || isBookedOut;

    return Opacity(
      opacity: blocked ? 0.45 : 1.0,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: blocked ? null : () => onSelect(product),
          borderRadius: BorderRadius.circular(8),
          splashColor: accentColor.withValues(alpha: 0.2),
          hoverColor: accentColor.withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark ? accentColor.withValues(alpha: 0.1) : accentColor.withValues(alpha: 0.05),
              border: Border.all(color: accentColor.withValues(alpha: isDark ? 0.25 : 0.2)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Stack(clipBehavior: Clip.none, children: [
              Row(children: [
                // Icon
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: isDark ? accentColor.withValues(alpha: 0.2) : accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(categoryIcon, style: const TextStyle(fontSize: 16)),
                ),
                const SizedBox(width: 8),
                // Text Content
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Container(
                        alignment: Alignment.centerLeft,
                        child: AutoSizeText(
                          product['name'] ?? '',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: MediaQuery.sizeOf(context).width < 768 ? 12 : 14, color: cs.onSurface, height: 1.1),
                          maxLines: 2, 
                          minFontSize: 8,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    if (product['barcode'] != null && product['barcode'].toString().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(product['barcode'].toString(), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant.withValues(alpha: 0.8), height: 1.1), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    if (realStock != double.infinity)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text('Stok: ${availableStock.round()}', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: availableStock <= 0 ? cs.error : accentColor)),
                      ),
                  ],
                )),
              ]),

              // Badges
              if (isReallyEmpty) Positioned(top: -2, right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: cs.error, borderRadius: BorderRadius.circular(4)),
                  child: const Text('HABIS', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              )
              else if (isBookedOut) Positioned(top: -2, right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: Colors.amber[700], borderRadius: BorderRadius.circular(4)),
                  child: const Text('BOOKED', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w800, color: Colors.white)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
