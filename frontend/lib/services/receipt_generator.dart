import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import '../core/helpers.dart';

class ReceiptGenerator {
  static Future<List<int>> generate({
    required Map<String, dynamic> transaction,
    required List<Map<String, dynamic>> details,
    required Map<String, dynamic> settings,
    PaperSize paperSize = PaperSize.mm58,
    CapabilityProfile? profile,
  }) async {
    profile ??= await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Header
    final storeName = settings['store_name']?.toString() ?? 'KAYPOS Store';
    final storeAddr = settings['store_address']?.toString() ?? '';
    final storePhone = settings['store_phone']?.toString() ?? '';

    bytes += generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    
    if (storeAddr.isNotEmpty) {
      bytes += generator.text(storeAddr, styles: const PosStyles(align: PosAlign.center));
    }
    if (storePhone.isNotEmpty) {
      bytes += generator.text('Tel: $storePhone', styles: const PosStyles(align: PosAlign.center));
    }
    bytes += generator.feed(1);

    // Transaction info
    bytes += generator.hr(ch: '-'); // Dashed line
    final dateStr = fmtDate(transaction['created_at'] ?? '');
    
    // Receipt header
    bytes += generator.row([
      PosColumn(text: '#${transaction['id']}', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: dateStr, width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    
    bytes += generator.row([
      PosColumn(text: 'Kasir:', width: 6, styles: const PosStyles(align: PosAlign.left)),
      PosColumn(text: transaction['cashier_name']?.toString() ?? '-', width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.hr(ch: '-');

    // Items
    for (var d in details) {
      bytes += generator.text(d['product_name']?.toString() ?? '', styles: const PosStyles(bold: true));
      
      final qty = (d['quantity'] as num?)?.toDouble() ?? 0.0;
      final formattedUnit = formatCartItemDisplay(
        qty,
        d['current_unit_data'],
        d['product_units'] as List<dynamic>?,
        d['base_unit'] as String?,
      );
      
      final price = fmtPrice(d['sold_price'] ?? 0);
      final subtotal = fmtPrice(d['subtotal'] ?? 0);
      
      final desc = '  $formattedUnit @ $price';
      
      bytes += generator.row([
        PosColumn(text: desc, width: 8, styles: const PosStyles(align: PosAlign.left)),
        PosColumn(text: subtotal, width: 4, styles: const PosStyles(align: PosAlign.right)),
      ]);
    }

    bytes += generator.hr(ch: '-');

    // Totals
    bytes += generator.row([
      PosColumn(text: 'TOTAL', width: 6, styles: const PosStyles(bold: true)),
      PosColumn(text: fmtPrice(transaction['total_amount'] ?? 0), width: 6, styles: const PosStyles(align: PosAlign.right, bold: true)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Bayar', width: 6),
      PosColumn(text: fmtPrice(transaction['paid_amount'] ?? 0), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);
    bytes += generator.row([
      PosColumn(text: 'Kembali', width: 6),
      PosColumn(text: fmtPrice(transaction['change_amount'] ?? 0), width: 6, styles: const PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.hr(ch: '-');

    // Footer
    bytes += generator.feed(1);
    bytes += generator.text('Terima Kasih', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('Barang yang sudah dibeli', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.text('tidak dapat dikembalikan', styles: const PosStyles(align: PosAlign.center));
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }

  static Future<List<int>> generateTestPrint({
    required Map<String, dynamic> settings,
    PaperSize paperSize = PaperSize.mm58,
    CapabilityProfile? profile,
  }) async {
    profile ??= await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    List<int> bytes = [];

    // Header
    final storeName = settings['store_name']?.toString() ?? 'KAYPOS Store';

    bytes += generator.text(storeName,
        styles: const PosStyles(align: PosAlign.center, bold: true, height: PosTextSize.size2, width: PosTextSize.size2));
    
    bytes += generator.text('Test Print OK!', styles: const PosStyles(align: PosAlign.center));
    bytes += generator.hr(ch: '-');
    bytes += generator.text(fmtDate(DateTime.now().toIso8601String()), styles: const PosStyles(align: PosAlign.center));
    
    bytes += generator.feed(2);
    bytes += generator.cut();

    return bytes;
  }
}
