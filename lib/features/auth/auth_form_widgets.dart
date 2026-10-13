import 'package:flutter/material.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Shared validators and small widgets for the auth forms.

String? validateEmail(String? v) {
  final s = v?.trim() ?? '';
  if (s.isEmpty) return 'Introdu adresa de email';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)) return 'Adresa de email nu este validă';
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Introdu parola';
  if (v.length < 10) return 'Parola trebuie să aibă cel puțin 10 caractere';
  return null;
}

/// [noun] is the field in lower case, e.g. 'prenumele' → "Completează prenumele".
String? validateRequired(String? v, [String noun = 'câmpul']) =>
    (v == null || v.trim().isEmpty) ? 'Completează $noun' : null;

/// Shows an [ApiException] (or anything else) as an inline error card.
class FormErrorBanner extends StatelessWidget {
  final Object? error;
  const FormErrorBanner({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final e = error;
    final message = e is ApiException ? e.message : 'A apărut o eroare. Încearcă din nou.';
    final details = e is ApiException ? e.details.values.toList() : const <String>[];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(message, style: const TextStyle(color: Colors.red))),
            ],
          ),
          for (final d in details)
            Padding(
              padding: const EdgeInsets.only(left: 28, top: 4),
              child: Text('• $d', style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// Title + subtitle used on top of the auth screens.
class AuthHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  const AuthHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.primary)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(fontSize: 15, color: AppColors.textSecondary, height: 1.4)),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Primary button with a progress indicator while [busy].
class BusyButton extends StatelessWidget {
  final bool busy;
  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  const BusyButton({super.key, required this.busy, required this.onPressed, required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: busy ? null : onPressed,
        icon: busy
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Icon(icon ?? Icons.arrow_forward),
        label: Text(label),
      ),
    );
  }
}
