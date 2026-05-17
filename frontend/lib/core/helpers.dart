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
