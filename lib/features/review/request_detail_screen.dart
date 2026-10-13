import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/chat/chat_controller.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart' show PredictionBadge;
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/prediction_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/features/review/review_repository.dart';
import 'package:skynetic_app/features/review/review_widgets.dart';
import 'package:skynetic_app/features/scans/authenticated_image.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// One review request. Patients see status, doctor and assessment; the
/// assigned doctor also sees the case data and the workflow actions.
class RequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;
  const RequestDetailScreen({super.key, required this.requestId});

  @override
  ConsumerState<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await action();
      invalidateReviewData(ref);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Acțiunea nu a reușit. Încearcă din nou.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _askText(String title, String label) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: c, maxLines: 3, maxLength: 2000, decoration: InputDecoration(labelText: label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Anulează')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, c.text.trim().isEmpty ? null : c.text.trim()),
            child: const Text('Trimite'),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirm(String title, String body) async =>
      (await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Nu')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Da')),
          ],
        ),
      )) ??
      false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isDoctor = auth.isDoctor;
    final request = ref.watch(requestProvider(widget.requestId));

    return Scaffold(
      appBar: AppBar(title: Text(isDoctor ? 'Caz' : 'Evaluare medicală')),
      body: request.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(e.toString(), textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton(onPressed: () => invalidateReviewData(ref), child: const Text('Reîncearcă')),
            ]),
          ),
        ),
        data: (r) => RefreshIndicator(
          onRefresh: () async {
            invalidateReviewData(ref);
            await ref.read(requestProvider(widget.requestId).future);
          },
          child: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _Header(request: r, isDoctor: isDoctor),
                const SizedBox(height: 16),
                if (r.scan != null) _ScanSection(request: r),
                if (isDoctor && r.patient != null) _PatientSection(patient: r.patient!),
                _LesionSection(lesion: r.lesion),
                if (r.latestReview != null)
                  SectionCard(
                    title: 'Evaluarea medicului',
                    trailing: isDoctor && !_busy
                        ? TextButton(onPressed: () => _openAssessment(r), child: const Text('Revizuiește'))
                        : null,
                    child: AssessmentView(review: r.latestReview!),
                  ),
                if (!isDoctor && r.status == ReviewStatus.completed && r.latestReview != null) _DisclaimerCard(),
                if (r.latestNote != null && (r.status == ReviewStatus.needsInfo || r.status == ReviewStatus.rejected))
                  SectionCard(
                    title: r.status == ReviewStatus.needsInfo ? 'Mesajul medicului' : 'Motivul respingerii',
                    child: Text(r.latestNote!, style: const TextStyle(height: 1.4)),
                  ),
                if (r.status != ReviewStatus.pending && (r.isOpen || r.status == ReviewStatus.completed))
                  _ChatButton(requestId: r.id, isDoctor: isDoctor),
                _Timeline(events: r.events),
                const SizedBox(height: 16),
                if (isDoctor) _DoctorActions(request: r, busy: _busy, onAction: _doctorAction, onAssess: () => _openAssessment(r))
                else if (r.status == ReviewStatus.pending)
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            if (await _confirm('Retragi cererea?', 'Medicul nu va mai primi această cerere.')) {
                              await _run(() => ref.read(reviewRepositoryProvider).cancel(r.id));
                            }
                          },
                    icon: const Icon(Icons.close),
                    label: const Text('Retrage cererea'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openAssessment(ReviewRequest r) async {
    await context.push('/review-requests/${r.id}/assess');
    if (mounted) invalidateReviewData(ref);
  }

  Future<void> _doctorAction(String action, ReviewRequest r) async {
    final repo = ref.read(reviewRepositoryProvider);
    switch (action) {
      case 'accept':
        await _run(() => repo.accept(r.id));
      case 'needs_info':
        final note = await _askText('Ce informații lipsesc?', 'Mesaj pentru pacient');
        if (note != null) await _run(() => repo.needsInfo(r.id, note));
      case 'resume':
        await _run(() => repo.resume(r.id));
      case 'reject':
        final reason = await _askText('Motivul respingerii', 'Explicație pentru pacient');
        if (reason != null) await _run(() => repo.reject(r.id, reason));
    }
  }
}

