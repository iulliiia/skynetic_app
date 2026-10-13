import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/features/auth/auth_form_widgets.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  final String? initialRole; // 'patient' | 'doctor'
  final String? next;
  const RegisterScreen({super.key, this.initialRole, this.next});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _specialty = TextEditingController(text: 'Dermatovenerologie');
  final _registrationNumber = TextEditingController();
  final _institution = TextEditingController();

  late UserRole _role = widget.initialRole == 'doctor' ? UserRole.doctor : UserRole.patient;
  bool _noticeAccepted = false;
  bool _busy = false;
  bool _obscure = true;
  Object? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _email, _password, _specialty, _registrationNumber, _institution]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (!_noticeAccepted) {
      setState(() => _error = const ApiException(
            code: 'notice_required',
            message: 'Trebuie să accepți nota de prelucrare a datelor pentru a continua.',
          ));
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final controller = ref.read(authControllerProvider.notifier);
    try {
      if (_role == UserRole.patient) {
        await controller.registerPatient(
          _email.text,
          _password.text,
          PatientRegistration(firstName: _firstName.text.trim(), lastName: _lastName.text.trim()),
        );
        if (!mounted) return;
        context.go(widget.next ?? '/');
      } else {
        await controller.registerDoctor(
          _email.text,
          _password.text,
          DoctorRegistration(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            specialty: _specialty.text.trim(),
            registrationNumber: _registrationNumber.text.trim(),
            institution: _institution.text.trim(),
          ),
        );
        if (!mounted) return;
        context.go('/doctor');
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDoctor = _role == UserRole.doctor;
    return Scaffold(
      appBar: AppBar(title: const Text('Creează un cont')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveCenter(
            maxWidth: 520,
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AuthHeader(
                    title: 'Cont nou',
                    subtitle: 'Alege tipul de cont. Conturile de medic sunt verificate manual înainte de activare.',
                  ),
                  SegmentedButton<UserRole>(
                    segments: const [
                      ButtonSegment(value: UserRole.patient, label: Text('Pacient'), icon: Icon(Icons.person_outline)),
                      ButtonSegment(value: UserRole.doctor, label: Text('Medic'), icon: Icon(Icons.medical_services_outlined)),
                    ],
                    selected: {_role},
                    onSelectionChanged: _busy ? null : (s) => setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 24),
                  FormErrorBanner(error: _error),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Prenume'),
                          validator: (v) => validateRequired(v, 'prenumele'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _lastName,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(labelText: 'Nume'),
                          validator: (v) => validateRequired(v, 'numele'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.mail_outline)),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: _obscure,
                    decoration: InputDecoration(
                      labelText: 'Parolă (minimum 10 caractere)',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    validator: validatePassword,
                  ),
                  if (isDoctor) ...[
                    const SizedBox(height: 24),
                    const Text('Date profesionale',
                        style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _specialty,
                      decoration: const InputDecoration(labelText: 'Specialitate'),
                      validator: (v) => validateRequired(v, 'specialitatea'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _registrationNumber,
                      decoration: const InputDecoration(
                        labelText: 'Număr de înregistrare (Colegiul Medicilor)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) => validateRequired(v, 'numărul de înregistrare'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _institution,
                      decoration: const InputDecoration(labelText: 'Instituție / clinică (opțional)'),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.accent2.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: AppColors.accent3),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Contul va fi verificat de un administrator pe baza datelor profesionale. Până la aprobare nu vei putea evalua cazuri.',
                              style: TextStyle(fontSize: 13, height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  CheckboxListTile(
                    value: _noticeAccepted,
                    onChanged: _busy ? null : (v) => setState(() => _noticeAccepted = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Am citit și sunt de acord cu prelucrarea datelor contului și a imaginilor încărcate pentru funcționarea aplicației. Aplicația are scop informativ și nu oferă un diagnostic medical.',
                      style: TextStyle(fontSize: 13, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  BusyButton(busy: _busy, onPressed: _submit, label: 'Creează contul', icon: Icons.person_add_alt_1),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _busy ? null : () => context.canPop() ? context.pop() : context.go('/login'),
                    child: const Text('Ai deja cont? Autentifică-te'),
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
