import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/features/auth/auth_form_widgets.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

class LoginScreen extends ConsumerStatefulWidget {
  /// Where to go after signing in (e.g. `/claim`).
  final String? next;
  const LoginScreen({super.key, this.next});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  Object? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).login(_email.text, _password.text);
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      if (user?.role == UserRole.doctor || user?.role == UserRole.admin) {
        context.go('/doctor');
      } else {
        context.go(widget.next ?? '/');
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final registerUri = Uri(path: '/register', queryParameters: {
      if (widget.next != null) 'next': widget.next!,
    }).toString();

    return Scaffold(
      appBar: AppBar(title: const Text('Autentificare')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveCenter(
            maxWidth: 480,
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Bine ai revenit',
                    subtitle:
                        'Autentifică-te pentru a-ți urmări leziunile în timp și pentru a solicita evaluarea unui medic dermatolog.',
                  ),
                  FormErrorBanner(error: _error),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.password],
                    decoration: InputDecoration(
                      labelText: 'Parolă',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Introdu parola' : null,
                    onFieldSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: 24),
                  BusyButton(busy: _busy, onPressed: _submit, label: 'Intră în cont', icon: Icons.login),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => context.push(registerUri),
                    child: const Text('Nu ai cont? Creează unul'),
                  ),
                  if (widget.next == null)
                    TextButton(
                      onPressed: _busy ? null : () => context.go('/'),
                      child: const Text('Continuă fără cont'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
