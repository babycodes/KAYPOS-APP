import 'package:flutter/material.dart';
import 'dart:convert';
import '../../../core/api.dart';
import '../../../core/helpers.dart';
import '../../../services/printer_service.dart';

class ReceiptModal extends StatefulWidget {
  final dynamic transaction;
  final List<Map<String, dynamic>> details;
  const ReceiptModal({super.key, required this.transaction, required this.details});
  @override
  State<ReceiptModal> createState() => _ReceiptModalState();
}

class _ReceiptModalState extends State<ReceiptModal> {
  bool _printing = false;
  String _printMsg = '';

  Future<void> _printReceipt() async {
    setState(() { _printing = true; _printMsg = ''; });
    try {
      if (!PrinterService().isConnected) {
        setState(() { _printMsg = '⚠️ Printer belum terhubung'; _printing = false; });
        return;
      }
      final res = await Api.post('/print/receipt', body: {'transaction_id': widget.transaction['id']});
      if (res['success'] == true && res['receipt_base64'] != null) {
        final bytes = base64Decode(res['receipt_base64']);
        await PrinterService().printReceipt(bytes.toList());
        setState(() => _printMsg = '✅ Nota berhasil dicetak!');
      } else {
        setState(() => _printMsg = '⚠️ Gagal format nota');
      }
    } catch (e) {
      setState(() => _printMsg = '⚠️ ${e.toString().replaceFirst("Exception: ", "")}');
    }
    setState(() => _printing = false);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 384),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Success Header
          Container(
            width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF22C55E), Color(0xFF059669)]),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(children: [
              Container(width: 64, height: 64, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.check, size: 36, color: Colors.white)),
              const SizedBox(height: 12),
              const Text('Transaksi Berhasil!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('#${widget.transaction['id']} — ${fmtDate(widget.transaction['created_at'] ?? '')}', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
            ]),
          ),
          // Items
          ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
            child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(20), children: [
              ...widget.details.map((d) => Padding(padding: const EdgeInsets.only(bottom: 8),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(d['product_name'] ?? '', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: cs.onSurface)),
                    Text('${d['quantity']} ${d['unit_used']} × ${fmtPrice(d['sold_price'] ?? 0)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ])),
                  Text(fmtPrice(d['subtotal'] ?? 0), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: cs.onSurface)),
                ]))),
              Divider(color: cs.outlineVariant),
              _row('Total', fmtPrice(widget.transaction['total_amount'] ?? 0), cs, bold: true),
              _row('Bayar', fmtPrice(widget.transaction['paid_amount'] ?? 0), cs),
              const SizedBox(height: 4),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Kembali', style: TextStyle(fontWeight: FontWeight.w600, color: cs.secondary, fontSize: 14)),
                  Text(fmtPrice(widget.transaction['change_amount'] ?? 0), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: cs.secondary)),
                ])),
            ])),
          // Print message
          if (_printMsg.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(width: double.infinity, padding: const EdgeInsets.all(8), margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: _printMsg.startsWith('✅') ? Colors.green.withValues(alpha: 0.1) : cs.errorContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(8)),
              child: Text(_printMsg, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _printMsg.startsWith('✅') ? Colors.green : cs.onSurfaceVariant), textAlign: TextAlign.center))),
          // Actions
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Row(children: [
            Expanded(child: SizedBox(height: 48, child: OutlinedButton(onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
              child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w600))))),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: SizedBox(height: 48, child: FilledButton.icon(
              onPressed: _printing ? null : _printReceipt, icon: _printing ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.print, size: 18),
              style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 1),
              label: Text(_printing ? 'Mencetak...' : 'Cetak Nota', style: const TextStyle(fontWeight: FontWeight.bold))))),
          ])),
        ]),
      ),
    );
  }

  Widget _row(String label, String value, ColorScheme cs, {bool bold = false}) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: bold ? FontWeight.bold : FontWeight.w600, color: cs.onSurface)),
      ]));
  }
}
