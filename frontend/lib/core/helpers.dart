// KAYPOS — Helpers
import 'package:flutter/material.dart';

String fmtPrice(num n) {
  if (n < 1 && n > 0) return 'Rp ${n.toStringAsFixed(2)}';
  final formatted = n.round().toString().replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
  return 'Rp $formatted';
}

String fmtDate(String d) {
  try {
    final dt = DateTime.parse(d);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return d;
  }
}

void showToast(BuildContext context, String msg) {
  final height = MediaQuery.of(context).size.height;
  final width = MediaQuery.of(context).size.width;
  final cs = Theme.of(context).colorScheme;

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        msg, 
        style: TextStyle(fontWeight: FontWeight.w600, color: cs.onPrimary),
        textAlign: TextAlign.center,
      ),
      backgroundColor: cs.primary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: EdgeInsets.only(
        bottom: (height - 100) > 0 ? (height - 100) : 20, // push to top
        left: width * 0.25,   // center, half width
        right: width * 0.25,
      ),
      duration: const Duration(seconds: 3),
    ),
  );
}

String formatStock(num baseStock, List<dynamic>? units, String? baseUnit) {
  final bUnit = (baseUnit == null || baseUnit.trim().isEmpty) ? 'pcs' : baseUnit.trim();
  if (baseStock <= 0) return '0 $bUnit';
  
  if (units != null && units.isNotEmpty) {
    final sortedUnits = List.from(units)..sort((a, b) => ((b['qty_per_unit'] as num?) ?? 1).compareTo((a['qty_per_unit'] as num?) ?? 1));
    
    for (final u in sortedUnits) {
      final qtyPerUnit = (u['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
      if (qtyPerUnit > 1 && baseStock >= qtyPerUnit) {
        final majorQty = (baseStock / qtyPerUnit).floor();
        final remainder = baseStock - (majorQty * qtyPerUnit);
        
        final majorStr = majorQty.toString();
        if (remainder <= 0.001) {
          return '$majorStr ${u['unit_name']}';
        } else {
          final remStr = remainder == remainder.truncateToDouble() ? remainder.truncate().toString() : remainder.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
          return '$majorStr ${u['unit_name']} $remStr $bUnit';
        }
      }
    }
  }
  final bStr = baseStock == baseStock.truncateToDouble() ? baseStock.truncate().toString() : baseStock.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
  return '$bStr $bUnit';
}

String formatCartItemDisplay(double qty, dynamic currentUnitData, List<dynamic>? productUnits, String? baseUnit) {
  final bUnit = (baseUnit == null || baseUnit.trim().isEmpty) ? 'pcs' : baseUnit.trim();
  final currentMultiplier = (currentUnitData?['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
  final currentUnitName = (currentUnitData?['unit_name'] as String?) ?? bUnit;
  final totalBase = qty * currentMultiplier;

  if (productUnits != null && productUnits.isNotEmpty) {
    final sortedUnits = List.from(productUnits)..sort((a, b) => ((b['qty_per_unit'] as num?) ?? 1).compareTo((a['qty_per_unit'] as num?) ?? 1));
    
    bool canUpgrade = sortedUnits.any((u) {
      final qpu = (u['qty_per_unit'] as num?)?.toDouble() ?? 1.0;
      return qpu > currentMultiplier && totalBase >= qpu;
    });

    if (canUpgrade) {
      return formatStock(totalBase, productUnits, baseUnit);
    }
  }

  final qtyStr = qty == qty.truncateToDouble() ? qty.truncate().toString() : qty.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');

  if (qty == 1) {
    return '1 $currentUnitName';
  }

  if (currentMultiplier > 1) {
    final multStr = currentMultiplier == currentMultiplier.truncateToDouble() ? currentMultiplier.truncate().toString() : currentMultiplier.toStringAsFixed(2).replaceAll(RegExp(r'0*$'), '').replaceAll(RegExp(r'\.$'), '');
    return '${qtyStr}x $multStr $bUnit';
  } else {
    return '${qtyStr}x $bUnit';
  }
}

String toTitleCase(String text) {
  if (text.isEmpty) return text;
  return text.split(' ').map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  }).join(' ');
}

const Map<String, IconData> categoryIcons = {
  '📦': Icons.inventory_2,
  '🍔': Icons.fastfood,
  '🥤': Icons.local_drink,
  '🛍️': Icons.shopping_bag,
  '🏷️': Icons.local_offer,
  '☕': Icons.local_cafe,
  '🍰': Icons.cake,
  '🍎': Icons.apple,
  '📱': Icons.smartphone,
  '💻': Icons.computer,
  '👕': Icons.checkroom,
  '💊': Icons.medical_services,
  '🛠️': Icons.build,
  '📚': Icons.menu_book,
  '⚽': Icons.sports_soccer,
  '🚗': Icons.directions_car,
  '🏠': Icons.home,
  '🎵': Icons.music_note,
  '🐾': Icons.pets,
  '🧩': Icons.extension,
};

Widget buildCategoryIcon(String iconKey, {double size = 24}) {
  final iconData = categoryIcons[iconKey];
  if (iconData != null) {
    return Icon(iconData, size: size);
  }
  return Text(iconKey, style: TextStyle(fontSize: size));
}
