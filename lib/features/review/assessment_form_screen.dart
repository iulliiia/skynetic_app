import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/auth/auth_form_widgets.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Doctor: structured clinical assessment. Submitting completes the request
/// (or adds a new version when it is already completed).
class AssessmentFormScreen extends ConsumerStatefulWidget {
  final String requestId;
  const AssessmentFormScreen({super.key, required this.requestId});

  @override
  ConsumerState<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends ConsumerState<AssessmentFormScreen> {
  final _form = GlobalKey<FormState>();
  final _impression = TextEditingController();
  final _comments = TextEditingController();
  final _confirmed = TextEditingController();
  String? _category;
  String? _certainty;
  String? _recommendation;
  String _provenance = 'image_based';
  bool _inPerson = false;
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _impression.dispose();
    _comments.dispose();
    _confirmed.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(reviewRepositoryProvider).submitAssessment(
            widget.requestId,
            AssessmentInput(
              clinicalImpression: _impression.text.trim(),
              suspectedCategory: _category!,
              certainty: _certainty!,
              recommendation: _recommendation!,
              inPersonConsultationAdvised: _inPerson,
              provenance: _provenance,
              confirmedDiagnosis: _provenance == 'image_based' ? null : _confirmed.text.trim(),
              additionalComments: _comments.text.trim(),
            ),
          );
      if (!mounted) return;
      invalidateReviewData(ref);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Evaluarea a fost trimisă pacientului.')));
      context.pop();
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Evaluare clinică')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ResponsiveCenter(
            maxWidth: 600,
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Evaluarea este structurată pentru a putea fi folosită ulterior în cercetare. Specifică pe ce se bazează: o opinie pe imagine nu este un diagnostic confirmat.',
                    style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),
                  FormErrorBanner(error: _error),
                  TextFormField(
                    controller: _impression,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const InputDecoration(labelText: 'Impresie clinică *', alignLabelWithHint: true),
                    validator: (v) => validateRequired(v, 'impresia clinică'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Categorie suspectată *'),
                    items: [
                      for (final e in ClinicalVocab.suspectedCategories.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                    validator: (v) => v == null ? 'Alege o categorie' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _certainty,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Certitudine *'),
                    items: [
                      for (final e in ClinicalVocab.certainties.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _certainty = v),
                    validator: (v) => v == null ? 'Alege nivelul de certitudine' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _recommendation,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Recomandare *'),
                    items: [
                      for (final e in ClinicalVocab.recommendations.entries)
                        DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) => setState(() => _recommendation = v),
                    validator: (v) => v == null ? 'Alege o recomandare' : null,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Recomand consult în persoană'),
                    value: _inPerson,
                    onChanged: (v) => setState(() => _inPerson = v),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _provenance,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Baza evaluării'),
                    items: [
                      for (final e in ClinicalVocab.provenances.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
                    ],
                    onChanged: (v) => setState(() => _provenance = v ?? 'image_based'),
                  ),
                  if (_provenance != 'image_based') ...[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmed,
                      decoration: const InputDecoration(labelText: 'Diagnostic confirmat (opțional)'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _comments,
                    maxLines: 3,
                    maxLength: 4000,
                    decoration: const InputDecoration(labelText: 'Comentarii pentru pacient (opțional)', alignLabelWithHint: true),
                  ),
                  const SizedBox(height: 8),
                  BusyButton(busy: _busy, onPressed: _submit, label: 'Trimite evaluarea', icon: Icons.send),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
