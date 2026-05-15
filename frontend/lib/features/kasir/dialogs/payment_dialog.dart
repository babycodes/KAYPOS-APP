import 'package:flutter/material.dart';
import '../../../core/helpers.dart';

String _fmtInput(String digits) {
  if (digits.isEmpty) return '';
  return digits.replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
}

class PaymentDialog extends StatefulWidget {
  final double total;
  final Function(double) onConfirm;
  const PaymentDialog({super.key, required this.total, required this.onConfirm});
  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  double paidAmount = 0;
  final _customCtrl = TextEditingController();

  final shortcuts = [
    {'label': 'Uang Pas', 'value': 'exact'},
    {'label': '10rb', 'value': 10000},
    {'label': '20rb', 'value': 20000},
    {'label': '50rb', 'value': 50000},
    {'label': '100rb', 'value': 100000},
    {'label': '200rb', 'value': 200000},
    {'label': '500rb', 'value': 500000},
    {'label': '1 Juta', 'value': 1000000},
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final change = paidAmount - widget.total;
    final isValid = paidAmount >= widget.total && widget.total > 0;

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9, maxWidth: 500),
      decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Text('Pembayaran', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
        const SizedBox(height: 16),
        // Total
        Container(
          width: double.infinity, padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: 0.2))),
          child: Column(children: [
            Text('TOTAL TAGIHAN', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontWeight: FontWeight.w600, letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(fmtPrice(widget.total), style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: cs.primary)),
          ]),
        ),
        const SizedBox(height: 16),
        // Shortcuts
        GridView.count(crossAxisCount: 4, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 2.2,
          children: shortcuts.map((s) {
            final val = s['value'] == 'exact' ? widget.total : (s['value'] as num).toDouble();
            final selected = paidAmount == val;
            return InkWell(
              onTap: () => setState(() { paidAmount = val; _customCtrl.text = _fmtInput('${val.round()}'); }),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: selected ? cs.primary : cs.outlineVariant, width: selected ? 2 : 1)),
                child: Center(child: Text(s['label'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cs.onSurface))),
              ),
            );
          }).toList()),
        const SizedBox(height: 16),
        // Custom input
        Text('ATAU MASUKKAN NOMINAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: _customCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.right,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface),
          decoration: InputDecoration(prefixText: 'Rp ', filled: true, fillColor: cs.surfaceContainer),
          onChanged: (v) {
            final digits = v.replaceAll(RegExp('[^0-9]'), '');
            final parsed = double.tryParse(digits) ?? 0;
            final formatted = _fmtInput(digits);
            if (_customCtrl.text != formatted) {
              _customCtrl.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
            }
            setState(() => paidAmount = parsed);
          },
        ),
        const SizedBox(height: 16),
        // Change
        if (paidAmount > 0) Container(
          width: double.infinity, padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: change >= 0 ? cs.secondaryContainer.withValues(alpha: 0.3) : cs.errorContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(12), border: Border.all(color: change >= 0 ? cs.secondary.withValues(alpha: 0.2) : cs.error.withValues(alpha: 0.2))),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(change >= 0 ? 'Kembalian' : 'Kurang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: change >= 0 ? cs.secondary : cs.error)),
            Text(fmtPrice(change.abs()), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: change >= 0 ? cs.secondary : cs.error)),
          ]),
        ),
        const SizedBox(height: 20),
        // Buttons
        Row(children: [
          Expanded(child: SizedBox(height: 56, child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
            child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600)),
          ))),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: SizedBox(height: 56, child: FilledButton(
            onPressed: isValid ? () { Navigator.pop(context); widget.onConfirm(paidAmount); } : null,
            style: FilledButton.styleFrom(backgroundColor: cs.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 1),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check, size: 20), SizedBox(width: 8), Text('Konfirmasi & Cetak', style: TextStyle(fontWeight: FontWeight.bold))]),
          ))),
        ]),
      ])),
    );
  }
}
