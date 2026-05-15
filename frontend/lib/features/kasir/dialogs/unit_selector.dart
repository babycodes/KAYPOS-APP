import 'package:flutter/material.dart';
import '../../../core/helpers.dart';

class UnitSelectorDialog extends StatefulWidget {
  final dynamic product;
  final Function(dynamic, String, num) onConfirm;
  const UnitSelectorDialog({super.key, required this.product, required this.onConfirm});
  @override
  State<UnitSelectorDialog> createState() => _UnitSelectorDialogState();
}

class _UnitSelectorDialogState extends State<UnitSelectorDialog> {
  late String selectedUnit;
  double quantity = 1;
  late TextEditingController _qtyCtrl;

  @override
  void initState() {
    super.initState();
    selectedUnit = (widget.product['units'] as List?)?.first?['unit_name'] ?? '';
    _qtyCtrl = TextEditingController(text: '1');
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get selectedUnitData => (widget.product['units'] as List?)?.firstWhere((u) => u['unit_name'] == selectedUnit, orElse: () => null);
  double get pricePerOne => selectedUnitData != null ? (selectedUnitData!['price'] as num) / (selectedUnitData!['qty_per_unit'] as num) : 0;
  double get totalPrice => pricePerOne * quantity;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final units = widget.product['units'] as List? ?? [];

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Header
        Padding(padding: const EdgeInsets.all(20), child: Row(children: [
          Text(widget.product['category_icon'] ?? '📦', style: const TextStyle(fontSize: 24)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.product['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: cs.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(widget.product['category_name'] ?? '', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ])),
        ])),
        Divider(height: 1, color: cs.outlineVariant.withValues(alpha: 0.3)),
        Padding(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Pilih Satuan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
          const SizedBox(height: 8),
          GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 3,
            children: units.map<Widget>((u) {
              final selected = selectedUnit == u['unit_name'];
              return InkWell(onTap: () => setState(() => selectedUnit = u['unit_name']),
                borderRadius: BorderRadius.circular(12),
                child: Container(padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: selected ? cs.primary : cs.outlineVariant.withValues(alpha: 0.5), width: selected ? 2 : 1),
                    color: selected ? cs.primaryContainer.withValues(alpha: 0.3) : cs.surfaceContainer),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(u['unit_name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface)),
                    Text(fmtPrice(u['price'] ?? 0), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ])));
            }).toList()),
          const SizedBox(height: 20),
          // Quantity
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Jumlah', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
            Container(
              width: 180,
              decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
              padding: const EdgeInsets.all(4),
              child: Row(children: [
                InkWell(onTap: () { 
                  if (quantity > 0.25) {
                    setState(() { 
                      quantity = (quantity - (quantity >= 1 ? 1 : 0.25)); 
                      _qtyCtrl.text = quantity == quantity.roundToDouble() ? '${quantity.round()}' : quantity.toStringAsFixed(2);
                    }); 
                  }
                },
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.remove, size: 18, color: cs.onSurface))),
                Expanded(child: TextField(
                  controller: _qtyCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: cs.onSurface),
                  decoration: const InputDecoration(isDense: true, border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  onChanged: (v) {
                    final val = double.tryParse(v.replaceAll(',', '.'));
                    if (val != null && val >= 0) {
                      final maxStock = (widget.product['stock_quantity'] as num?)?.toDouble() ?? double.infinity;
                      final qtyPerUnit = (selectedUnitData?['qty_per_unit'] as num?)?.toDouble() ?? 1;
                      final maxAllowed = maxStock == double.infinity ? double.infinity : (maxStock / qtyPerUnit);
                      
                      if (val > maxAllowed) {
                        setState(() {
                          quantity = maxAllowed;
                          _qtyCtrl.text = maxAllowed == maxAllowed.roundToDouble() ? '${maxAllowed.round()}' : maxAllowed.toStringAsFixed(2);
                        });
                      } else {
                        setState(() => quantity = val);
                      }
                    }
                  },
                )),
                InkWell(onTap: () {
                  final maxStock = (widget.product['stock_quantity'] as num?)?.toDouble() ?? double.infinity;
                  final qtyPerUnit = (selectedUnitData?['qty_per_unit'] as num?)?.toDouble() ?? 1;
                  final maxAllowed = maxStock == double.infinity ? double.infinity : (maxStock / qtyPerUnit);
                  
                  if (quantity + 1 <= maxAllowed) {
                    setState(() { 
                      quantity += 1;
                      _qtyCtrl.text = quantity == quantity.roundToDouble() ? '${quantity.round()}' : quantity.toStringAsFixed(2);
                    });
                  } else if (quantity < maxAllowed) {
                    setState(() { 
                      quantity = maxAllowed;
                      _qtyCtrl.text = quantity == quantity.roundToDouble() ? '${quantity.round()}' : quantity.toStringAsFixed(2);
                    });
                  }
                },
                  child: Container(width: 44, height: 44, decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.add, size: 18, color: cs.onPrimary))),
              ])),
          ]),
          const SizedBox(height: 16),
          // Total
          Container(width: double.infinity, padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.secondary.withValues(alpha: 0.2))),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurface)),
              Text(fmtPrice(totalPrice), style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.secondary)),
            ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: SizedBox(height: 48, child: OutlinedButton(onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Batal')))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(height: 48, child: FilledButton.icon(
              onPressed: quantity > 0 ? () { Navigator.pop(context); widget.onConfirm(widget.product, selectedUnit, quantity); } : null,
              icon: const Icon(Icons.shopping_cart, size: 18),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 1),
              label: const Text('Tambah ke Keranjang', style: TextStyle(fontWeight: FontWeight.bold))))),
          ]),
        ])),
      ])),
    );
  }
}
