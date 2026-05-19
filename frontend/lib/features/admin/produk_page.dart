import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api.dart';
import '../../core/helpers.dart';
import '../kasir/dialogs/confirm_dialog.dart';

class ProdukPage extends StatefulWidget {
  const ProdukPage({super.key});
  @override
  State<ProdukPage> createState() => _ProdukPageState();
}

class _ProdukPageState extends State<ProdukPage> {
  List<dynamic> products = [];
  List<dynamic> categories = [];
  bool isLoading = true;
  String activeTab = 'active'; // 'active' or 'inactive'
  String searchQuery = '';
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => isLoading = true);
    try {
      final futures = await Future.wait([
        Api.get('/products/all'),
        Api.get('/categories')
      ]);
      if (mounted) setState(() {
        products = futures[0] as List;
        categories = futures[1] as List;
        isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  List<dynamic> get filteredProducts {
    return products.where((p) {
      final isItemActive = p['is_active'] == 1;
      final matchTab = activeTab == 'active' ? isItemActive : !isItemActive;
      if (!matchTab) return false;
      
      if (searchQuery.isEmpty) return true;
      final q = searchQuery.toLowerCase();
      final name = (p['name'] ?? '').toString().toLowerCase();
      final barcode = (p['barcode'] ?? '').toString().toLowerCase();
      final cat = (p['category_name'] ?? '').toString().toLowerCase();
      return name.contains(q) || barcode.contains(q) || cat.contains(q);
    }).toList();
  }

  void _openForm([dynamic product]) {
    if (categories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Buat kategori terlebih dahulu!')));
      return;
    }
    showDialog(context: context, builder: (_) => ProdukFormDialog(
      product: product,
      categories: categories,
      onSave: _loadData,
    ));
  }

  Future<void> _toggleActive(dynamic p) async {
    try {
      await Api.put('/products/${p['id']}', body: {'is_active': p['is_active'] == 1 ? 0 : 1});
      _loadData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _downloadTemplate() async {
    final url = Uri.parse('${Api.getApiBase()}/products/template/excel');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka link template')));
    }
  }

  Future<void> _importExcel() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => isLoading = true);
        
        final bytes = result.files.single.bytes!;
        final filename = result.files.single.name;
        
        final uri = Uri.parse('${Api.getApiBase()}/products/import');
        var request = http.MultipartRequest('POST', uri);
        
        final token = Api.getToken();
        if (token.isNotEmpty) request.headers['Authorization'] = 'Bearer $token';
        
        request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
        
        var response = await request.send();
        final respStr = await response.stream.bytesToString();
        final json = jsonDecode(respStr);
        
        if (response.statusCode == 200 || response.statusCode == 201) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json['message'] ?? 'Import berhasil')));
          _loadData();
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(json['error'] ?? 'Gagal import excel')));
          setState(() => isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Terjadi kesalahan: $e')));
      setState(() => isLoading = false);
    }
  }

  void _confirmDelete(dynamic p) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
      title: 'Hapus Produk',
      message: 'Yakin ingin menghapus produk "${p['name']}" beserta semua data stok dan harga satuannya?',
      confirmText: 'Ya, Hapus',
    ));
    if (confirmed == true && mounted) {
      try {
        await Api.delete('/products/${p['id']}');
        _loadData();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final items = filteredProducts;

    final activeCount = products.where((p) => p['is_active'] == 1).length;
    final inactiveCount = products.where((p) => p['is_active'] != 1).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(children: [
        // Toolbar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(16)),
          child: Row(children: [
            // Tabs
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: cs.surfaceContainerHigh, borderRadius: BorderRadius.circular(12)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                _tab('active', 'Aktif ($activeCount)', cs),
                _tab('inactive', 'Non-aktif ($inactiveCount)', cs),
              ]),
            ),
            const SizedBox(width: 16),
            Expanded(child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari nama, barcode, kategori...', prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true, filled: true, fillColor: cs.surfaceBright,
              ),
            )),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              icon: const Icon(Icons.upload_file),
              tooltip: 'Import Excel',
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'download', child: Row(children: [Icon(Icons.download, size: 18), SizedBox(width: 8), Text('Download Template')])),
                const PopupMenuItem(value: 'import', child: Row(children: [Icon(Icons.upload_file, size: 18), SizedBox(width: 8), Text('Import Data (Excel)')])),
              ],
              onSelected: (val) {
                if (val == 'download') _downloadTemplate();
                if (val == 'import') _importExcel();
              },
            ),
          ]),
        ),
        const SizedBox(height: 16),
        // List
        Expanded(child: isLoading 
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                const SizedBox(height: 16),
                Text('Tidak ada produk', style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant)),
              ]))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, i) {
                  final p = items[i];
                  final units = p['units'] as List? ?? [];
                  final stock = p['stock_quantity'] ?? 0;
                  final minStock = p['min_stock_alert'] ?? 0;
                  final isLowStock = stock <= minStock;

                  return Card(
                    elevation: 0, margin: const EdgeInsets.only(bottom: 8),
                    color: p['is_active'] == 1 ? cs.surfaceContainer : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5))),
                    child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: cs.primaryContainer, borderRadius: BorderRadius.circular(12)),
                          child: Center(child: Text(p['category_icon'] ?? '📦', style: const TextStyle(fontSize: 24)))),
                        const SizedBox(width: 12),
                        Expanded(flex: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Flexible(child: Text(p['name'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: p['is_active'] == 1 ? cs.onSurface : cs.onSurfaceVariant))),
                            if (p['is_active'] != 1) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: cs.errorContainer, borderRadius: BorderRadius.circular(4)), child: Text('NON-AKTIF', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: cs.onErrorContainer)))],
                          ]),
                          Row(children: [
                            Text('${p['category_name']} ', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                            if (p['barcode'] != null && p['barcode'].toString().trim().isNotEmpty)
                              Text('· ${p['barcode']}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant))
                            else
                              Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2), decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(4)), child: Text('No Barcode', style: TextStyle(fontSize: 9, color: cs.error))),
                          ]),
                        ])),
                        if (!isMobile) const SizedBox(width: 12),
                        if (!isMobile) Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Stok / Modal', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                          Row(children: [
                            Text(formatStock(stock, units, p['base_unit'] as String?), style: TextStyle(fontWeight: FontWeight.bold, color: isLowStock ? cs.error : cs.primary)),
                            if (p['purchase_price'] != null && p['purchase_price'] > 0) ...[
                              Text(' · ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                              Expanded(child: Text('${fmtPrice(((p['purchase_price'] as num).toDouble()) * (units.firstWhere((u) => u['unit_name'] == p['purchase_unit'], orElse: () => {'qty_per_unit': 1})['qty_per_unit'] as num).toDouble())}/${p['purchase_unit'] ?? ''}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                            ]
                          ]),
                        ])),
                        if (!isMobile) const SizedBox(width: 12),
                        if (!isMobile) Expanded(child: Wrap(spacing: 4, runSpacing: 4, children: units.map((u) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                          child: Text('1 ${u['unit_name']} = ${fmtPrice(u['price'])}', style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer)),
                        )).toList())),
                        PopupMenuButton(
                          icon: const Icon(Icons.more_vert),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: const Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                            PopupMenuItem(value: 'toggle', child: Row(children: [Icon(p['is_active'] == 1 ? Icons.visibility_off : Icons.visibility, size: 18), SizedBox(width: 8), Text(p['is_active'] == 1 ? 'Non-aktifkan' : 'Aktifkan')])),
                            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Hapus', style: TextStyle(color: Colors.red))])),
                          ],
                          onSelected: (val) {
                            if (val == 'edit') _openForm(p);
                            if (val == 'toggle') _toggleActive(p);
                            if (val == 'delete') _confirmDelete(p);
                          },
                        )
                      ]),
                      if (isMobile) ...[
                        const Divider(height: 24),
                        Row(children: [
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Stok / Modal', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                            Row(children: [
                              Text(formatStock(stock, units, p['base_unit'] as String?), style: TextStyle(fontWeight: FontWeight.bold, color: isLowStock ? cs.error : cs.primary)),
                              if (p['purchase_price'] != null && p['purchase_price'] > 0) ...[
                                Text(' · ', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                                Expanded(child: Text('${fmtPrice(((p['purchase_price'] as num).toDouble()) * (units.firstWhere((u) => u['unit_name'] == p['purchase_unit'], orElse: () => {'qty_per_unit': 1})['qty_per_unit'] as num).toDouble())}/${p['purchase_unit'] ?? ''}', style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant), overflow: TextOverflow.ellipsis)),
                              ]
                            ]),
                          ])),
                        ]),
                        const SizedBox(height: 8),
                        Wrap(spacing: 4, runSpacing: 4, children: units.map((u) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: cs.secondaryContainer, borderRadius: BorderRadius.circular(6)),
                          child: Text('1 ${u['unit_name']} = ${fmtPrice(u['price'])}', style: TextStyle(fontSize: 10, color: cs.onSecondaryContainer)),
                        )).toList()),
                      ]
                    ])),
                  );
                },
              )
        ),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openForm,
        icon: const Icon(Icons.add),
        label: const Text('Produk Baru'),
      ),
    );
  }

  Widget _tab(String id, String label, ColorScheme cs) {
    final active = activeTab == id;
    return InkWell(
      onTap: () => setState(() => activeTab = id),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(color: active ? cs.primary : Colors.transparent, borderRadius: BorderRadius.circular(8)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: active ? FontWeight.bold : FontWeight.w500, color: active ? cs.onPrimary : cs.onSurfaceVariant)),
      ),
    );
  }
}

