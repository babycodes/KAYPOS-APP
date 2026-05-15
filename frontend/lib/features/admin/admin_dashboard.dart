import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/helpers.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> summary = {'total_transactions': 0, 'total_sales': 0, 'avg_transaction': 0};
  List<dynamic> lowStock = [];
  List<dynamic> topProducts = [];
  List<dynamic> chartData = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        Api.get('/transactions/today'),
        Api.get('/inventory/low-stock'),
        Api.get('/reports/products?days=7'),
        Api.get('/reports/chart28'),
      ]);
      setState(() {
        summary = results[0];
        lowStock = results[1] as List;
        topProducts = ((results[2] as List).take(5)).toList();
        chartData = results[3] as List;
      });
    } catch (_) {}
  }

  String _fmtK(num n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}jt';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}rb';
    return '$n';
  }

  String _shortDate(String d) { final p = d.split('-'); return p.length >= 3 ? '${p[2]}/${p[1]}' : d; }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final chartMax = chartData.isEmpty ? 1.0 : chartData.map((d) => (d['sales'] as num).toDouble()).reduce((a, b) => a > b ? a : b).clamp(1.0, double.infinity);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(0), children: [
        // Summary Cards
        Row(children: [
          _summaryCard('Penjualan Hari Ini', fmtPrice(summary['total_sales'] ?? 0), cs.primaryContainer.withValues(alpha: 0.3), cs.primary, cs),
          const SizedBox(width: 8),
          _summaryCard('Jumlah Transaksi', '${summary['total_transactions'] ?? 0}', cs.secondaryContainer.withValues(alpha: 0.3), cs.secondary, cs),
          const SizedBox(width: 8),
          _summaryCard('Rata-rata / Transaksi', fmtPrice(summary['avg_transaction'] ?? 0), cs.tertiaryContainer.withValues(alpha: 0.3), cs.tertiary, cs),
        ]),
        const SizedBox(height: 16),

        // 28-Day Chart
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Icon(Icons.show_chart, size: 16, color: cs.onSurface), const SizedBox(width: 8),
              Text('Penjualan 28 Hari Terakhir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface))]),
            const SizedBox(height: 12),
            if (chartData.isEmpty)
              Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Belum ada data', style: TextStyle(color: cs.onSurfaceVariant))))
            else SizedBox(height: 140, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children:
              chartData.asMap().entries.map((e) {
                final d = e.value;
                final isToday = e.key == chartData.length - 1;
                final pct = chartMax > 0 ? ((d['sales'] as num) / chartMax) : 0.0;
                return Expanded(child: Tooltip(
                  message: '${_shortDate(d['date'] ?? '')}: ${_fmtK(d['sales'] ?? 0)} (${d['count']}x)',
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 0.5),
                    decoration: BoxDecoration(color: isToday ? cs.primary : cs.primary.withValues(alpha: 0.4), borderRadius: const BorderRadius.vertical(top: Radius.circular(2))),
                    height: (pct * 130).clamp(2.0, 140.0),
                  ),
                ));
              }).toList(),
            )),
            if (chartData.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(_shortDate(chartData.first['date'] ?? ''), style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
              Text('Hari ini', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
            ])),
          ]),
        ),
        const SizedBox(height: 16),

        // Low Stock + Top Products
        LayoutBuilder(builder: (_, constraints) {
          final isWide = constraints.maxWidth > 600;
          final children = [
            // Low Stock
            Expanded(flex: 1, child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.warning_amber, size: 16, color: cs.error), const SizedBox(width: 8),
                  Text('Stok Rendah', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface))]),
                const SizedBox(height: 8),
                if (lowStock.isEmpty) Text('Semua stok aman 👍', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))
                else ...lowStock.take(8).map((item) => Container(
                  margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.error.withValues(alpha: 0.1))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Expanded(child: Text(item['name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    Text('${(item['stock_quantity'] as num?)?.round() ?? 0} ${item['base_unit'] ?? ''}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.error)),
                  ]),
                )),
              ]),
            )),
            SizedBox(width: isWide ? 12 : 0, height: isWide ? 0 : 12),
            // Top Products
            Expanded(flex: 1, child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Icon(Icons.emoji_events, size: 16, color: cs.primary), const SizedBox(width: 8),
                  Text('Produk Terlaris (7 Hari)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: cs.onSurface))]),
                const SizedBox(height: 8),
                if (topProducts.isEmpty) Text('Belum ada data penjualan', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant))
                else ...topProducts.asMap().entries.map((e) => Container(
                  margin: const EdgeInsets.only(bottom: 4), padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Container(width: 24, height: 24, decoration: BoxDecoration(color: cs.primaryContainer, shape: BoxShape.circle),
                      child: Center(child: Text('${e.key + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(e.value['product_name'] ?? '', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                    Text(fmtPrice(e.value['total_revenue'] ?? 0), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
                  ]),
                )),
              ]),
            )),
          ];
          return isWide ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: children) : Column(children: children.map((c) => c is Expanded ? SizedBox(width: double.infinity, child: c.child) : c).toList());
        }),
      ]),
    );
  }

  Widget _summaryCard(String label, String value, Color bg, Color textColor, ColorScheme cs) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: textColor.withValues(alpha: 0.2))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: textColor)),
      ]),
    ));
  }
}
