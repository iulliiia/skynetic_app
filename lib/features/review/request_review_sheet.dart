import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Explains what will be shared with the doctor, takes an optional message
/// and files the request. Returns the created request or null.
Future<ReviewRequest?> showRequestReviewSheet(BuildContext context, {required Scan scan, required Lesion lesion}) {
  return showModalBottomSheet<ReviewRequest>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _RequestReviewSheet(scan: scan, lesion: lesion),
  );
}

class _RequestReviewSheet extends ConsumerStatefulWidget {
  final Scan scan;
  final Lesion lesion;
  const _RequestReviewSheet({required this.scan, required this.lesion});

  @override
  ConsumerState<_RequestReviewSheet> createState() => _RequestReviewSheetState();
}

class _RequestReviewSheetState extends ConsumerState<_RequestReviewSheet> {
  final _message = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = _message.text.trim();
      final rq = await ref.read(reviewRepositoryProvider).createRequest(widget.scan.id, message: msg.isEmpty ? null : msg);
      invalidateReviewData(ref);
      if (mounted) Navigator.of(context).pop(rq);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'Cererea nu a putut fi trimisă. Încearcă din nou.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Solicită evaluare medicală',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primary)),
            const SizedBox(height: 8),
            const Text(
              'Cererea este trimisă unui medic dermatolog verificat. Vei fi notificat când o preia și când evaluarea este gata.',
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.accent2.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ce vede medicul', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.accent3)),
                  SizedBox(height: 6),
                  Text('• această fotografie și celelalte fotografii ale aceleiași leziuni\n'
                      '• rezultatul analizei automate\n'
                      '• detaliile leziunii (localizare, simptome, note)\n'
                      '• numele tău, vârsta, fototipul și factorii de risc din profil',
                      style: TextStyle(fontSize: 13, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text('Leziune: ${widget.lesion.label} · ${widget.lesion.locationLabel}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 3,
              maxLength: 2000,
              decoration: const InputDecoration(
                labelText: 'Mesaj pentru medic (opțional)',
                hintText: 'Ex: a crescut în ultimele luni și mă mâncărime',
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _busy ? null : _submit,
              icon: _busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send),
              label: const Text('Trimite cererea'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Anulează')),
          ],
        ),
      ),
    );
  }
}