class ProdukFormDialog extends StatefulWidget {
  final dynamic product;
  final List<dynamic> categories;
  final VoidCallback onSave;

  const ProdukFormDialog({super.key, this.product, required this.categories, required this.onSave});

  @override
  State<ProdukFormDialog> createState() => _ProdukFormDialogState();
}

class _ProdukFormDialogState extends State<ProdukFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _barcodeCtrl, _stockCtrl, _minStockCtrl;
  late TextEditingController _purchasePriceCtrl, _baseUnitCtrl;
  final FocusNode _barcodeFocus = FocusNode();
  int _catKey = 0;
  
  int? _selectedCat;
  List<dynamic> _availableUnits = [];
  List<Map<String, dynamic>> _unitPrices = [];
  bool isSaving = false;

  bool _isBarcodeEditable = false;
  bool _barcodeExistsOriginally = false;
  String? _selectedPurchaseUnit;
  String? _selectedStockUnit;

  @override
  void initState() {
    super.initState();
    final p = widget.product;
    _nameCtrl = TextEditingController(text: p?['name'] ?? '');
    _baseUnitCtrl = TextEditingController(text: p?['base_unit'] ?? 'pcs');
    _baseUnitCtrl.addListener(() { if (mounted) setState(() {}); });
    _barcodeCtrl = TextEditingController(text: p?['barcode'] ?? '');
    
    _barcodeExistsOriginally = (p?['barcode'] ?? '').toString().isNotEmpty;
    _isBarcodeEditable = !_barcodeExistsOriginally;
    _selectedPurchaseUnit = p?['purchase_unit']?.toString().isNotEmpty == true ? p!['purchase_unit'] : null;

    if (p != null) {
      final uList = p['units'] as List? ?? [];
      _unitPrices = uList.map((u) => {
        'unit_name': u['unit_name'],
        'qty_per_unit': u['qty_per_unit'],
        'price': u['price'],
      }).toList();
      
      double baseStock = (p['stock_quantity'] as num?)?.toDouble() ?? 0;
      List<dynamic> sortedUnits = List.from(uList);
      sortedUnits.sort((a, b) => ((b['qty_per_unit'] as num?) ?? 1).compareTo((a['qty_per_unit'] as num?) ?? 1));
      
      double bestMultiplier = 1.0;
      String? bestUnit;
      if (baseStock > 0) {
        for (var u in sortedUnits) {
          double m = (u['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
          if (m > 0 && baseStock % m == 0) {
            bestMultiplier = m;
            bestUnit = u['unit_name'];
            break;
          }
        }
      }
      
      _selectedStockUnit = bestUnit ?? (p['base_unit']?.toString().isNotEmpty == true ? p['base_unit'] : 'pcs');
      double displayStock = baseStock / bestMultiplier;
      _stockCtrl = TextEditingController(text: displayStock == displayStock.roundToDouble() ? displayStock.round().toString() : displayStock.toStringAsFixed(2));
      
      double minStockVal = (p['min_stock'] as num? ?? p['min_stock_alert'] as num? ?? 0).toDouble();
      double displayMinStock = minStockVal / bestMultiplier;
      _minStockCtrl = TextEditingController(text: displayMinStock == 0 ? '' : (displayMinStock == displayMinStock.roundToDouble() ? displayMinStock.round().toString() : displayMinStock.toStringAsFixed(2)));

      double pp = (p['purchase_price'] as num?)?.toDouble() ?? 0;
      double totalModal = pp * baseStock;
      _purchasePriceCtrl = TextEditingController(text: totalModal == 0 ? '' : (totalModal == totalModal.roundToDouble() ? totalModal.round().toString() : totalModal.toStringAsFixed(2)));
    } else {
      _stockCtrl = TextEditingController();
      _minStockCtrl = TextEditingController();
      _purchasePriceCtrl = TextEditingController();
    }

    _barcodeFocus.addListener(() {
      if (!_barcodeFocus.hasFocus && _isBarcodeEditable && _barcodeExistsOriginally) {
        setState(() => _isBarcodeEditable = false);
      }
    });

    if (widget.categories.isNotEmpty) {
      _selectedCat = p?['category_id'] ?? widget.categories.first['id'];
      _onCategoryChange(_selectedCat!);
    }
  }

  @override
  void dispose() {
    _barcodeFocus.dispose();
    super.dispose();
  }

  void _onCategoryChange(int catId) {
    setState(() {
      _selectedCat = catId;
      final cat = widget.categories.firstWhere((c) => c['id'] == catId, orElse: () => null);
      _availableUnits = cat?['units'] ?? [];
      
      // Filter existing unit prices to match new category
      final validNames = _availableUnits.map((u) => u['unit_name']).toList();
      _unitPrices.removeWhere((up) => !validNames.contains(up['unit_name']));

      if (_selectedPurchaseUnit != null && !validNames.contains(_selectedPurchaseUnit)) {
        _selectedPurchaseUnit = null;
      }
    });
  }

  void _addUnitPrice() {
    final validNames = _availableUnits.map((u) => u['unit_name']).toList();
    final unused = validNames.where((n) => !_unitPrices.any((up) => up['unit_name'] == n)).toList();
    if (unused.isNotEmpty) {
      setState(() => _unitPrices.add({ 'unit_name': unused.first, 'qty_per_unit': '', 'price': '' }));
    }
  }

  void _removeUnitPrice(int index) async {
    final up = _unitPrices[index];
    final currentPrice = (up['price'] as num?) ?? 0;
    if (currentPrice > 0) {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
        title: 'Hapus Satuan Jual',
        message: 'Yakin ingin menghapus harga untuk satuan "${up['unit_name']}"?',
        confirmText: 'Hapus',
      ));
      if (confirmed != true) return;
    }
    setState(() => _unitPrices.removeAt(index));
  }

  void _generateBarcode() async {
    if (_barcodeExistsOriginally) {
      final confirmed = await showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
        title: 'Generate Ulang Barcode?',
        message: 'Produk ini sudah memiliki barcode. Mengubah barcode bisa menyebabkan barcode lama tidak bisa di-scan lagi. Yakin?',
        confirmText: 'Generate',
      ));
      if (confirmed != true) return;
    }
    setState(() {
      _barcodeCtrl.text = DateTime.now().millisecondsSinceEpoch.toString();
      _isBarcodeEditable = true;
    });
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Filter valid unit prices
    final validPrices = _unitPrices.where((up) => (up['price'] as num) > 0).toList();
    if (validPrices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimal 1 harga jual harus diisi > 0')));
      return;
    }

    setState(() => isSaving = true);
    
    double inputStock = double.tryParse(_stockCtrl.text) ?? 0;
    double multiplier = 1;
    final baseUnitName = _baseUnitCtrl.text.trim().isEmpty ? 'pcs' : _baseUnitCtrl.text.trim();
    if (_selectedStockUnit != null && _selectedStockUnit != baseUnitName) {
      final unitData = _unitPrices.firstWhere((u) => u['unit_name'] == _selectedStockUnit, orElse: () => <String, dynamic>{});
      multiplier = (unitData['qty_per_unit'] as num?)?.toDouble() ?? 1;
    }
    double finalStock = inputStock * multiplier;
    
    double inputMinStock = double.tryParse(_minStockCtrl.text) ?? 0;
    double finalMinStock = inputMinStock * multiplier;

    double rawPurchasePrice = double.tryParse(_purchasePriceCtrl.text) ?? 0;
    double purchasePricePerBaseUnit = (rawPurchasePrice > 0 && finalStock > 0) ? (rawPurchasePrice / finalStock) : rawPurchasePrice;

    final data = {
      'name': toTitleCase(_nameCtrl.text.trim()),
      'base_unit': baseUnitName,
      'category_id': _selectedCat,
      'barcode': _barcodeCtrl.text.trim().isEmpty ? null : _barcodeCtrl.text.trim(),
      'stock': finalStock,
      'min_stock': finalMinStock,
      'purchase_price': purchasePricePerBaseUnit,
      'purchase_unit': _selectedPurchaseUnit ?? '',
      'unit_prices': validPrices,
    };

    try {
      if (widget.product != null) {
        await Api.put('/products/${widget.product['id']}', body: data);
      } else {
        await Api.post('/products', body: data);
      }
      if (mounted) {
        widget.onSave();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(widget.product != null ? 'Edit Produk' : 'Tambah Produk', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ]),
          ),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(key: _formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Basic Info
              isMobile ? Column(children: [
                _field(_nameCtrl, 'Nama Produk', true, textCapitalization: TextCapitalization.words),
                const SizedBox(height: 12),
                _field(_baseUnitCtrl, 'Satuan Terkecil (Base Unit, cth: pcs)', true),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  key: ValueKey(_catKey),
                  value: _selectedCat,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori', isDense: true),
                  items: widget.categories.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text('${c['icon']} ${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _handleCatChange,
                ),
              ]) : Row(children: [
                Expanded(flex: 2, child: _field(_nameCtrl, 'Nama Produk', true, textCapitalization: TextCapitalization.words)),
                const SizedBox(width: 12),
                Expanded(child: _field(_baseUnitCtrl, 'Satuan Terkecil', true)),
                const SizedBox(width: 12),
                Expanded(child: DropdownButtonFormField<int>(
                  key: ValueKey(_catKey),
                  value: _selectedCat,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kategori', isDense: true),
                  items: widget.categories.map((c) => DropdownMenuItem<int>(value: c['id'], child: Text('${c['icon']} ${c['name']}', maxLines: 1, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: _handleCatChange,
                )),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: TextFormField(
                  controller: _barcodeCtrl,
                  focusNode: _barcodeFocus,
                  enabled: _isBarcodeEditable,
                  decoration: const InputDecoration(labelText: 'Barcode (opsional)', isDense: true),
                )),
                if (_barcodeExistsOriginally && !_isBarcodeEditable) ...[
                  const SizedBox(width: 8),
                  IconButton.filledTonal(onPressed: () { 
                    setState(() => _isBarcodeEditable = true); 
                    WidgetsBinding.instance.addPostFrameCallback((_) => _barcodeFocus.requestFocus()); 
                  }, icon: const Icon(Icons.edit), tooltip: 'Edit Barcode Manual'),
                ],
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: _generateBarcode, icon: const Icon(Icons.auto_awesome), tooltip: 'Generate'),
              ]),
              const SizedBox(height: 24),

              // Purchase / Modal
              const Text('Data Pembelian / Modal', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
                child: isMobile ? Column(children: [
                  _field(_purchasePriceCtrl, 'Harga Modal', false, isNum: true, prefix: 'Rp'),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedPurchaseUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Satuan Beli (opsional)', isDense: true),
                    items: _availableUnits.map((u) => DropdownMenuItem<String>(value: u['unit_name'], child: Text(u['unit_name']))).toList(),
                    onChanged: (v) => setState(() => _selectedPurchaseUnit = v),
                  ),
                ]) : Row(children: [
                  Expanded(child: _field(_purchasePriceCtrl, 'Harga Modal', false, isNum: true, prefix: 'Rp')),
                  const SizedBox(width: 12),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: _selectedPurchaseUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Satuan Beli (opsional)', isDense: true),
                    items: _availableUnits.map((u) => DropdownMenuItem<String>(value: u['unit_name'], child: Text(u['unit_name']))).toList(),
                    onChanged: (v) => setState(() => _selectedPurchaseUnit = v),
                  )),
                ])
              ),
              const SizedBox(height: 24),

              // Selling Prices
              const Text('Harga Jual (Multi-Satuan)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainerLowest, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (_availableUnits.isEmpty)
                    Padding(padding: const EdgeInsets.all(8.0), child: Text('Kategori ini belum memiliki satuan (units). Edit kategori terlebih dahulu.', style: TextStyle(color: cs.error))),
                  ..._unitPrices.asMap().entries.map((e) {
                    final i = e.key;
                    final up = e.value;
                    return Padding(padding: const EdgeInsets.only(bottom: 8), child: isMobile ? Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: cs.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        DropdownButtonFormField<String>(
                          value: up['unit_name'],
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Satuan Jual', isDense: true),
                          items: _availableUnits.map((u) => DropdownMenuItem<String>(value: u['unit_name'], child: Text(u['unit_name']))).toList(),
                          onChanged: (v) => setState(() => _unitPrices[i]['unit_name'] = v!),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: up['qty_per_unit'].toString(),
                          decoration: const InputDecoration(labelText: 'Isi per Satuan', isDense: true),
                          keyboardType: TextInputType.number,
                          onChanged: (v) => _unitPrices[i]['qty_per_unit'] = double.tryParse(v) ?? 1,
                        ),
                        const SizedBox(height: 8),
                        Row(children: [
                          Expanded(child: TextFormField(
                            initialValue: up['price'].toString(),
                            decoration: const InputDecoration(labelText: 'Harga Jual', isDense: true, prefixText: 'Rp '),
                            keyboardType: TextInputType.number,
                            onChanged: (v) => _unitPrices[i]['price'] = double.tryParse(v) ?? 0,
                          )),
                          IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUnitPrice(i)),
                        ])
                      ])
                    ) : Row(children: [
                      Expanded(child: DropdownButtonFormField<String>(
                        value: up['unit_name'],
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Satuan Jual', isDense: true),
                        items: _availableUnits.map((u) => DropdownMenuItem<String>(value: u['unit_name'], child: Text(u['unit_name']))).toList(),
                        onChanged: (v) => setState(() => _unitPrices[i]['unit_name'] = v!),
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        initialValue: up['qty_per_unit'].toString(),
                        decoration: const InputDecoration(labelText: 'Isi per Satuan', isDense: true),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _unitPrices[i]['qty_per_unit'] = double.tryParse(v) ?? 1,
                      )),
                      const SizedBox(width: 8),
                      Expanded(child: TextFormField(
                        initialValue: up['price'].toString(),
                        decoration: const InputDecoration(labelText: 'Harga Jual', isDense: true, prefixText: 'Rp '),
                        keyboardType: TextInputType.number,
                        onChanged: (v) => _unitPrices[i]['price'] = double.tryParse(v) ?? 0,
                      )),
                      IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeUnitPrice(i)),
                    ]));
                  }),
                  if (_unitPrices.length < _availableUnits.length)
                    TextButton.icon(onPressed: _addUnitPrice, icon: const Icon(Icons.add), label: const Text('Tambah Satuan Jual')),
                ])
              ),
              const SizedBox(height: 24),

              // Stock
              const Text('Stok', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Builder(builder: (context) {
                final baseUnitName = _baseUnitCtrl.text.trim().isEmpty ? 'pcs' : _baseUnitCtrl.text.trim();
                final List<String> stockOpts = [baseUnitName];
                for (var u in _unitPrices) {
                  if (u['unit_name'] != null && !stockOpts.contains(u['unit_name'])) {
                    stockOpts.add(u['unit_name']);
                  }
                }
                String currentStockUnit = stockOpts.contains(_selectedStockUnit) ? _selectedStockUnit! : baseUnitName;

                Widget stockInput = Row(children: [
                  Expanded(flex: 2, child: _field(_stockCtrl, 'Jumlah Stok Masuk', false, isNum: true)),
                  const SizedBox(width: 8),
                  Expanded(child: DropdownButtonFormField<String>(
                    value: currentStockUnit,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Satuan', isDense: true),
                    items: stockOpts.map((u) => DropdownMenuItem<String>(value: u, child: Text(u))).toList(),
                    onChanged: (v) => setState(() => _selectedStockUnit = v),
                  )),
                ]);

                return isMobile ? Column(children: [
                  stockInput,
                  const SizedBox(height: 12),
                  _field(_minStockCtrl, 'Batas Peringatan Stok Minimum', false, isNum: true),
                ]) : Row(children: [
                  Expanded(child: stockInput),
                  const SizedBox(width: 12),
                  Expanded(child: _field(_minStockCtrl, 'Batas Peringatan Stok Minimum', false, isNum: true)),
                ]);
              }),
            ])),
          )),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
              const SizedBox(width: 12),
              FilledButton(onPressed: isSaving ? null : _save, child: isSaving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Simpan Produk')),
            ]),
          )
        ]),
      ),
    );
  }

  void _handleCatChange(int? v) {
    if (v == null || v == _selectedCat) return;
    if (widget.product != null) {
      final cat = widget.categories.firstWhere((c) => c['id'] == v, orElse: () => null);
      final newUnits = cat?['units'] ?? [];
      final validNames = newUnits.map((u) => u['unit_name']).toList();
      final willLoseUnits = _unitPrices.any((up) => !validNames.contains(up['unit_name']));
      if (willLoseUnits) {
        showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
          title: 'Peringatan Ganti Kategori',
          message: 'Anda merubah kategori. Sebagian data satuan jual yang tidak tersedia di kategori baru akan dihapus. Lanjutkan?',
          confirmText: 'Ya, Ganti',
        )).then((confirmed) {
          if (confirmed == true) {
            _onCategoryChange(v);
          } else {
            setState(() => _catKey++); // force Dropdown to snap back to _selectedCat
          }
        });
        return;
      }
    }
    _onCategoryChange(v);
  }

  Widget _field(TextEditingController ctrl, String label, bool required, {bool isNum = false, String? prefix, TextCapitalization? textCapitalization}) {
    return TextFormField(
      controller: ctrl,
      textCapitalization: textCapitalization ?? TextCapitalization.none,
      decoration: InputDecoration(labelText: label, isDense: true, prefixText: prefix != null ? '$prefix ' : null),
      keyboardType: isNum ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      validator: required ? (v) => v == null || v.trim().isEmpty ? 'Wajib' : null : null,
    );
  }
}
