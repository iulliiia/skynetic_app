import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/lesions/lesion_picker.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/models/scan_result.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

/// Lets a freshly signed-in patient attach the scans made as a guest to a
/// lesion of their account. Each row corresponds to a local [SavedScan]
/// whose server-side guest session is still claimable.
class ClaimScreen extends ConsumerStatefulWidget {
  const ClaimScreen({super.key});

  @override
  ConsumerState<ClaimScreen> createState() => _ClaimScreenState();
}

class _ClaimScreenState extends ConsumerState<ClaimScreen> {
  List<SavedScan> _pending = [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SavedScans.load();
    if (!mounted) return;
    setState(() {
      _pending = SavedScans.claimable;
      _loading = false;
    });
  }

  Future<void> _claim(SavedScan scan) async {
    final lesion = await showLesionPicker(context);
    if (lesion == null || !mounted) return;
    setState(() => _busyId = scan.remoteScanId);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lesionRepositoryProvider).claimGuestScan(
            scanId: scan.remoteScanId!,
            claimToken: scan.claimToken!,
            lesionId: lesion.id,
          );
      await SavedScans.update(scan, scan.copyWith(claimedAt: DateTime.now()));
      invalidateLesionData(ref);
      messenger.showSnackBar(SnackBar(content: Text('Scanarea a fost adăugată la „${lesion.label}”.')));
    } on ApiException catch (e) {
      if (e.code == 'claim_invalid') {
        // Expired or already claimed elsewhere: stop offering it.
        await SavedScans.update(scan, scan.copyWith(clearClaim: true));
      }
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Asocierea nu a reușit. Încearcă din nou.')));
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        await _load();
      }
    }
  }

  Future<void> _dismiss(SavedScan scan) async {
    await SavedScans.update(scan, scan.copyWith(clearClaim: true));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Asociază scanările')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveCenter(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Fotografiile analizate înainte de crearea contului pot fi adăugate la leziunile tale, ca să le urmărești evoluția și să ceri evaluarea unui medic.',
                      style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    if (_pending.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.check_circle_outline, size: 56, color: AppColors.accent1.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text('Nu ai scanări de asociat.', style: TextStyle(color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                    for (final s in _pending) _PendingRow(
                      scan: s,
                      busy: _busyId == s.remoteScanId,
                      onClaim: () => _claim(s),
                      onDismiss: () => _dismiss(s),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _PendingRow extends StatelessWidget {
  final SavedScan scan;
  final bool busy;
  final VoidCallback onClaim;
  final VoidCallback onDismiss;
  const _PendingRow({required this.scan, required this.busy, required this.onClaim, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ScanImage(path: scan.imagePath, width: 64, height: 64),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(scan.uniqueTag, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(scan.locationLabel, style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 2, overflow: TextOverflow.ellipsis),
                      Text(
                        '${DateFormat('d MMM yyyy', 'ro_RO').format(scan.scanDate)} · ${classes[scan.classId] ?? ''}',
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                TextButton(onPressed: busy ? null : onDismiss, child: const Text('Ignoră')),
                FilledButton.icon(
                  onPressed: busy ? null : onClaim,
                  style: FilledButton.styleFrom(backgroundColor: AppColors.accent2),
                  icon: busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.link),
                  label: const Text('Asociază'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
