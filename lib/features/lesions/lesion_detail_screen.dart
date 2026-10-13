import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/features/lesions/prediction_models.dart';
import 'package:skynetic_app/features/review/request_review_sheet.dart';
import 'package:skynetic_app/features/scans/authenticated_image.dart';
import 'package:skynetic_app/features/scans/image_picking.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';

/// One lesion: details, actions and the chronological scan history.
class LesionDetailScreen extends ConsumerWidget {
  final String lesionId;
  const LesionDetailScreen({super.key, required this.lesionId});

  Future<void> _addScan(BuildContext context, WidgetRef ref) async {
    final file = await pickImageWithSourceSheet(context);
    if (file == null || !context.mounted) return;
    await context.push('/scan/result', extra: ScanResultArgs(file, lesionId: lesionId));
    if (context.mounted) invalidateLesionData(ref);
  }

  Future<void> _toggleArchive(BuildContext context, WidgetRef ref, Lesion lesion) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lesionRepositoryProvider).updateLesion(lesion.id, {'archived': !lesion.isArchived});
      invalidateLesionData(ref);
      messenger.showSnackBar(SnackBar(
          content: Text(lesion.isArchived ? 'Leziunea a fost reactivată.' : 'Leziunea a fost arhivată.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesion = ref.watch(lesionProvider(lesionId));
    final scans = ref.watch(lesionScansProvider(lesionId));

    return Scaffold(
      appBar: AppBar(
        title: Text(lesion.value?.label ?? 'Leziune', overflow: TextOverflow.ellipsis),
        actions: [
          if (lesion.hasValue) ...[
            IconButton(
              tooltip: 'Editează',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                await context.push('/lesions/$lesionId/edit');
                if (context.mounted) invalidateLesionData(ref);
              },
            ),
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'archive') _toggleArchive(context, ref, lesion.value!);
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'archive',
                  child: Text(lesion.value!.isArchived ? 'Reactivează leziunea' : 'Arhivează leziunea'),
                ),
              ],
            ),
          ],
        ],
      ),
      floatingActionButton: lesion.hasValue && !lesion.value!.isArchived
          ? FloatingActionButton.extended(
              onPressed: () => _addScan(context, ref),
              backgroundColor: AppColors.accent2,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Adaugă o scanare'),
            )
          : null,
      body: lesion.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(e.toString(), textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton(onPressed: () => invalidateLesionData(ref), child: const Text('Reîncearcă')),
              ],
            ),
          ),
        ),
        data: (l) => RefreshIndicator(
          onRefresh: () async {
            invalidateLesionData(ref);
            await ref.read(lesionScansProvider(lesionId).future);
          },
          child: ResponsiveCenter(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              children: [
                _InfoCard(lesion: l),
                const SizedBox(height: 24),
                Row(
                  children: [
                    const Expanded(
                      child: Text('Istoricul scanărilor',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                    ),
                    Text('${l.scanCount}', style: const TextStyle(color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                scans.when(
                  loading: () => const Padding(
                      padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                  error: (e, _) => Text(e.toString(), style: const TextStyle(color: Colors.red)),
                  data: (items) => items.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.accent1.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Text(
                            'Nicio scanare încă. Fotografiază leziunea în condiții de lumină bună și repetă la câteva săptămâni pentru a observa schimbările.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                          ),
                        )
                      : GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 200,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            mainAxisExtent: 150 + MediaQuery.textScalerOf(context).scale(1) * 56,
                          ),
                          itemCount: items.length,
                          itemBuilder: (_, i) => _ScanTile(
                            scan: items[i],
                            onTap: () => _showScan(context, ref, items[i], l),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showScan(BuildContext context, WidgetRef ref, Scan scan, Lesion lesion) {
    showDialog(
      context: context,
      builder: (ctx) => _ScanDialog(scan: scan, lesion: lesion),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final Lesion lesion;
  const _InfoCard({required this.lesion});

  @override
  Widget build(BuildContext context) {
    final rows = <(IconData, String, String)>[
      (Icons.place_outlined, 'Localizare', lesion.locationLabel),
      if (lesion.firstNoticedOn != null)
        (Icons.event_outlined, 'Observată', _fmtDate(DateTime.tryParse(lesion.firstNoticedOn!))),
      if (lesion.symptoms.isNotEmpty)
        (Icons.healing_outlined, 'Simptome',
            lesion.symptoms.map((s) => LesionVocab.symptoms[s] ?? s).join(', ')),
      if (lesion.notes != null && lesion.notes!.isNotEmpty) (Icons.note_outlined, 'Note', lesion.notes!),
    ];
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (lesion.isArchived)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(999)),
                child: const Text('Arhivată', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(r.$1, size: 20, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(r.$2, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          Text(r.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
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

class _ScanTile extends StatelessWidget {
  final Scan scan;
  final VoidCallback onTap;
  const _ScanTile({required this.scan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: scan.quality.acceptable ? BorderSide.none : const BorderSide(color: Colors.orange, width: 2),
      ),
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: AuthenticatedScanImage(scanId: scan.id)),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_fmtDate(scan.takenAt),
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      if (!scan.quality.acceptable)
                        const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 2),
                  PredictionBadge(summary: scan.latestPrediction),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScanDialog extends ConsumerStatefulWidget {
  final Scan scan;
  final Lesion lesion;
  const _ScanDialog({required this.scan, required this.lesion});

  @override
  ConsumerState<_ScanDialog> createState() => _ScanDialogState();
}

class _ScanDialogState extends ConsumerState<_ScanDialog> {
  bool _deleting = false;
  bool _analyzing = false;
  Prediction? _fresh;

  Future<void> _analyze() async {
    setState(() => _analyzing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final p = await ref.read(lesionRepositoryProvider).analyzeScan(widget.scan.id);
      invalidateLesionData(ref);
      if (mounted) setState(() => _fresh = p);
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Analiza nu a reușit. Încearcă din nou.')));
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Șterge scanarea'),
        content: const Text('Fotografia va fi ștearsă definitiv. Continui?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Anulează')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await ref.read(lesionRepositoryProvider).deleteScan(widget.scan.id);
      invalidateLesionData(ref);
      messenger.showSnackBar(const SnackBar(content: Text('Scanarea a fost ștearsă.')));
      navigator.pop();
    } on ApiException catch (e) {
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      setState(() => _deleting = false);
      messenger.showSnackBar(const SnackBar(content: Text('Scanarea nu a putut fi ștearsă.')));
    }
  }

  Future<void> _requestReview() async {
    final navigator = Navigator.of(context);
    final rq = await showRequestReviewSheet(context, scan: widget.scan, lesion: widget.lesion);
    if (rq == null || !mounted) return;
    navigator.pop();
    context.push('/review-requests/${rq.id}');
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scan;
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(aspectRatio: 1, child: AuthenticatedScanImage(scanId: s.id)),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('d MMMM yyyy, HH:mm', 'ro_RO').format(s.takenAt),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (s.width != null) Text('${s.width}×${s.height} px', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(height: 10),
                    _PredictionLine(summary: s.latestPrediction, fresh: _fresh, analyzing: _analyzing, onAnalyze: _analyze),
                    if (s.patientNotes != null) ...[const SizedBox(height: 8), Text(s.patientNotes!)],
                    if (!s.quality.acceptable) ...[
                      const SizedBox(height: 12),
                      for (final w in s.quality.warningMessages)
                        Row(children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(child: Text(w, style: const TextStyle(color: Colors.orange))),
                        ]),
                    ],
                    const SizedBox(height: 16),
                    if (!widget.lesion.isArchived)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _deleting ? null : _requestReview,
                          icon: const Icon(Icons.medical_services_outlined),
                          // short enough for a 320 px dialog at large text sizes
                          label: const Text('Evaluare medicală', maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    const SizedBox(height: 8),
                    // Wrap: the two buttons stack on a 320 px screen.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: _deleting ? null : _delete,
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          icon: _deleting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.delete_outline),
                          label: const Text('Șterge'),
                        ),
                        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Închide')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _fmtDate(DateTime? d) => d == null ? '—' : DateFormat('d MMM yyyy', 'ro_RO').format(d);

/// Small coloured label with the latest AI result (or "Neanalizat").
class PredictionBadge extends StatelessWidget {
  final PredictionSummary? summary;
  const PredictionBadge({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final color = s == null ? Colors.grey : PredictionClasses.color(s.displayClassId);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(
        s == null ? 'Neanalizat' : s.shortLabelRo,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _PredictionLine extends StatelessWidget {
  final PredictionSummary? summary;
  final Prediction? fresh;
  final bool analyzing;
  final VoidCallback onAnalyze;
  const _PredictionLine({required this.summary, required this.fresh, required this.analyzing, required this.onAnalyze});

  @override
  Widget build(BuildContext context) {
    final classId = fresh?.displayClassId ?? summary?.displayClassId;
    final version = fresh?.modelVersion ?? summary?.modelVersion;
    if (classId == null) {
      return Row(
        children: [
          const Expanded(child: Text('Fără analiză AI', style: TextStyle(color: Colors.grey))),
          TextButton.icon(
            onPressed: analyzing ? null : onAnalyze,
            icon: analyzing
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.analytics_outlined, size: 18),
            label: const Text('Analizează'),
          ),
        ],
      );
    }
    final color = PredictionClasses.color(classId);
    return Row(
      children: [
        Icon(Icons.analytics_outlined, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${PredictionClasses.labelsRo[classId]} · model $version · orientativ',
            style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
