import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/api.dart';
import '../../core/auth_provider.dart';
import '../../core/helpers.dart';
import '../../core/theme_provider.dart';
import '../../shared/widgets/theme_toggle.dart';
import 'widgets/product_card.dart';
import 'widgets/cart_item_widget.dart';
import 'dialogs/payment_dialog.dart';
import 'dialogs/receipt_modal.dart';
import 'dialogs/unit_selector.dart';
import 'dialogs/confirm_dialog.dart';
import '../auth/lock_screen.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({super.key});
  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  List<dynamic> products = [];
  List<dynamic> categories = [];
  List<Map<String, dynamic>> cart = [];
  int? selectedCategory;
  String searchQuery = '';
  bool showSearch = false;
  bool cartOpen = false;
  bool showDashboard = false;
  bool showHistory = false;
  bool showProfile = false;
  bool showHeldCarts = false;
  bool showLogoutConfirm = false;
  String? activeCartLabel;
  bool showLowStock = false;
  String stockTab = 'empty';
  String profileMsg = '';
  final _nameCtrl = TextEditingController();
  final _oldPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _oldPinCtrl = TextEditingController();
  final _newPinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();
  Map<String, dynamic> todayStats = {'total_transactions': 0, 'total_sales': 0, 'avg_transaction': 0};
  List<dynamic> txHistory = [];
  List<dynamic> heldCarts = [];
  List<dynamic> lowStockItems = [];
  List<dynamic> outOfStockItems = [];
  int _mobileNavIndex = 0;

  double get cartTotal => cart.fold(0.0, (s, i) => s + (i['unit_price'] as num) * (i['quantity'] as num));

  List<dynamic> get filteredProducts => products.where((p) {
    final matchCat = selectedCategory == null || p['category_id'] == selectedCategory;
    final q = searchQuery.toLowerCase();
    final matchSearch = searchQuery.isEmpty || 
        (p['name'] as String).toLowerCase().contains(q) ||
        (p['barcode']?.toString().toLowerCase().contains(q) ?? false);
    return matchCat && matchSearch;
  }).toList();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (!auth.isLoggedIn) { context.go('/login'); return; }
      _loadData();
      _loadDashboard();
      _loadHeldCarts();
      _loadLowStock();
    });
  }

  @override
  void dispose() { super.dispose(); }

  void _closeAllModals() {
    showDashboard = false; showHistory = false; showProfile = false;
    showHeldCarts = false; showLowStock = false; cartOpen = false; showSearch = false;
    searchQuery = '';
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([Api.get('/products'), Api.get('/categories')]);
      setState(() { products = results[0] as List; categories = results[1] as List; });
    } catch (_) {}
  }

  Future<void> _loadDashboard() async {
    try {
      final results = await Future.wait([Api.get('/transactions/today'), Api.get('/transactions?limit=10')]);
      setState(() { todayStats = results[0]; });
    } catch (_) {}
  }

  Future<void> _loadHeldCarts() async {
    try { final r = await Api.get('/held-carts'); if (mounted) setState(() => heldCarts = r as List); } catch (_) {}
  }

  Future<void> _loadLowStock() async {
    try {
      final results = await Future.wait([Api.get('/inventory/low-stock'), Api.get('/inventory/out-of-stock')]);
      setState(() { lowStockItems = results[0] as List; outOfStockItems = results[1] as List; });
    } catch (_) {}
  }

  Future<void> _loadHistory() async {
    try {
      final now = DateTime.now();
      final today = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final res = await Api.get('/transactions?date=$today&limit=50');
      setState(() => txHistory = (res['data'] ?? []) as List);
    } catch (_) { setState(() => txHistory = []); }
  }

  double _calcUnitPrice(dynamic product, String unitName) {
    final units = product['units'] as List?;
    if (units == null) return 0;
    final unit = units.firstWhere((u) => u['unit_name'] == unitName, orElse: () => null);
    if (unit == null) return 0;
    return (unit['price'] as num).toDouble();
  }

  double _getHeldQty(int productId) {
    double sum = 0;
    for (final hc in heldCarts) {
      for (final i in (hc['cart_data'] as List? ?? [])) {
        if (i['product']?['id'] == productId) {
          final units = i['product']?['units'] as List? ?? [];
          final unitName = i['selected_unit'];
          final unit = units.firstWhere((u) => u['unit_name'] == unitName, orElse: () => null);
          final multiplier = (unit?['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
          sum += ((i['quantity'] as num?)?.toDouble() ?? 0) * multiplier;
        }
      }
    }
    return sum;
  }

  double _getBookedStock(int productId) {
    double booked = 0;
    for (final item in cart) {
      if (item['product']['id'] == productId) {
        final units = item['product']['units'] as List? ?? [];
        final unitName = item['selected_unit'];
        final unit = units.firstWhere((u) => u['unit_name'] == unitName, orElse: () => null);
        final multiplier = (unit?['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
        booked += (item['quantity'] as num).toDouble() * multiplier;
      }
    }
    return booked;
  }
  
  void _applyMaxSplit(dynamic product) {
    cart.removeWhere((i) => i['product']['id'] == product['id']);
    double remaining = (product['stock_quantity'] as num?)?.toDouble() ?? 0;
    if (remaining <= 0) return;
    
    final units = List.from(product['units'] as List? ?? []);
    units.sort((a, b) => ((b['qty_per_unit'] as num?) ?? 1).compareTo((a['qty_per_unit'] as num?) ?? 1));
    
    for (final unit in units) {
      final mult = (unit['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
      if (mult <= 0) continue;
      final qty = (remaining / mult).floorToDouble();
      if (qty > 0) {
        cart.add({
          'product': product, 
          'selected_unit': unit['unit_name'], 
          'quantity': qty, 
          'unit_price': _calcUnitPrice(product, unit['unit_name'])
        });
        remaining = remaining - (qty * mult);
      }
    }
    if (remaining > 0.001) {
      final baseUnitName = (product['base_unit'] as String?)?.isNotEmpty == true ? product['base_unit'] : 'pcs';
      cart.add({
        'product': product, 
        'selected_unit': baseUnitName, 
        'quantity': double.parse(remaining.toStringAsFixed(2)), 
        'unit_price': _calcUnitPrice(product, baseUnitName)
      });
    }
    setState((){});
  }

  void _consolidateProductCart(dynamic product) {
    final units = List.from(product['units'] as List? ?? []);
    if (units.length <= 1) return; // Only consolidate multi-unit products

    double totalBaseQtyInCart = 0;
    units.sort((a, b) => ((b['qty_per_unit'] as num?) ?? 1).compareTo((a['qty_per_unit'] as num?) ?? 1));

    int firstIndex = -1;
    for (int i = 0; i < cart.length; i++) {
      final c = cart[i];
      if (c['product']['id'] == product['id']) {
        if (firstIndex == -1) firstIndex = i;
        final cUnit = units.firstWhere((u) => u['unit_name'] == c['selected_unit'], orElse: () => null);
        final mult = (cUnit?['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
        totalBaseQtyInCart += (c['quantity'] as num) * mult;
      }
    }

    if (totalBaseQtyInCart <= 0.001) return;

    cart.removeWhere((c) => c['product']['id'] == product['id']);

    double remaining = totalBaseQtyInCart;
    List<Map<String, dynamic>> newItems = [];

    for (final unit in units) {
      final mult = (unit['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
      if (mult <= 0) continue;
      final qty = (remaining / mult).floorToDouble();
      if (qty > 0) {
        newItems.add({
          'product': product, 
          'selected_unit': unit['unit_name'], 
          'quantity': qty, 
          'unit_price': _calcUnitPrice(product, unit['unit_name'])
        });
        remaining = remaining - (qty * mult);
      }
    }
    
    if (remaining > 0.001) {
      final baseUnitName = (product['base_unit'] as String?)?.isNotEmpty == true ? product['base_unit'] : 'pcs';
      newItems.add({
        'product': product, 
        'selected_unit': baseUnitName, 
        'quantity': double.parse(remaining.toStringAsFixed(2)), 
        'unit_price': _calcUnitPrice(product, baseUnitName)
      });
    }
    
    if (firstIndex != -1 && firstIndex <= cart.length) {
      cart.insertAll(firstIndex, newItems);
    } else {
      cart.addAll(newItems);
    }
  }

  void _handleProductSelect(dynamic product) {
    final units = product['units'] as List? ?? [];
    final booked = _getBookedStock(product['id']);
    final held = _getHeldQty(product['id']);
    final availableStock = (product['stock_quantity'] as num?)?.toDouble() ?? double.infinity;
    final trueAvailable = availableStock == double.infinity ? double.infinity : availableStock - booked - held;
    
    if (units.length > 1) {
      showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
        builder: (_) => UnitSelectorDialog(product: product, availableStock: trueAvailable, onConfirm: _addToCart));
    } else {
      _addToCart(product, units.isNotEmpty ? units[0]['unit_name'] : 'pcs', 1);
    }
  }

  void _addToCart(dynamic product, String unitName, num quantity) {
    final idx = cart.indexWhere((i) => i['product']['id'] == product['id'] && i['selected_unit'] == unitName);
    if (idx >= 0) {
      _setItemQuantity(idx, (cart[idx]['quantity'] as num).toDouble() + quantity.toDouble());
    } else {
      cart.add({'product': product, 'selected_unit': unitName, 'quantity': 0, 'unit_price': _calcUnitPrice(product, unitName)});
      _setItemQuantity(cart.length - 1, quantity.toDouble());
    }
  }

  void _incrementItem(int i) => _setItemQuantity(i, (cart[i]['quantity'] as num).toDouble() + 1);
  void _decrementItem(int i) { if ((cart[i]['quantity'] as num) > 1) _setItemQuantity(i, (cart[i]['quantity'] as num).toDouble() - 1); }
  void _removeItem(int i) => setState(() => cart.removeAt(i));
  
  void _setItemQuantity(int i, double qty) {
    if (qty < 0) qty = 0;
    final item = cart[i];
    final product = item['product'];
    final unitName = item['selected_unit'];
    
    final realStock = (product['stock_quantity'] as num?)?.toDouble() ?? double.infinity;
    if (realStock == double.infinity) {
      setState(() { 
        cart[i]['quantity'] = qty;
        _consolidateProductCart(product);
      });
      return;
    }
    
    final held = _getHeldQty(product['id']);
    final availableStock = realStock - held;

    final units = product['units'] as List? ?? [];
    final unit = units.firstWhere((u) => u['unit_name'] == unitName, orElse: () => null);
    final qtyPerUnit = (unit?['qty_per_unit'] as num?)?.toDouble() ?? 1;

    double otherCartQtyInBaseUnit = 0;
    for (int j = 0; j < cart.length; j++) {
      if (j != i && cart[j]['product']['id'] == product['id']) {
        final cUnit = units.firstWhere((u) => u['unit_name'] == cart[j]['selected_unit'], orElse: () => null);
        final cQtyPerUnit = (cUnit?['qty_per_unit'] as num?)?.toDouble() ?? 1;
        otherCartQtyInBaseUnit += (cart[j]['quantity'] as num) * cQtyPerUnit;
      }
    }
    
    final requestedInBaseUnit = qty * qtyPerUnit;
    
    if (otherCartQtyInBaseUnit + requestedInBaseUnit > availableStock) {
      final allowedInBaseUnit = availableStock - otherCartQtyInBaseUnit;
      qty = allowedInBaseUnit / qtyPerUnit;
      if (qty < 0) qty = 0;
      showToast(context, 'Stok maksimal: ${qty.toStringAsFixed(qty == qty.roundToDouble() ? 0 : 2)} $unitName');
    }
    
    setState(() {
      cart[i]['quantity'] = qty;
      _consolidateProductCart(product);
    });
  }

  Future<void> _handleCheckout(double paidAmount) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
      title: 'Konfirmasi Transaksi',
      message: 'Pastikan semua item dan jumlah pembayaran sudah benar. Transaksi akan langsung tersimpan dan tidak bisa diubah.',
      confirmText: 'Ya, Proses Pembelian',
    ));
    if (confirmed != true) return;
    try {
      final items = cart.map((c) => {'product_id': c['product']['id'], 'unit_name': c['selected_unit'], 'quantity': c['quantity']}).toList();
      final result = await Api.post('/transactions', body: {'items': items, 'paid_amount': paidAmount});
      if (mounted) {
        setState(() { cart.clear(); cartOpen = false; activeCartLabel = null; });
        if (activeCartLabel != null) {
          try { Api.delete('/held-carts/${activeCartLabel!}'); } catch (_) {}
        }
        _loadDashboard(); _loadData();
        showDialog(context: context, builder: (_) => ReceiptModal(transaction: result['transaction'], details: List<Map<String, dynamic>>.from(result['details'])));
      }
    } catch (e) { if (mounted) showToast(context, '❌ ${e.toString().replaceFirst("Exception: ", "")}'); }
  }

  void _handleLogout() async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => const KayConfirmDialog(
      title: 'Logout', message: 'Yakin ingin logout dari kasir?', confirmText: 'Ya, Logout'));
    if (confirmed == true && mounted) { context.read<AuthProvider>().logout(); context.go('/login'); }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final auth = context.watch<AuthProvider>();
    final isMobile = MediaQuery.sizeOf(context).width < 768;

    // Lock screen overlay
    if (auth.isLocked) return const LockScreen();

    return Scaffold(
      backgroundColor: cs.surface,
      body: Stack(children: [
      Column(children: [
        // === APPBAR ===
        Container(
          color: Theme.of(context).appBarTheme.backgroundColor ?? cs.primary,
          padding: EdgeInsets.only(left: 16, right: 16, top: MediaQuery.of(context).padding.top, bottom: 0),
          constraints: const BoxConstraints(minHeight: 48),
          child: SizedBox(height: 48, child: Row(children: [
            Image.asset('assets/icon-512.png', width: 28, height: 28),
            const SizedBox(width: 12),
            const Text('KAYPOS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: -0.5)),
          ])),
        ),

        // === TOOLBAR ===
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: cs.surface, border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)))),
          child: Row(children: [
            // Category dropdown
            Builder(builder: (ctx) {
              final dropdown = Container(height: 36, constraints: isMobile ? null : const BoxConstraints(maxWidth: 220), padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5))),
                child: DropdownButtonHideUnderline(child: DropdownButton<int?>(
                  value: selectedCategory, isExpanded: true, isDense: true,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('📦 Semua Kategori')),
                    ...categories.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['icon'] ?? '📦'} ${c['name']}'))),
                  ],
                  onChanged: (v) => setState(() => selectedCategory = v),
                )));
              return isMobile ? Expanded(child: dropdown) : dropdown;
            }),
            const SizedBox(width: 8),
            // Desktop search
            if (!isMobile) Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: SizedBox(height: 40, child: TextField(
              onChanged: (v) => setState(() => searchQuery = v),
              style: TextStyle(fontSize: 13, color: cs.onSurface),
              decoration: const InputDecoration(hintText: 'Cari produk...', prefixIcon: Icon(Icons.search, size: 18)),
            )))),
            // Desktop buttons
            if (!isMobile) ...[
              const SizedBox(width: 8),
              _toolbarBtn(Icons.pie_chart, 'Rekap', onTap: () { setState(() { _closeAllModals(); showDashboard = true; }); _loadDashboard(); }),
              const SizedBox(width: 4),
              _toolbarBtn(Icons.history, 'Riwayat', onTap: () { setState(() { _closeAllModals(); showHistory = true; }); _loadHistory(); }),
              const SizedBox(width: 4),
              _toolbarBtn(Icons.person, auth.userName, onTap: () => setState(() { _closeAllModals(); showProfile = true; })),
              if (auth.isAdmin) ...[const SizedBox(width: 4), _toolbarBtn(Icons.settings, 'Admin', color: cs.tertiaryContainer, textColor: cs.onTertiaryContainer, onTap: () => context.go('/admin'))],
              const SizedBox(width: 4),
              _toolbarBtn(Icons.logout, 'Keluar', color: cs.errorContainer.withValues(alpha: 0.5), textColor: cs.error, onTap: _handleLogout),
            ],
            // Stock alert indicator
            if (lowStockItems.isNotEmpty || outOfStockItems.isNotEmpty) ...[
              const SizedBox(width: 4),
              _toolbarBtn(Icons.warning_amber, isMobile ? 'Stok' : 'Stok',
                color: outOfStockItems.isNotEmpty ? cs.errorContainer : const Color(0xFFFEF3C7),
                textColor: outOfStockItems.isNotEmpty ? cs.error : const Color(0xFFB45309),
                onTap: () => setState(() { _closeAllModals(); showLowStock = true; stockTab = outOfStockItems.isNotEmpty ? 'empty' : 'low'; })),
            ],
            // Held carts indicator
            if (heldCarts.isNotEmpty) ...[
              const SizedBox(width: 8),
              _toolbarBtn(Icons.access_time, isMobile ? '' : 'Ditahan', color: cs.secondaryContainer, textColor: cs.onSecondaryContainer,
                badge: heldCarts.length.toString(), onTap: () { setState(() { _closeAllModals(); showHeldCarts = true; }); _loadHeldCarts(); }),
            ],
            const SizedBox(width: 4),
            // Lock button
            InkWell(onTap: () { context.read<AuthProvider>().lock(); },
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.lock, size: 18, color: cs.error))),
            const SizedBox(width: 4),
            const ThemeToggleButton(),
          ]),
        ),

        // === MOBILE SEARCH BAR ===
        if (isMobile && showSearch) Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: cs.surfaceContainer.withValues(alpha: 0.5), border: Border(bottom: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)))),
          child: Row(children: [
            Expanded(child: TextField(
              autofocus: true, onChanged: (v) => setState(() => searchQuery = v),
              decoration: InputDecoration(hintText: 'Cari produk...', prefixIcon: const Icon(Icons.search, size: 16), isDense: true,
                filled: true, fillColor: cs.surfaceContainer, 
                contentPadding: const EdgeInsets.symmetric(vertical: 10)),
            )),
            const SizedBox(width: 8),
            InkWell(onTap: () => setState(() { showSearch = false; searchQuery = ''; }),
              child: Container(width: 36, height: 36, decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant))),
          ]),
        ),

        // === MAIN CONTENT ===
        Expanded(child: Row(children: [
          // Product Grid
          Expanded(child: Padding(
            padding: EdgeInsets.only(left: 4, right: 4, top: 4, bottom: isMobile ? 76 : 4),
            child: filteredProducts.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Text('🔍', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 8),
                  Text('Produk tidak ditemukan', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: cs.onSurfaceVariant)),
                ]))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: isMobile ? 216 : 264,
                    mainAxisExtent: 68, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: filteredProducts.length,
                  itemBuilder: (_, i) => ProductCard(product: filteredProducts[i], bookedQty: _getHeldQty(filteredProducts[i]['id']) + _getBookedStock(filteredProducts[i]['id']), onSelect: _handleProductSelect),
                ),
          )),

          // Desktop Cart Sidebar
          if (!isMobile) Container(
            width: (MediaQuery.sizeOf(context).width * 0.40).clamp(320.0, 600.0),
            decoration: BoxDecoration(color: cs.surfaceContainerLow, border: Border(left: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.5)))),
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  const Text('🛒 Keranjang', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  if (cart.isNotEmpty) ...[const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)),
                    child: Text('${cart.length}', style: TextStyle(color: cs.onPrimary, fontSize: 12, fontWeight: FontWeight.bold)))],
                ]),
                if (cart.isNotEmpty) TextButton(onPressed: _clearCart, child: Text('Kosongkan', style: TextStyle(color: cs.error, fontSize: 12, fontWeight: FontWeight.w600))),
              ])),
              const Divider(height: 1),
              Expanded(child: cart.isEmpty
                ? Center(child: Text('Keranjang Kosong', style: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5), fontWeight: FontWeight.w500, fontSize: 14)))
                : ListView.builder(padding: const EdgeInsets.all(12), itemCount: cart.length,
                    itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 8),
                      child: CartItemWidget(item: cart[i], onIncrement: () => _incrementItem(i), onDecrement: () => _decrementItem(i), onRemove: () => _removeItem(i), onSetQuantity: (q) => _setItemQuantity(i, q), onMaxSplit: () => _applyMaxSplit(cart[i]['product']))))),
              const Divider(height: 1),
              Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)),
                  Text(fmtPrice(cartTotal), style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: cs.primary)),
                ]),
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, height: 44, child: FilledButton(
                  onPressed: cart.isEmpty ? null : () => _holdCart(),
                  style: FilledButton.styleFrom(backgroundColor: cs.secondaryContainer, foregroundColor: cs.onSecondaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.access_time, size: 14), SizedBox(width: 6), Text('Tahan', style: TextStyle(fontWeight: FontWeight.bold))]),
                )),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 56, child: FilledButton(
                  onPressed: cart.isEmpty ? null : () => _showPayment(),
                  style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 1),
                  child: const Text('💳 BAYAR SEKARANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                )),
              ])),
            ]),
          ),
        ])),
      ]),
      // === OVERLAYS ===
      // Dashboard overlay
      if (showDashboard) ...[_overlay(() => setState(() => showDashboard = false)),
        Positioned(bottom: isMobile ? 80 : 16, left: 16, right: isMobile ? 16 : null, width: isMobile ? null : 400,
          child: Material(elevation: 8, borderRadius: BorderRadius.circular(16), color: cs.surfaceBright,
            child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('📊 Rekap Hari Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                InkWell(onTap: () => setState(() => showDashboard = false), child: const Text('✕')),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                _statCard('Penjualan', fmtPrice(todayStats['total_sales'] ?? 0), cs.primaryContainer.withValues(alpha: 0.3), cs.primary),
                const SizedBox(width: 8),
                _statCard('Transaksi', '${todayStats['total_transactions'] ?? 0}', cs.secondaryContainer.withValues(alpha: 0.3), cs.secondary),
                const SizedBox(width: 8),
                _statCard('Rata-Rata', fmtPrice(todayStats['avg_transaction'] ?? 0), cs.tertiaryContainer.withValues(alpha: 0.3), cs.tertiary),
              ]),
            ]))))],
      // History overlay
      if (showHistory) ...[_overlay(() => setState(() => showHistory = false)),
        Center(child: Material(elevation: 8, borderRadius: BorderRadius.circular(16), color: cs.surfaceBright,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('📄 Riwayat Hari Ini', style: TextStyle(fontWeight: FontWeight.bold)), InkWell(onTap: () => setState(() => showHistory = false), child: const Text('✕'))])),
              const Divider(height: 1),
              Flexible(child: txHistory.isEmpty
                ? const Padding(padding: EdgeInsets.all(32), child: Text('Belum ada transaksi hari ini'))
                : ListView.builder(shrinkWrap: true, itemCount: txHistory.length, padding: const EdgeInsets.all(12),
                    itemBuilder: (_, i) { final tx = txHistory[i]; return Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('#${tx['id']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)), Text('${tx['created_at'] ?? ''}'.split(' ').last.length >= 5 ? '${tx['created_at']}'.split(' ').last.substring(0, 5) : '', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(tx['cashier_name'] ?? '-', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)), Text(fmtPrice(tx['total_amount'] ?? 0), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: cs.primary))]),
                        const SizedBox(height: 4),
                        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Bayar: ${fmtPrice(tx['paid_amount'] ?? 0)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)), Text('Kembali: ${fmtPrice(tx['change_amount'] ?? 0)}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))]),
                        const SizedBox(height: 8),
                        SizedBox(width: double.infinity, height: 32, child: FilledButton(onPressed: () => _reprintReceipt(tx['id']),
                          style: FilledButton.styleFrom(backgroundColor: cs.primaryContainer, foregroundColor: cs.onPrimaryContainer, padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.print, size: 12), SizedBox(width: 4), Text('Lihat / Cetak Ulang', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))]))),
                      ])); })),
            ]))))],
      // Held carts overlay
      if (showHeldCarts) ...[_overlay(() => setState(() => showHeldCarts = false)),
        Positioned(top: 120, right: 16, width: 320,
          child: Material(elevation: 8, borderRadius: BorderRadius.circular(16), color: cs.surfaceBright,
            child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Text('⏱ Ditahan (${heldCarts.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                InkWell(onTap: () => setState(() => showHeldCarts = false), child: const Text('✕'))]),
              const SizedBox(height: 8),
              if (heldCarts.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada transaksi ditahan')),
              ...heldCarts.map((h) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(h['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('${(h['cart_data'] as List?)?.length ?? 0} item · ${fmtPrice(h['total'] ?? 0)}', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: SizedBox(height: 32, child: FilledButton(onPressed: () => _recallCart(h), style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))), child: const Text('Panggil', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))))),
                    const SizedBox(width: 8),
                    SizedBox(height: 32, child: FilledButton(onPressed: () => _deleteHeldCart(h['id'], h['label'] ?? 'antrian ini'),
                      style: FilledButton.styleFrom(backgroundColor: cs.errorContainer.withValues(alpha: 0.5), foregroundColor: cs.error, padding: const EdgeInsets.symmetric(horizontal: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('Hapus', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
                  ]),
                ]))),
            ]))))],
      // Profile overlay
      if (showProfile) ...[_overlay(() => setState(() => showProfile = false)),
        Center(child: Material(elevation: 8, borderRadius: BorderRadius.circular(16), color: cs.surfaceBright,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 384, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
            child: SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('👤 Profil Saya', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                InkWell(onTap: () => setState(() => showProfile = false), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant)))]),
              if (profileMsg.isNotEmpty) ...[const SizedBox(height: 12), Container(width: double.infinity, padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: profileMsg.startsWith('✅') ? Colors.green.withValues(alpha: 0.1) : cs.errorContainer, borderRadius: BorderRadius.circular(8)),
                child: Text(profileMsg, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: profileMsg.startsWith('✅') ? Colors.green : cs.onErrorContainer), textAlign: TextAlign.center))],
              const SizedBox(height: 16),
              // === NAME ===
              _sectionBox('📝 Nama Tampilan', [
                _field(_nameCtrl..text = _nameCtrl.text.isEmpty ? auth.userName : _nameCtrl.text, 'Nama', false),
              ], 'Simpan Nama', cs.primary, cs.onPrimary, _saveName),
              const SizedBox(height: 12),
              // === PASSWORD ===
              _sectionBox('🔑 Ganti Password', [
                _field(_oldPasswordCtrl, 'Password Lama', true),
                const SizedBox(height: 8),
                _field(_newPasswordCtrl, 'Password Baru', true),
                const SizedBox(height: 8),
                _field(_confirmPasswordCtrl, 'Konfirmasi Password', true),
              ], 'Simpan Password', cs.secondary, cs.onSecondary, _savePassword),
              const SizedBox(height: 12),
              // === PIN ===
              _sectionBox('🔢 Ganti PIN (6 angka)', [
                _field(_oldPinCtrl, 'PIN Lama', true, isPin: true),
                const SizedBox(height: 8),
                _field(_newPinCtrl, 'PIN Baru', true, isPin: true),
                const SizedBox(height: 8),
                _field(_confirmPinCtrl, 'Konfirmasi PIN', true, isPin: true),
              ], 'Simpan PIN', cs.tertiary, cs.onTertiary, _savePin),
            ])))))],
      // Mobile cart bottom sheet
      if (cartOpen && isMobile) ...[_overlay(() => setState(() => cartOpen = false)),
        Positioned(left: 0, right: 0, bottom: 0, child: Material(elevation: 8, color: cs.surfaceBright,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2)))),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [const Text('🛒 Keranjang', style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(12)), child: Text('${cart.length}', style: TextStyle(color: cs.onPrimary, fontSize: 12, fontWeight: FontWeight.bold)))]),
                Row(children: [
                  if (cart.isNotEmpty) TextButton(onPressed: _clearCart, child: Text('Kosongkan', style: TextStyle(color: cs.error, fontSize: 12))),
                  InkWell(onTap: () => setState(() => cartOpen = false), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant))),
                ]),
              ])),
              const Divider(),
              Flexible(child: ListView.builder(shrinkWrap: true, itemCount: cart.length, padding: const EdgeInsets.all(12),
                itemBuilder: (_, i) => Padding(padding: const EdgeInsets.only(bottom: 8),
                  child: CartItemWidget(item: cart[i], onIncrement: () => _incrementItem(i), onDecrement: () => _decrementItem(i), onRemove: () => _removeItem(i), onSetQuantity: (q) => _setItemQuantity(i, q), onMaxSplit: () => _applyMaxSplit(cart[i]['product']))))),
              Padding(padding: const EdgeInsets.all(16), child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cs.onSurfaceVariant)), Text(fmtPrice(cartTotal), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: cs.primary))]),
                const SizedBox(height: 8),
                Row(children: [Expanded(child: SizedBox(height: 44, child: FilledButton(onPressed: cart.isEmpty ? null : _holdCart, style: FilledButton.styleFrom(backgroundColor: cs.secondaryContainer, foregroundColor: cs.onSecondaryContainer, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.access_time, size: 14), SizedBox(width: 6), Text('Tahan', style: TextStyle(fontWeight: FontWeight.bold))]))))]),
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, height: 56, child: FilledButton(onPressed: cart.isEmpty ? null : _showPayment, style: FilledButton.styleFrom(backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 1),
                  child: const Text('💳 BAYAR SEKARANG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)))),
              ])),
            ]))))],
      // Low stock overlay
      if (showLowStock) ...[_overlay(() => setState(() => showLowStock = false)),
        Center(child: Material(elevation: 8, borderRadius: BorderRadius.circular(16), color: cs.surfaceBright,
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: 440, maxHeight: MediaQuery.sizeOf(context).height * 0.8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Padding(padding: const EdgeInsets.all(16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('📦 Status Stok', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                InkWell(onTap: () => setState(() => showLowStock = false), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: cs.surfaceContainer, borderRadius: BorderRadius.circular(8)), child: Icon(Icons.close, size: 18, color: cs.onSurfaceVariant)))])),
              // Tabs
              Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Row(children: [
                Expanded(child: InkWell(onTap: () => setState(() => stockTab = 'empty'), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: stockTab == 'empty' ? cs.error : cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('🚫 Habis (${outOfStockItems.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stockTab == 'empty' ? cs.onError : cs.onSurfaceVariant)))))),
                const SizedBox(width: 8),
                Expanded(child: InkWell(onTap: () => setState(() => stockTab = 'low'), child: Container(padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: stockTab == 'low' ? Colors.amber : cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
                  child: Center(child: Text('⚠️ Rendah (${lowStockItems.length})', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: stockTab == 'low' ? Colors.white : cs.onSurfaceVariant)))))),
              ])),
              const SizedBox(height: 8),
              Flexible(child: ListView(shrinkWrap: true, padding: const EdgeInsets.all(16), children: [
                if (stockTab == 'empty') ...(outOfStockItems.isEmpty ? [const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Tidak ada stok habis 👍')))] : outOfStockItems.map((item) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: cs.errorContainer.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: cs.error.withValues(alpha: 0.2))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), Text(item['category_name'] ?? '-', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))]),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: cs.error.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text('HABIS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: cs.error)))]))).toList()),
                if (stockTab == 'low') ...(lowStockItems.isEmpty ? [const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Semua stok aman 👍')))] : lowStockItems.map((item) => Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.withValues(alpha: 0.3))),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)), Text('${item['category_name'] ?? '-'} · Min: ${item['min_stock_alert'] ?? 0}', style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant))]),
                    Text('${(item['stock_quantity'] as num?)?.round() ?? 0}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.amber[700]))]))).toList()),
              ])),
            ]))))],
      ]),

      // Mobile FAB
      floatingActionButton: isMobile && cart.isNotEmpty && !cartOpen ? FloatingActionButton(
        onPressed: () => setState(() => cartOpen = true),
        backgroundColor: cs.primary,
        child: Badge(label: Text('${cart.length}'), child: Icon(Icons.shopping_bag, color: cs.onPrimary)),
      ) : null,

      // Mobile Bottom Nav
      bottomNavigationBar: isMobile ? Container(
        margin: const EdgeInsets.only(left: 12, right: 12, bottom: 12),
        decoration: BoxDecoration(color: cs.surfaceBright.withValues(alpha: 0.95), borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4))]),
        child: ClipRRect(borderRadius: BorderRadius.circular(24),
          child: BottomNavigationBar(
            currentIndex: _mobileNavIndex, backgroundColor: Colors.transparent, elevation: 0, type: BottomNavigationBarType.fixed,
            selectedItemColor: cs.primary, unselectedItemColor: cs.onSurfaceVariant,
            selectedLabelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold), unselectedLabelStyle: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600),
            onTap: (i) { setState(() { _closeAllModals(); _mobileNavIndex = i; });
              if (i == 0) { setState(() => showDashboard = true); _loadDashboard(); }
              else if (i == 1) { setState(() => showHistory = true); _loadHistory(); }
              else if (i == 2) setState(() => showSearch = true);
              else if (i == 3) setState(() => showProfile = true);
              else if (auth.isAdmin && i == 4) context.go('/admin');
              else if ((auth.isAdmin && i == 5) || (!auth.isAdmin && i == 4)) _handleLogout();
            },
            items: [
              const BottomNavigationBarItem(icon: Icon(Icons.pie_chart), label: 'Rekap'),
              const BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
              const BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Cari'),
              const BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profil'),
              if (auth.isAdmin) const BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Admin'),
              const BottomNavigationBarItem(icon: Icon(Icons.logout), label: 'Keluar'),
            ],
          )),
      ) : null,
    );
  }

  void _showPayment() {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => PaymentDialog(total: cartTotal, onConfirm: _handleCheckout));
  }

  Future<void> _holdCart() async {
    if (cart.isEmpty) return;
    if (activeCartLabel != null) {
      _doHoldCart(activeCartLabel!);
      return;
    }
    int counter = 1;
    String defaultLabel = 'Pembeli $counter';
    while (heldCarts.any((c) => c['label'] == defaultLabel)) {
      counter++;
      defaultLabel = 'Pembeli $counter';
    }
    final ctrl = TextEditingController(text: defaultLabel);
    final label = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('🛒 Tahan Transaksi'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Beri nama untuk antrian ini', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 12),
        TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(
          hintText: 'Nama pembeli...', filled: true)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim().isEmpty ? defaultLabel : ctrl.text.trim()), child: const Text('Simpan')),
      ],
    ));
    if (label != null) _doHoldCart(label);
  }

  Future<void> _doHoldCart(String label) async {
    try {
      await Api.post('/held-carts', body: {'label': label, 'cart_data': cart, 'total': cartTotal});
      setState(() { cart.clear(); cartOpen = false; activeCartLabel = null; });
      await _loadHeldCarts(); _loadData();
    } catch (e) { if (mounted) showToast(context, 'Gagal: $e'); }
  }

  Future<void> _clearCart() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => const KayConfirmDialog(
        title: 'Kosongkan Keranjang',
        message: 'Apakah Anda yakin ingin mengosongkan semua item di keranjang ini?',
        confirmText: 'Ya, Kosongkan',
      ),
    );
    if (confirmed == true) {
      setState(() {
        cart.clear();
        activeCartLabel = null;
        if (MediaQuery.sizeOf(context).width < 768) cartOpen = false;
      });
    }
  }

  Future<void> _recallCart(dynamic held) async {
    if (cart.isNotEmpty) {
      await Api.post('/held-carts', body: {'label': activeCartLabel ?? 'Pembeli aktif', 'cart_data': cart, 'total': cartTotal}).catchError((_) {});
    }
    await Api.delete('/held-carts/${held['id']}').catchError((_) {});
    setState(() { cart = List<Map<String, dynamic>>.from((held['cart_data'] as List).map((e) => Map<String, dynamic>.from(e))); activeCartLabel = held['label']; showHeldCarts = false; });
    await _loadHeldCarts();
  }

  Future<void> _deleteHeldCart(int id, String label) async {
    final confirmed = await showDialog<bool>(context: context, builder: (_) => KayConfirmDialog(
      title: 'Hapus Antrian', message: 'Yakin ingin menghapus antrian "$label"? Semua item akan dihapus.', confirmText: 'Ya, Hapus'));
    if (confirmed != true) return;
    try { await Api.delete('/held-carts/$id'); await _loadHeldCarts(); _loadData(); } catch (_) {}
  }

  Widget _overlay(VoidCallback onTap) => Positioned.fill(child: GestureDetector(onTap: onTap, child: Container(color: Colors.black54)));

  Widget _statCard(String label, String value, Color bg, Color textColor) {
    return Expanded(child: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: textColor)),
      ])));
  }

  Future<void> _reprintReceipt(dynamic txId) async {
    try {
      final res = await Api.get('/transactions/$txId');
      if (mounted) {
        showDialog(context: context, builder: (_) => ReceiptModal(
          transaction: res['transaction'] ?? res,
          details: List<Map<String, dynamic>>.from(res['details'] ?? [])),
        );
      }
    } catch (e) { if (mounted) showToast(context, 'Gagal memuat nota: $e'); }
  }

  Future<void> _saveName() async {
    try {
      final name = _nameCtrl.text.trim();
      if (name.isEmpty || name == context.read<AuthProvider>().userName) { setState(() => profileMsg = 'Tidak ada perubahan nama'); return; }
      await Api.put('/auth/profile', body: {'name': name});
      context.read<AuthProvider>().updateUserName(name);
      setState(() => profileMsg = '✅ Nama berhasil diubah!');
    } catch (e) { setState(() => profileMsg = '❌ ${e.toString().replaceFirst("Exception: ", "")}'); }
  }

  Future<void> _savePassword() async {
    try {
      if (_newPasswordCtrl.text.isEmpty) { setState(() => profileMsg = 'Password baru wajib diisi'); return; }
      await Api.put('/auth/profile', body: {'old_password': _oldPasswordCtrl.text, 'new_password': _newPasswordCtrl.text, 'confirm_password': _confirmPasswordCtrl.text});
      _oldPasswordCtrl.clear(); _newPasswordCtrl.clear(); _confirmPasswordCtrl.clear();
      setState(() => profileMsg = '✅ Password berhasil diubah!');
    } catch (e) { setState(() => profileMsg = '❌ ${e.toString().replaceFirst("Exception: ", "")}'); }
  }

  Future<void> _savePin() async {
    try {
      if (_newPinCtrl.text.isEmpty) { setState(() => profileMsg = 'PIN baru wajib diisi'); return; }
      await Api.put('/auth/profile', body: {'old_pin': _oldPinCtrl.text, 'new_pin': _newPinCtrl.text, 'confirm_pin': _confirmPinCtrl.text});
      _oldPinCtrl.clear(); _newPinCtrl.clear(); _confirmPinCtrl.clear();
      setState(() => profileMsg = '✅ PIN berhasil diubah!');
    } catch (e) { setState(() => profileMsg = '❌ ${e.toString().replaceFirst("Exception: ", "")}'); }
  }

  Widget _sectionBox(String title, List<Widget> fields, String btnLabel, Color btnBg, Color btnFg, VoidCallback onSave) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: cs.surfaceContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.onSurfaceVariant)),
        const SizedBox(height: 8),
        ...fields,
        const SizedBox(height: 8),
        SizedBox(width: double.infinity, height: 36, child: FilledButton(onPressed: onSave,
          style: FilledButton.styleFrom(backgroundColor: btnBg, foregroundColor: btnFg, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          child: Text(btnLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)))),
      ]));
  }

  Widget _field(TextEditingController ctrl, String hint, bool obscure, {bool isPin = false}) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(height: 40, child: TextField(
      controller: ctrl, obscureText: obscure,
      keyboardType: isPin ? TextInputType.number : TextInputType.text,
      textAlign: isPin ? TextAlign.center : TextAlign.start,
      style: TextStyle(fontSize: 14, color: cs.onSurface, letterSpacing: isPin ? 8 : 0),
      decoration: InputDecoration(hintText: hint, filled: true, fillColor: cs.surfaceContainer, isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),


),
    ));
  }

  Widget _toolbarBtn(IconData icon, String label, {Color? color, Color? textColor, String? badge, VoidCallback? onTap}) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(12),
      child: Container(height: 36, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(color: color ?? cs.surfaceContainer, borderRadius: BorderRadius.circular(12)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: textColor ?? cs.onSurfaceVariant),
          if (label.isNotEmpty) ...[const SizedBox(width: 6), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor ?? cs.onSurfaceVariant))],
          if (badge != null) ...[const SizedBox(width: 6), Container(constraints: const BoxConstraints(minWidth: 20), height: 20, padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: cs.secondary, borderRadius: BorderRadius.circular(10)),
            child: Center(child: Text(badge, style: TextStyle(color: cs.onSecondary, fontSize: 10, fontWeight: FontWeight.bold))))],
        ])));
  }
}
