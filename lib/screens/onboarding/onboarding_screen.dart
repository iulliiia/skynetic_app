import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_page.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';
import 'package:skynetic_app/widgets/custom_button.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 3;

  final List<OnboardingPageData> _pages = [
    OnboardingPageData(
      title: 'Fa sau Incarca o poza!',
      description:
          'Captureaza o imagine clara a leziunii pielii tale sau incarca o poza existenta din galeria ta.',
      icon: Icons.camera_alt_outlined,
    ),
    OnboardingPageData(
      title: 'Primeste analiza imediata',
      description:
          'Modelul AI va analiza imaginea si iti va oferi o clasificare detaliata.',
      icon: Icons.analytics_outlined,
    ),
    OnboardingPageData(
      title: 'Monitorizeaza evolutia!',
      description:
          'Salveaza-ti rezultatele pentru a monitoriza evolutia in timp si colaboreaza cu profesionisti.',
      icon: Icons.history,
    ),
  ];

  void _onPageChanged(int page) {
    setState(() {
      _currentPage = page;
    });
  }

  void _nextPage() {
    if (_currentPage < _numPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  void _completeOnboarding() async {
    await SharedPrefs.setOnboardingCompleted();
    if (mounted) context.go('/');
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                itemCount: _numPages,
                itemBuilder: (context, index) {
                  return OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _numPages,
                      (index) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _currentPage == index
                              ? AppColors.accent2
                              : AppColors.accent1,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  CustomButton(
                    text: _currentPage == _numPages - 1 ? 'Incepe' : 'Inainte',
                    onPressed: _nextPage,
                  ),
                  if (_currentPage < _numPages - 1)
                    TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text('Sari peste'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String description;
  final IconData icon;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.icon,
  });
}
