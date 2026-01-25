import 'package:flutter/material.dart';
import 'package:skynetic_app/screens/home_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ro_RO', null);
  await SharedPrefs.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'skynetic_app',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeScreen(),
    );
  }
}