class _Header extends StatelessWidget {
  final ReviewRequest request;
  final bool isDoctor;
  const _Header({required this.request, required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    final r = request;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(r.lesion.label,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ),
            const SizedBox(width: 8),
            Flexible(child: StatusChip(status: r.status)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          isDoctor
              ? 'Pacient: ${r.patient?.displayName ?? '—'} · trimisă ${fmtDateTime(r.submittedAt)}'
              : (r.doctor == null
                  ? 'Cererea așteaptă alocarea unui medic · ${fmtDateTime(r.submittedAt)}'
                  : '${r.doctor!.displayName} · ${r.doctor!.specialty}'),
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        if (r.patientMessage != null && r.patientMessage!.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.accent1.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.chat_bubble_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(child: Text(r.patientMessage!, style: const TextStyle(height: 1.4))),
            ]),
          ),
        ],
      ],
    );
  }
}

class _ScanSection extends ConsumerWidget {
  final ReviewRequest request;
  const _ScanSection({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = request;
    final scan = r.scan!;
    final history = ref.watch(requestLesionScansProvider(r.id));
    final lp = scan.latestPrediction;
    return SectionCard(
      title: 'Fotografia evaluată',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(aspectRatio: 1, child: ProtectedImage(path: ReviewRepository.caseImagePath(r.id, scan.id))),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(fmtDateTime(scan.takenAt), style: const TextStyle(fontSize: 12, color: Colors.grey))),
              PredictionBadge(summary: lp),
            ],
          ),
          if (lp != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Analiză automată: ${PredictionClasses.labelsRo[lp.displayClassId]} (model ${lp.modelVersion}) — orientativă, nu un diagnostic.',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            ),
          if (!scan.quality.acceptable)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('Calitate: ${scan.quality.warningMessages.join(', ')}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange)),
            ),
          history.maybeWhen(
            data: (items) {
              final others = items.where((s) => s.id != scan.id).toList();
              if (others.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Istoricul leziunii', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 96,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: others.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) => Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: ProtectedImage(path: ReviewRepository.caseImagePath(r.id, others[i].id), width: 72, height: 72),
                            ),
                            const SizedBox(height: 4),
                            Text(fmtDate(others[i].takenAt), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _PatientSection extends StatelessWidget {
  final PatientRef patient;
  const _PatientSection({required this.patient});

  String _a(String? v) => v == null ? '—' : (ClinicalVocab.healthAnswers[v] ?? v);

  @override
  Widget build(BuildContext context) {
    final p = patient;
    return SectionCard(
      title: 'Pacient',
      child: Column(children: [
        InfoRow('Nume', p.displayName),
        InfoRow('Vârstă / sex', '${p.age?.toString() ?? '—'} / ${p.sex == null ? '—' : {'female': 'F', 'male': 'M', 'other': 'altul', 'prefer_not_to_say': 'nedeclarat'}[p.sex] ?? p.sex}'),
        InfoRow('Fototip', p.fitzpatrickType?.toString() ?? '—'),
        InfoRow('Melanom în antecedente', _a(p.historyMelanoma)),
        InfoRow('Alt cancer de piele', _a(p.historyOtherSkinCancer)),
        InfoRow('Istoric familial', _a(p.familyHistorySkinCancer)),
        InfoRow('Imunosupresie', _a(p.immunosuppression)),
        InfoRow('Expunere UV', p.uvExposure == null ? '—' : ({'low': 'scăzută', 'moderate': 'moderată', 'high': 'ridicată', 'unknown': 'nu știe', 'prefer_not_to_say': 'nedeclarat'}[p.uvExposure] ?? p.uvExposure!)),
      ]),
    );
  }
}

class _LesionSection extends StatelessWidget {
  final LesionRef lesion;
  const _LesionSection({required this.lesion});

  @override
  Widget build(BuildContext context) {
    final l = lesion;
    return SectionCard(
      title: 'Leziune',
      child: Column(children: [
        InfoRow('Localizare', l.locationLabel),
        if (l.firstNoticedOn != null) InfoRow('Observată', l.firstNoticedOn!),
        if (l.symptoms.isNotEmpty) InfoRow('Simptome', l.symptoms.map((s) => LesionVocab.symptoms[s] ?? s).join(', ')),
        if (l.notes != null && l.notes!.isNotEmpty) InfoRow('Note', l.notes!),
      ]),
    );
  }
}

class _Timeline extends StatelessWidget {
  final List<ReviewEvent> events;
  const _Timeline({required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) return const SizedBox.shrink();
    return SectionCard(
      title: 'Istoric',
      child: Column(
        children: [
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 10, height: 10,
                    margin: const EdgeInsets.only(top: 4, right: 10),
                    decoration: BoxDecoration(color: ReviewStatus.color(e.toStatus), shape: BoxShape.circle),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ReviewStatus.label(e.toStatus), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(fmtDateTime(e.occurredAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        if (e.note != null && !e.note!.startsWith('assessment v'))
                          Text(e.note!, style: const TextStyle(fontSize: 12, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DoctorActions extends StatelessWidget {
  final ReviewRequest request;
  final bool busy;
  final Future<void> Function(String action, ReviewRequest r) onAction;
  final VoidCallback onAssess;
  const _DoctorActions({required this.request, required this.busy, required this.onAction, required this.onAssess});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final buttons = <Widget>[];
    switch (r.status) {
      case ReviewStatus.pending:
        buttons.add(ElevatedButton.icon(
          onPressed: busy ? null : () => onAction('accept', r),
          icon: const Icon(Icons.check),
          label: const Text('Preia cazul'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ));
      case ReviewStatus.accepted:
        buttons.add(ElevatedButton.icon(
          onPressed: busy ? null : onAssess,
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Scrie evaluarea'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ));
        buttons.add(OutlinedButton.icon(
          onPressed: busy ? null : () => onAction('needs_info', r),
          icon: const Icon(Icons.help_outline),
          label: const Text('Cere informații'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ));
      case ReviewStatus.needsInfo:
        buttons.add(ElevatedButton.icon(
          onPressed: busy ? null : () => onAction('resume', r),
          icon: const Icon(Icons.play_arrow),
          label: const Text('Informații primite — continuă'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
        ));
        buttons.add(OutlinedButton.icon(
          onPressed: busy ? null : onAssess,
          icon: const Icon(Icons.assignment_turned_in_outlined),
          label: const Text('Scrie evaluarea oricum'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ));
    }
    if (r.isOpen) {
      buttons.add(TextButton.icon(
        onPressed: busy ? null : () => onAction('reject', r),
        icon: const Icon(Icons.block),
        label: const Text('Nu pot evalua acest caz'),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      ));
    }
    if (buttons.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final b in buttons) Padding(padding: const EdgeInsets.only(bottom: 10), child: b),
        if (busy) const LinearProgressIndicator(),
      ],
    );
  }
}

class _DisclaimerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(children: [
        Icon(Icons.info_outline, color: AppColors.accent3),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Evaluarea se bazează pe fotografii și nu înlocuiește un consult dermatologic. Dacă medicul a recomandat un consult, programează-l.',
            style: TextStyle(fontSize: 13, height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _ChatButton extends ConsumerWidget {
  final String requestId;
  final bool isDoctor;
  const _ChatButton({required this.requestId, required this.isDoctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadMessagesProvider).value?[requestId] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () async {
          await context.push('/review-requests/$requestId/chat');
          ref.invalidate(unreadMessagesProvider);
        },
        icon: Badge(isLabelVisible: unread > 0, label: Text('$unread'), child: const Icon(Icons.chat_bubble_outline)),
        label: Text(isDoctor ? 'Conversație cu pacientul' : 'Conversație cu medicul'),
        style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
      ),
    );
  }
}
