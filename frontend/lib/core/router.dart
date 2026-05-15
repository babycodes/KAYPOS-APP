import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/splash/splash_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/kasir/kasir_screen.dart';
import '../features/admin/admin_shell.dart';
import '../features/admin/admin_dashboard.dart';
import '../features/admin/kategori_page.dart';
import '../features/admin/produk_page.dart';
import '../features/admin/stok_page.dart';
import '../features/admin/laporan_page.dart';
import '../features/admin/karyawan_page.dart';
import '../features/admin/settings_page.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', pageBuilder: (context, state) => const NoTransitionPage(child: SplashScreen())),
    GoRoute(path: '/login', pageBuilder: (context, state) => const NoTransitionPage(child: LoginScreen())),
    GoRoute(path: '/kasir', pageBuilder: (context, state) => const NoTransitionPage(child: KasirScreen())),
    ShellRoute(
      builder: (context, state, child) => AdminShell(child: child),
      routes: [
        GoRoute(path: '/admin', pageBuilder: (context, state) => const NoTransitionPage(child: AdminDashboard())),
        GoRoute(path: '/admin/produk', pageBuilder: (context, state) => const NoTransitionPage(child: ProdukPage())),
        GoRoute(path: '/admin/kategori', pageBuilder: (context, state) => const NoTransitionPage(child: KategoriPage())),
        GoRoute(path: '/admin/stok', pageBuilder: (context, state) => const NoTransitionPage(child: StokPage())),
        GoRoute(path: '/admin/laporan', pageBuilder: (context, state) => const NoTransitionPage(child: LaporanPage())),
        GoRoute(path: '/admin/karyawan', pageBuilder: (context, state) => const NoTransitionPage(child: KaryawanPage())),
        GoRoute(path: '/admin/settings', pageBuilder: (context, state) => const NoTransitionPage(child: SettingsPage())),
      ],
    ),
  ],
);
