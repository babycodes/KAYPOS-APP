import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme_provider.dart';
import 'core/api.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  await themeProvider.init();
  
  final prefs = await SharedPreferences.getInstance();
  final savedUrl = prefs.getString('kaypos_server_url');
  if (savedUrl != null && savedUrl.isNotEmpty) {
    Api.setServerUrl(savedUrl);
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider.value(value: themeProvider),
      ],
      child: const KayPosApp(),
    ),
  );
}

class KayPosApp extends StatelessWidget {
  const KayPosApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return MaterialApp.router(
      title: 'KAYPOS',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
