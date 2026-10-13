import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Coloured status pill.
class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = ReviewStatus.color(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(ReviewStatus.label(status),
          style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
    );
  }
}

/// One request in a list (patient or doctor view).
class RequestCard extends StatelessWidget {
  final ReviewRequest request;
  final bool doctorView;
  final VoidCallback onTap;
  const RequestCard({super.key, required this.request, required this.onTap, this.doctorView = false});

  @override
  Widget build(BuildContext context) {
    final r = request;
    final who = doctorView
        ? (r.patient?.displayName ?? 'Pacient')
        : (r.doctor?.displayName ?? 'Medic nealocat încă');
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(r.lesion.label,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 8),
                  StatusChip(status: r.status),
                ],
              ),
              const SizedBox(height: 4),
              Text(r.lesion.locationLabel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 6),
              Text('$who · ${fmtDateTime(r.submittedAt)}', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

/// Key/value row used in detail cards.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    // Label and value wrap independently; on narrow screens the value drops
    // below the label instead of overflowing.
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final stacked = c.maxWidth < 300;
          final labelText = Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey));
          final valueText = Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13));
          if (stacked) {
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [labelText, valueText]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 120, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

/// Titled card.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  const SectionCard({super.key, required this.title, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary))),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

/// Structured assessment rendered for both roles.
class AssessmentView extends StatelessWidget {
  final MedicalReview review;
  const AssessmentView({super.key, required this.review});

  @override
  Widget build(BuildContext context) {
    final m = review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoRow('Categorie suspectată', ClinicalVocab.suspectedCategories[m.suspectedCategory] ?? m.suspectedCategory),
        InfoRow('Certitudine', ClinicalVocab.certainties[m.certainty] ?? m.certainty),
        InfoRow('Recomandare', ClinicalVocab.recommendations[m.recommendation] ?? m.recommendation),
        InfoRow('Consult în persoană', m.inPersonConsultationAdvised ? 'Recomandat' : 'Nu este necesar acum'),
        InfoRow('Baza evaluării', ClinicalVocab.provenances[m.provenance] ?? m.provenance),
        if (m.confirmedDiagnosis != null) InfoRow('Diagnostic confirmat', m.confirmedDiagnosis!),
        const SizedBox(height: 8),
        const Text('Impresie clinică', style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(m.clinicalImpression, style: const TextStyle(height: 1.4)),
        if (m.additionalComments != null && m.additionalComments!.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('Comentarii', style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 2),
          Text(m.additionalComments!, style: const TextStyle(height: 1.4)),
        ],
        const SizedBox(height: 8),
        Text('Versiunea ${m.version} · ${fmtDateTime(m.createdAt)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}

String fmtDateTime(DateTime d) => DateFormat('d MMM yyyy, HH:mm', 'ro_RO').format(d);
String fmtDate(DateTime d) => DateFormat('d MMM yyyy', 'ro_RO').format(d);
