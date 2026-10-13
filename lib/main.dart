import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro_RO', null);
  await SharedPrefs.init();
  runApp(const ProviderScope(child: SkyneticApp()));
}

class SkyneticApp extends ConsumerWidget {
  const SkyneticApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Skynetic',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      routerConfig: router,
    );
  }
}
