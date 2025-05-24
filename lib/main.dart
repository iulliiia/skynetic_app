import 'package:flutter/material.dart';
import 'package:skynetic_app/screens/splash_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
      home: const SplashScreen(),
    );
  }
}
