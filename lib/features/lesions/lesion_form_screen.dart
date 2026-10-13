import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/auth/auth_form_widgets.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// Create (lesionId == null) or edit a lesion. Pops with the saved [Lesion].
class LesionFormScreen extends ConsumerStatefulWidget {
  final String? lesionId;
  const LesionFormScreen({super.key, this.lesionId});

  @override
  ConsumerState<LesionFormScreen> createState() => _LesionFormScreenState();
}

class _LesionFormScreenState extends ConsumerState<LesionFormScreen> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _notes = TextEditingController();
  String? _siteCode;
  String? _bodySide;
  String? _laterality;
  DateTime? _firstNoticed;
  final Set<String> _symptoms = {};
  bool _prefilled = false;
  bool _busy = false;
  Object? _error;

  bool get _isEdit => widget.lesionId != null;

  @override
  void dispose() {
    _label.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _prefill(Lesion l) {
    if (_prefilled) return;
    _prefilled = true;
    _label.text = l.label;
    _notes.text = l.notes ?? '';
    _siteCode = l.anatomicalSiteCode;
    _bodySide = l.bodySide;
    _laterality = l.laterality;
    _firstNoticed = l.firstNoticedOn == null ? null : DateTime.tryParse(l.firstNoticedOn!);
    _symptoms.addAll(l.symptoms);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstNoticed ?? DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      helpText: 'Când ai observat leziunea?',
    );
    if (picked != null) setState(() => _firstNoticed = picked);
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = LesionInput(
      label: _label.text.trim(),
      anatomicalSiteCode: _siteCode!,
      bodySide: _bodySide,
      laterality: _laterality,
      firstNoticedOn: _firstNoticed == null ? null : DateFormat('yyyy-MM-dd').format(_firstNoticed!),
      symptoms: _symptoms.toList(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
    try {
      final repo = ref.read(lesionRepositoryProvider);
      final saved = _isEdit
          ? await repo.updateLesion(widget.lesionId!, input.toJson())
          : await repo.createLesion(input);
      if (!mounted) return;
      invalidateLesionData(ref);
      if (context.canPop()) {
        context.pop(saved);
      } else {
        context.go('/lesions/${saved.id}');
      }
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sites = ref.watch(anatomicalSitesProvider);
    final existing = _isEdit ? ref.watch(lesionProvider(widget.lesionId!)) : null;
    existing?.whenData(_prefill);

    final loading = sites.isLoading || (existing?.isLoading ?? false);
    final loadError = sites.error ?? existing?.error;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Editează leziunea' : 'Leziune nouă')),
      body: SafeArea(
        child: loading
            ? const Center(child: CircularProgressIndicator())
            : loadError != null
                ? Center(child: Padding(padding: const EdgeInsets.all(24), child: FormErrorBanner(error: loadError)))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: ResponsiveCenter(
                      maxWidth: 560,
                      child: Form(
                        key: _form,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FormErrorBanner(error: _error),
                            TextFormField(
                              controller: _label,
                              maxLength: 80,
                              decoration: const InputDecoration(
                                labelText: 'Denumire *',
                                hintText: 'Ex: Aluniță umăr drept',
                                prefixIcon: Icon(Icons.label_outline),
                              ),
                              validator: (v) => validateRequired(v, 'denumirea'),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _siteCode,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Regiunea anatomică *',
                                prefixIcon: Icon(Icons.accessibility_new),
                              ),
                              items: [
                                for (final s in sites.value ?? const <AnatomicalSite>[])
                                  DropdownMenuItem(
                                    value: s.code,
                                    child: Text(
                                      s.isTopLevel ? s.labelRo : '     ${s.labelRo}',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(fontWeight: s.isTopLevel ? FontWeight.w600 : FontWeight.normal),
                                    ),
                                  ),
                              ],
                              onChanged: (v) => setState(() => _siteCode = v),
                              validator: (v) => v == null ? 'Alege regiunea anatomică' : null,
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _bodySide,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Partea corpului'),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('—')),
                                      for (final e in LesionVocab.bodySides.entries)
                                        DropdownMenuItem(value: e.key, child: Text(e.value, overflow: TextOverflow.ellipsis)),
                                    ],
                                    onChanged: (v) => setState(() => _bodySide = v),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String?>(
                                    initialValue: _laterality,
                                    isExpanded: true,
                                    decoration: const InputDecoration(labelText: 'Lateralitate'),
                                    items: [
                                      const DropdownMenuItem(value: null, child: Text('—')),
                                      for (final e in LesionVocab.lateralities.entries)
                                        DropdownMenuItem(value: e.key, child: Text(e.value)),
                                    ],
                                    onChanged: (v) => setState(() => _laterality = v),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.event_outlined, color: AppColors.primary),
                              title: Text(_firstNoticed == null
                                  ? 'Observată pentru prima dată (opțional)'
                                  : 'Observată: ${DateFormat('d MMMM yyyy', 'ro_RO').format(_firstNoticed!)}'),
                              trailing: _firstNoticed == null
                                  ? const Icon(Icons.chevron_right)
                                  : IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () => setState(() => _firstNoticed = null)),
                              onTap: _pickDate,
                            ),
                            const SizedBox(height: 8),
                            const Text('Simptome', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primary)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                for (final e in LesionVocab.symptoms.entries)
                                  FilterChip(
                                    label: Text(e.value),
                                    selected: _symptoms.contains(e.key),
                                    onSelected: (on) => setState(() => on ? _symptoms.add(e.key) : _symptoms.remove(e.key)),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _notes,
                              maxLines: 3,
                              maxLength: 2000,
                              decoration: const InputDecoration(
                                labelText: 'Note (opțional)',
                                hintText: 'Ex: a apărut după vacanța la mare',
                                prefixIcon: Icon(Icons.note_outlined),
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: 16),
                            BusyButton(
                              busy: _busy,
                              onPressed: _submit,
                              label: _isEdit ? 'Salvează modificările' : 'Creează leziunea',
                              icon: Icons.check,
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
