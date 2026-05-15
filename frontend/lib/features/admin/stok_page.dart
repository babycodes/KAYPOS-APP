import 'package:flutter/material.dart';
import '../../core/api.dart';
import '../../core/helpers.dart';

class StokPage extends StatefulWidget {
  const StokPage({super.key});
  @override
  State<StokPage> createState() => _StokPageState();
}

class _StokPageState extends State<StokPage> {
  List<dynamic> inventory = [];
  String filter = 'all';
  String searchQuery = '';
  
  int? editId;
  TextEditingController _stockCtrl = TextEditingController();
  TextEditingController _minAlertCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await Api.get('/inventory');
      if (mounted) setState(() => inventory = res as List);
    } catch (_) {}
  }

  List<dynamic> get filtered {
    var items = inventory;
    if (filter == 'low') {
      items = items.where((i) {
        final alert = (i['min_stock_alert'] as num?)?.toDouble() ?? 0;
        final qty = (i['stock_quantity'] as num?)?.toDouble() ?? 0;
        return alert > 0 && qty <= alert && qty > 0;
      }).toList();
    } else if (filter == 'empty') {
      items = items.where((i) => ((i['stock_quantity'] as num?)?.toDouble() ?? 0) <= 0).toList();
    }
    if (searchQuery.isNotEmpty) {
      final q = searchQuery.toLowerCase();
      items = items.where((i) => (i['name'] ?? '').toString().toLowerCase().contains(q)).toList();
    }
    return items;
  }

  void _openEdit(dynamic item) {
    setState(() {
      editId = item['product_id'];
      _stockCtrl.text = '${(item['stock_quantity'] as num?)?.round() ?? 0}';
      _minAlertCtrl.text = '${item['min_stock_alert'] ?? 0}';
    });
  }

  Future<void> _saveEdit(int productId) async {
    try {
      await Api.put('/inventory/$productId', body: {
        'stock_quantity': double.tryParse(_stockCtrl.text) ?? 0,
        'min_stock_alert': double.tryParse(_minAlertCtrl.text) ?? 0,
      });
      setState(() => editId = null);
      await _loadData();
      if (mounted) showToast(context, 'Stok diperbarui');
    } catch (e) {
      if (mounted) showToast(context, 'Gagal memperbarui stok: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final items = filtered;

    final lowCount = inventory.where((i) {
      final alert = (i['min_stock_alert'] as num?)?.toDouble() ?? 0;
      final qty = (i['stock_quantity'] as num?)?.toDouble() ?? 0;
      return alert > 0 && qty <= alert && qty > 0;
    }).length;
    
    final emptyCount = inventory.where((i) => ((i['stock_quantity'] as num?)?.toDouble() ?? 0) <= 0).length;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Top actions
      Wrap(spacing: 8, runSpacing: 8, children: [
        _FilterChip(label: 'Semua (${inventory.length})', active: filter == 'all', onTap: () => setState(() => filter = 'all')),
        _FilterChip(label: '⚠️ Rendah ($lowCount)', active: filter == 'low', onTap: () => setState(() => filter = 'low')),
        _FilterChip(label: '🚫 Habis ($emptyCount)', active: filter == 'empty', onTap: () => setState(() => filter = 'empty')),
      ]),
      const SizedBox(height: 16),
      
      // Search
      SizedBox(width: 400, child: TextField(
        decoration: InputDecoration(
          hintText: 'Cari produk...', prefixIcon: const Icon(Icons.search, size: 20),
          filled: true, fillColor: cs.surfaceContainerLow,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        ),
        onChanged: (v) => setState(() => searchQuery = v),
      )),
      const SizedBox(height: 16),

      // List
      Expanded(child: items.isEmpty
        ? Center(child: Text(filter == 'low' ? 'Semua stok aman 👍' : filter == 'empty' ? 'Tidak ada stok habis 👍' : 'Tidak ada data', style: TextStyle(color: cs.onSurfaceVariant)))
        : isMobile ? _buildMobileList(cs, items) : _buildDesktopTable(cs, items)),
    ]);
  }

  Widget _FilterChip({required String label, required bool active, required VoidCallback onTap}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20),
      child: Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? cs.primary : cs.surfaceContainer, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: active ? cs.onPrimary : cs.onSurfaceVariant))));
  }

  Widget _buildMobileList(ColorScheme cs, List<dynamic> items) {
    return ListView.builder(itemCount: items.length, itemBuilder: (ctx, i) {
      final item = items[i];
      final alert = (item['min_stock_alert'] as num?)?.toDouble() ?? 0;
      final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;
      final isLow = alert > 0 && qty <= alert;
      final editing = editId == item['product_id'];

      return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isLow ? cs.error.withValues(alpha: 0.3) : cs.outlineVariant)),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              Text('${item['category_name'] ?? '-'} · ${item['base_unit'] ?? '-'}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${qty.round()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: isLow ? cs.error : cs.onSurface)),
              if (alert > 0) Text('min: $alert', style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(width: 12),
            if (!editing) IconButton(onPressed: () => _openEdit(item), icon: Icon(Icons.edit, size: 18, color: cs.primary),
              style: IconButton.styleFrom(backgroundColor: cs.primaryContainer, padding: const EdgeInsets.all(8), minimumSize: Size.zero)),
          ]),
          if (editing) ...[
            const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
            Row(children: [
              Expanded(child: _editField('Stok', _stockCtrl)),
              const SizedBox(width: 8),
              Expanded(child: _editField('Min. Alert', _minAlertCtrl)),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => setState(() => editId = null), child: const Text('Batal', style: TextStyle(fontSize: 12))),
              const SizedBox(width: 8),
              FilledButton(onPressed: () => _saveEdit(item['product_id']), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)), child: const Text('Simpan', style: TextStyle(fontSize: 12))),
            ])
          ]
        ]));
    });
  }

  Widget _editField(String label, TextEditingController ctrl) {
    final cs = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
      const SizedBox(height: 4),
      SizedBox(height: 36, child: TextField(controller: ctrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        decoration: InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: cs.surfaceContainer))),
    ]);
  }

  Widget _buildDesktopTable(ColorScheme cs, List<dynamic> items) {
    return Container(decoration: BoxDecoration(color: cs.surfaceBright, borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant)),
      child: ClipRRect(borderRadius: BorderRadius.circular(16), child: ListView(children: [
        DataTable(
          headingRowColor: WidgetStatePropertyAll(cs.surfaceContainer),
          dataRowMinHeight: 56, dataRowMaxHeight: 56,
          columns: const [
            DataColumn(label: Text('Produk', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Kategori')),
            DataColumn(label: Text('Stok')),
            DataColumn(label: Text('Satuan')),
            DataColumn(label: Text('Min. Alert')),
            DataColumn(label: Text('')),
          ],
          rows: items.map((item) {
            final alert = (item['min_stock_alert'] as num?)?.toDouble() ?? 0;
            final qty = (item['stock_quantity'] as num?)?.toDouble() ?? 0;
            final isLow = alert > 0 && qty <= alert;
            final editing = editId == item['product_id'];

            return DataRow(
              color: isLow ? WidgetStatePropertyAll(cs.errorContainer.withValues(alpha: 0.2)) : null,
              cells: [
                DataCell(Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600))),
                DataCell(Text(item['category_name'] ?? '-')),
                DataCell(editing 
                  ? SizedBox(width: 80, child: TextField(controller: _stockCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))))
                  : Text('${qty.round()}', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: isLow ? cs.error : cs.onSurface))),
                DataCell(Text(item['base_unit'] ?? '-')),
                DataCell(editing
                  ? SizedBox(width: 80, child: TextField(controller: _minAlertCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center, decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8))))
                  : Text('$alert', style: TextStyle(color: cs.onSurfaceVariant))),
                DataCell(Align(alignment: Alignment.centerRight, child: editing
                  ? Row(mainAxisSize: MainAxisSize.min, children: [
                      TextButton(onPressed: () => setState(() => editId = null), child: const Text('Batal', style: TextStyle(fontSize: 12))),
                      FilledButton(onPressed: () => _saveEdit(item['product_id']), child: const Text('Simpan', style: TextStyle(fontSize: 12))),
                    ])
                  : IconButton(onPressed: () => _openEdit(item), icon: Icon(Icons.edit, size: 18, color: cs.primary), style: IconButton.styleFrom(backgroundColor: cs.primaryContainer, padding: const EdgeInsets.all(8))))),
              ]
            );
          }).toList(),
        )
      ])));
  }
}
