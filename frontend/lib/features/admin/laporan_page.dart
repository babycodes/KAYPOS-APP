import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/helpers.dart';

class LaporanPage extends StatefulWidget {
  const LaporanPage({super.key});
  @override
  State<LaporanPage> createState() => _LaporanPageState();
}

class _LaporanPageState extends State<LaporanPage> {
  List<dynamic> transactions = [];
  int total = 0;
  
  late String dateFilter;
  late String monthFilter;
  late String yearFilter;
  
  String activeTab = 'day';
  
  int? expandedId;
  List<dynamic> expandedDetails = [];
  
  Map<String, dynamic> monthlySummary = {'total_transactions': 0, 'total_sales': 0};
  List<dynamic> monthlyDaily = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    dateFilter = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    monthFilter = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    yearFilter = '${now.year}';
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      if (activeTab == 'day') {
        final res = await Api.get('/transactions?date=$dateFilter&limit=200');
        if (mounted) setState(() {
          transactions = res['data'] ?? [];
          total = res['total'] ?? 0;
        });
      } else if (activeTab == 'month') {
        final parts = monthFilter.split('-');
        if (parts.length != 2) return;
        final res = await Api.get('/reports/monthly?month=${parts[1]}&year=${parts[0]}');
        if (mounted) setState(() {
          monthlySummary = res['summary'] ?? {'total_transactions': 0, 'total_sales': 0};
          monthlyDaily = res['daily'] ?? [];
        });
      } else {
        Map<String, dynamic> combinedSummary = {'total_transactions': 0, 'total_sales': 0};
        List<dynamic> combinedDaily = [];
        for (int m = 1; m <= 12; m++) {
          final ms = m.toString().padLeft(2, '0');
          try {
            final r = await Api.get('/reports/monthly?month=$ms&year=$yearFilter');
            final summ = r['summary'] ?? {};
            if ((summ['total_transactions'] ?? 0) > 0) {
              combinedSummary['total_transactions'] = (combinedSummary['total_transactions'] as num) + (summ['total_transactions'] as num);
              combinedSummary['total_sales'] = (combinedSummary['total_sales'] as num) + (summ['total_sales'] as num);
              combinedDaily.add({
                'date': '$yearFilter-$ms',
                'count': summ['total_transactions'],
                'sales': summ['total_sales']
              });
            }
          } catch (_) {}
        }
        if (mounted) setState(() {
          monthlySummary = combinedSummary;
          monthlyDaily = combinedDaily;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleExpand(int id) async {
    if (expandedId == id) {
      setState(() => expandedId = null);
      return;
    }
    try {
      final res = await Api.get('/transactions/$id');
      setState(() {
        expandedDetails = res['details'] ?? [];
        expandedId = id;
      });
    } catch (_) {}
  }

  void _switchTab(String tab) {
    setState(() { activeTab = tab; expandedId = null; });
    _loadData();
  }

  void _exportData() {
    final token = Api.getToken();
    String url = '';
    final base = Api.getApiBase();
    if (activeTab == 'day') {
      url = '$base/reports/export?type=day&date=$dateFilter&token=$token';
    } else if (activeTab == 'month') {
      final parts = monthFilter.split('-');
      url = '$base/reports/export?type=month&month=${parts[1]}&year=${parts[0]}&token=$token';
    } else {
      url = '$base/reports/export?type=year&year=$yearFilter&token=$token';
    }
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  double get totalSales {
    return transactions.fold(0.0, (sum, tx) => sum + ((tx['total_amount'] as num?)?.toDouble() ?? 0.0));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Top actions
      Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
        Container(
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
          padding: const EdgeInsets.all(4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TabBtn('Harian', 'day'),
            _TabBtn('Bulanan', 'month'),
            _TabBtn('Tahunan', 'year'),
          ]),
        ),
        FilledButton.icon(
          onPressed: _exportData,
          icon: const Icon(Icons.download, size: 16),
          label: const Text('Export Excel', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          style: FilledButton.styleFrom(backgroundColor: Colors.green[600], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ]),
      const SizedBox(height: 16),

      // Filters
      Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
        if (activeTab == 'day') ...[
          _DateField(),
          Text('$total transaksi', style: TextStyle(fontSize: 14, color: cs.onSurfaceVariant)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.primary.withValues(alpha: 0.2))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Total: ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              Text(fmtPrice(totalSales), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
            ]),
          )
        ] else if (activeTab == 'month') ...[
          _MonthField(),
        ] else ...[
          _YearField(),
        ]
      ]),
      const SizedBox(height: 16),

      if (activeTab != 'day') ...[
        Row(children: [
          Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cs.primaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('TOTAL PENJUALAN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(fmtPrice(monthlySummary['total_sales'] ?? 0), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.primary)),
            ]))),
          const SizedBox(width: 12),
          Expanded(child: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: cs.secondaryContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.secondary.withValues(alpha: 0.2))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('JUMLAH TRANSAKSI', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('${monthlySummary['total_transactions'] ?? 0}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.secondary)),
            ]))),
        ]),
        const SizedBox(height: 16),
        if (monthlyDaily.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Tidak ada data', style: TextStyle(color: cs.onSurfaceVariant))))
        else
          Expanded(child: _buildMonthlyDesktopTable(cs)),
      ] else ...[
        if (transactions.isEmpty)
          Center(child: Padding(padding: const EdgeInsets.all(32), child: Text('Tidak ada transaksi', style: TextStyle(color: cs.onSurfaceVariant))))
        else
          Expanded(child: isMobile ? _buildDailyMobileList(cs) : _buildDailyDesktopTable(cs)),
      ]
    ]);
  }

  Widget _TabBtn(String label, String val) {
    final active = activeTab == val;
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: () => _switchTab(val), borderRadius: BorderRadius.circular(8),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? cs.onPrimary : cs.onSurfaceVariant))));
  }

  // HTML Input for dates are tricky in pure Flutter without extra packages, 
  // we'll just use a text field with onSubmitted for simplicity or manual entry.
  Widget _DateField() {
    return SizedBox(width: 140, child: TextField(
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      controller: TextEditingController(text: dateFilter)..selection = TextSelection.collapsed(offset: dateFilter.length),
      onSubmitted: (v) { dateFilter = v; _loadData(); },
      keyboardType: TextInputType.datetime,
    ));
  }
  Widget _MonthField() {
    return SizedBox(width: 120, child: TextField(
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      controller: TextEditingController(text: monthFilter)..selection = TextSelection.collapsed(offset: monthFilter.length),
      onSubmitted: (v) { monthFilter = v; _loadData(); },
      keyboardType: TextInputType.datetime,
    ));
  }
  Widget _YearField() {
    return SizedBox(width: 100, child: TextField(
      decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)),
      controller: TextEditingController(text: yearFilter)..selection = TextSelection.collapsed(offset: yearFilter.length),
      onSubmitted: (v) { yearFilter = v; _loadData(); },
      keyboardType: TextInputType.number,
    ));
  }

  Widget _buildMonthlyDesktopTable(ColorScheme cs) {
    return Container(decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: ListView(children: [
        DataTable(
          headingRowColor: WidgetStatePropertyAll(cs.surfaceContainer),
          columns: [
            DataColumn(label: Text(activeTab == 'month' ? 'Tanggal' : 'Bulan', style: const TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Transaksi', style: TextStyle(fontWeight: FontWeight.bold))),
            const DataColumn(label: Text('Penjualan', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: monthlyDaily.map((d) => DataRow(cells: [
            DataCell(Text(d['date'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text('${d['count'] ?? 0}')),
            DataCell(Text(fmtPrice(d['sales'] ?? 0), style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary))),
          ])).toList(),
        )
      ])));
  }

  Widget _buildDailyDesktopTable(ColorScheme cs) {
    return Container(decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: ListView(children: [
        DataTable(
          headingRowColor: WidgetStatePropertyAll(cs.surfaceContainer),
          columns: const [
            DataColumn(label: Text('#', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Waktu')),
            DataColumn(label: Text('Kasir')),
            DataColumn(label: Text('Total')),
            DataColumn(label: Text('Bayar')),
            DataColumn(label: Text('Kembali')),
          ],
          rows: _buildDailyRows(cs),
        )
      ])));
  }

  List<DataRow> _buildDailyRows(ColorScheme cs) {
    List<DataRow> rows = [];
    for (var tx in transactions) {
      final tUrl = (tx['created_at'] ?? '').toString();
      final time = tUrl.contains(' ') ? tUrl.split(' ')[1] : tUrl;
      rows.add(DataRow(
        color: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.hovered) ? cs.surfaceContainer.withValues(alpha: 0.3) : null),
        cells: [
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text('#${tx['id']}', style: TextStyle(color: cs.onSurfaceVariant, fontFamily: 'monospace')))),
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text(time))),
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text(tx['cashier_name'] ?? '-'))),
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text(fmtPrice(tx['total_amount']), style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)))),
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text(fmtPrice(tx['paid_amount'])))),
          DataCell(InkWell(onTap: () => _toggleExpand(tx['id']), child: Text(fmtPrice(tx['change_amount']), style: TextStyle(color: cs.secondary)))),
        ]
      ));
      if (expandedId == tx['id']) {
        rows.add(DataRow(color: WidgetStatePropertyAll(cs.surfaceContainer.withValues(alpha: 0.2)), cells: [
          DataCell(
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: expandedDetails.map((d) => 
              Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(children: [
                Text('${d['product_name']} — ${d['quantity']} ${d['unit_used']}', style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 16),
                Text(fmtPrice(d['subtotal']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ]))
            ).toList())),
          ),
          const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()), const DataCell(SizedBox()),
        ]));
      }
    }
    return rows;
  }

  Widget _buildDailyMobileList(ColorScheme cs) {
    return ListView.builder(itemCount: transactions.length, itemBuilder: (ctx, i) {
      final tx = transactions[i];
      final tUrl = (tx['created_at'] ?? '').toString();
      final time = tUrl.contains(' ') ? tUrl.split(' ')[1] : tUrl;
      final isExpanded = expandedId == tx['id'];

      return Container(margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
        child: InkWell(onTap: () => _toggleExpand(tx['id']), borderRadius: BorderRadius.circular(12), child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('#${tx['id']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant, fontFamily: 'monospace')),
            Text(time, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
          ]),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tx['cashier_name'] ?? '-', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
            Text(fmtPrice(tx['total_amount']), style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: cs.primary)),
          ]),
          if (isExpanded) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            ...expandedDetails.map((d) => Padding(padding: const EdgeInsets.only(bottom: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('${d['product_name']} — ${d['quantity']} ${d['unit_used']}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              Text(fmtPrice(d['subtotal']), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
            ]))).toList(),
            const SizedBox(height: 4),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Bayar: ${fmtPrice(tx['paid_amount'])}', style: const TextStyle(fontSize: 11)),
              Text('Kembali: ${fmtPrice(tx['change_amount'])}', style: TextStyle(fontSize: 11, color: cs.secondary)),
            ])
          ]
        ]))));
    });
  }
}
