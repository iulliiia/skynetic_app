import 'package:flutter/material.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;

  const OnboardingPage({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 48,
            maxWidth: 600,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  data.icon,
                  size: 80,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                data.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                data.description,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
