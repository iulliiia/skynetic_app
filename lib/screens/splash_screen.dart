import 'package:flutter/material.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_screen.dart';
import 'package:skynetic_app/screens/home_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late Animation<double> _logoFloat;

  String _animatedText = "Skynetic";
  String _displayedText = "";
  bool _showSubtitle = false;
  int _textIndex = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startTextAnimation();
    _navigate();
  }

  void _initAnimations() {
    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _logoFloat = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeInOut),
    );
  }

  void _startTextAnimation() async {
    for (int i = 0; i <= _animatedText.length; i++) {
      await Future.delayed(const Duration(milliseconds: 150));
      setState(() {
        _displayedText = _animatedText.substring(0, i);
      });
    }
    setState(() {
      _showSubtitle = true;
    });
  }

  void _navigate() async {
    await Future.delayed(const Duration(seconds: 5));
    final isDone = SharedPrefs.isOnboardingCompleted();
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              isDone ? const HomeScreen() : const OnboardingScreen(),
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.fromARGB(255, 100, 104, 159),
              AppColors.white,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedBuilder(
                animation: _logoFloat,
                builder: (context, child) {
                  return Transform.translate(
                    offset: Offset(0, -_logoFloat.value),
                    child: child,
                  );
                },
                child: SizedBox(
                  height: 250,
                  width: 250,
                  child: Image.asset('assets/images/skynetic_logo.png'),
                ),
              ),
              Text(
                _displayedText,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  fontSize: 40,
                  shadows: const [
                    Shadow(
                      color: AppColors.textPrimary,
                      offset: Offset(1, 2),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              AnimatedOpacity(
                opacity: _showSubtitle ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 1200),
                child: Text(
                  'Prevenția începe cu un click',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textSecondary,
                      ),
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(
                color: AppColors.accent2,
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
