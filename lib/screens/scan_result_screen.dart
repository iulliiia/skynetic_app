import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/lesion_picker.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/features/lesions/prediction_models.dart';
import 'package:skynetic_app/models/recommendation.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/widgets/result_card.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

/// Preview → consent → upload → AI analysis → result.
///
/// The photo is stored on the platform first (a patient picks the lesion it
/// belongs to; a guest gets a temporary scan with a claim token) and the
/// analysis runs server-side on the stored scan, so every result is tied to
/// a scan record and a model version.
class ScanResultScreen extends ConsumerStatefulWidget {
  final XFile imageFile;

  /// Preselected lesion (when started from a lesion's detail screen).
  final String? lesionId;

  const ScanResultScreen({super.key, required this.imageFile, this.lesionId});

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

enum _Stage { consent, uploading, analyzing, done, error }

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  _Stage _stage = _Stage.consent;
  bool _consentGiven = false;
  String? _errorMessage;

  String? _lesionId; // patient
  Scan? _scan; // patient upload
  GuestScan? _guest; // guest upload
  Prediction? _prediction;

  bool get _isPatient => ref.read(authControllerProvider).isPatient;
  bool get _uploaded => _scan != null || _guest != null;
  ScanQuality? get _quality => _scan?.quality ?? _guest?.quality;

  Future<void> _start() async {
    final repo = ref.read(lesionRepositoryProvider);
    try {
      if (!_uploaded) {
        if (_isPatient) {
          final lesionId = widget.lesionId ?? _lesionId ?? (await showLesionPicker(context))?.id;
          if (lesionId == null || !mounted) return;
          _lesionId = lesionId;
          setState(() => _stage = _Stage.uploading);
          final scan = await repo.uploadScan(lesionId, widget.imageFile);
          if (!mounted) return;
          invalidateLesionData(ref);
          if (!scan.quality.acceptable) {
            final keep = await _confirmKeepPoorQuality(scan.quality) ?? true;
            if (!mounted) return;
            if (!keep) {
              try {
                await repo.deleteScan(scan.id);
                invalidateLesionData(ref);
              } catch (_) {}
              if (mounted) context.pop(); // retake
              return;
            }
          }
          _scan = scan;
        } else {
          setState(() => _stage = _Stage.uploading);
          _guest = await repo.uploadGuestScan(widget.imageFile);
        }
      }
      if (!mounted) return;
      setState(() => _stage = _Stage.analyzing);
      final prediction = _scan != null
          ? await repo.analyzeScan(_scan!.id)
          : await repo.analyzeGuestScan(_guest!.scanId, _guest!.claimToken);
      if (!mounted) return;
      invalidateLesionData(ref);
      setState(() {
        _prediction = prediction;
        _stage = _Stage.done;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _stage = _Stage.error;
      });
    } catch (e) {
      log(e.toString());
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Ceva nu a funcționat. Încearcă din nou.';
        _stage = _Stage.error;
      });
    }
  }

  Future<bool?> _confirmKeepPoorQuality(ScanQuality q) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Calitatea imaginii'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final w in q.warningMessages)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  Expanded(child: Text(w)),
                ]),
              ),
            const SizedBox(height: 8),
            const Text('O fotografie clară, făcută la lumină naturală, ajută atât analiza automată cât și medicul.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Refă poza')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Analizează oricum')),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ guest save

  /// Keeps the result on the device, linked to the server-side guest scan so
  /// it can be attached to an account later.
  void _openGuestSaveDialog() {
    final TextEditingController tagController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    String? selectedBodySide;
    String? selectedLateralSide;
    String? selectedMainBodyPart;
    String? selectedSubBodyPart;
    bool saving = false;

    final bodySideOptions = ['Anterior', 'Posterior'];
    final lateralSideOptions = ['Stânga', 'Dreapta', 'Centru'];

    final Map<String, List<String>> bodyPartsHierarchy = {
      'Cap': ['Scalp', 'Frunte', 'Tâmple'],
      'Față': ['Obraz', 'Nas', 'Bărbie'],
      'Abdomen': ['Superior', 'Inferior'],
      'Spate': ['Superior', 'Mijloc', 'Inferior'],
      'Braț': ['Superior', 'Inferior'],
      'Mână': ['Palmă', 'Dosul mâinii', 'Degete mână'],
      'Picior': ['Talpă', 'Dosul piciorului', 'Degete picior'],
    };

    final List<String> mainBodyParts = [
      ...bodyPartsHierarchy.keys,
      'Gât', 'Piept', 'Axilă', 'Umăr', 'Coapsă', 'Gambă', 'Cot', 'Antebraț', 'Încheietura mâinii',
      'Șold', 'Genunchi', 'Gleznă', 'Zona inghinală', 'Zona genitală', 'Zona perianală',
    ];

    void showError(BuildContext context, String message) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              if (tagController.text.trim().isEmpty) return showError(context, 'Eticheta unică este obligatorie');
              if (selectedBodySide == null) return showError(context, 'Selectează partea corpului');
              if (selectedLateralSide == null) return showError(context, 'Selectează lateralitatea');
              if (selectedMainBodyPart == null) return showError(context, 'Selectează regiunea anatomică');

              final String fullBodyPart = selectedSubBodyPart != null
                  ? '$selectedMainBodyPart - $selectedSubBodyPart'
                  : selectedMainBodyPart!;
              final locationLabel = '$selectedBodySide - $selectedLateralSide - $fullBodyPart';

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              setDialogState(() => saving = true);
              try {
                final imagePath = await SavedScans.persistImage(widget.imageFile.path);
                await SavedScans.save(SavedScan(
                  imagePath: imagePath,
                  classId: _prediction!.displayClassId,
                  locationLabel: locationLabel,
                  uniqueTag: tagController.text.trim(),
                  bodySide: selectedBodySide!,
                  lateralSide: selectedLateralSide!,
                  bodyPart: selectedMainBodyPart!,
                  subBodyPart: selectedSubBodyPart,
                  notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                  scanDate: DateTime.now(),
                  remoteScanId: _guest?.scanId,
                  claimToken: _guest?.claimToken,
                  claimExpiresAt: _guest?.expiresAt,
                ));
              } catch (err) {
                log(err.toString());
                setDialogState(() => saving = false);
                messenger.showSnackBar(const SnackBar(content: Text('Scanarea nu a putut fi salvată.')));
                return;
              }
              messenger.showSnackBar(const SnackBar(
                  content: Text('Scanarea a fost salvată. O poți adăuga la un cont în următoarele 24 de ore.')));
              navigator.pop(); // Închide dialog
              if (mounted) navigator.pop(); // Închide ecran
            }

            return AlertDialog(
              scrollable: true,
              insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Salvează scanarea', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Etichetă unică *',
                        hintText: 'Ex: Semn spate, Aluniță braț',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Partea corpului *', prefixIcon: Icon(Icons.accessibility_new)),
                      initialValue: selectedBodySide,
                      isExpanded: true,
                      items: bodySideOptions
                          .map((side) => DropdownMenuItem(value: side, child: Text(side, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedBodySide = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Lateralitate *', prefixIcon: Icon(Icons.compare_arrows)),
                      initialValue: selectedLateralSide,
                      isExpanded: true,
                      items: lateralSideOptions
                          .map((side) => DropdownMenuItem(value: side, child: Text(side, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) => setDialogState(() => selectedLateralSide = value),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Regiunea anatomică *', prefixIcon: Icon(Icons.person_outline)),
                      initialValue: selectedMainBodyPart,
                      isExpanded: true,
                      items: mainBodyParts
                          .map((part) => DropdownMenuItem(value: part, child: Text(part, overflow: TextOverflow.ellipsis)))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        selectedMainBodyPart = value;
                        selectedSubBodyPart = null;
                      }),
                    ),
                    if (selectedMainBodyPart != null && bodyPartsHierarchy.containsKey(selectedMainBodyPart!)) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        key: ValueKey(selectedMainBodyPart),
                        decoration: const InputDecoration(labelText: 'Detaliu regiune', prefixIcon: Icon(Icons.segment)),
                        initialValue: selectedSubBodyPart,
                        isExpanded: true,
                        items: bodyPartsHierarchy[selectedMainBodyPart!]!
                            .map((sub) => DropdownMenuItem(value: sub, child: Text(sub, overflow: TextOverflow.ellipsis)))
                            .toList(),
                        onChanged: (value) => setDialogState(() => selectedSubBodyPart = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: notesController,
                      decoration: const InputDecoration(
                        labelText: 'Note adiționale (opțional)',
                        hintText: 'Ex: leziune mai mare decât luna trecută',
                        prefixIcon: Icon(Icons.note_outlined),
                      ),
                      maxLines: 2,
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text('* Câmpuri obligatorii',
                        style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 16),
                    // Buttons scroll with the form so they stay reachable with
                    // the keyboard open on small/landscape screens.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed: saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Anulează'),
                        ),
                        ElevatedButton(
                          onPressed: saving ? null : save,
                          style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20)),
                          child: saving
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Salvează'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ------------------------------------------------------------------- UI

  Widget _buildBody(AuthState auth) {
    switch (_stage) {
      case _Stage.uploading:
      case _Stage.analyzing:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(_stage == _Stage.uploading ? 'Se încarcă imaginea...' : 'Se analizează imaginea...',
                  textAlign: TextAlign.center),
            ],
          ),
        );
      case _Stage.error:
        return _buildError();
      case _Stage.done:
        return _buildResult();
      case _Stage.consent:
        return _buildConsent(auth);
    }
  }

  Widget _buildError() {
    return Column(
      children: [
        const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
        const SizedBox(height: 12),
        Text(_errorMessage ?? '', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.refresh),
          label: Text(_uploaded ? 'Reîncearcă analiza' : 'Reîncearcă'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
        ),
        const SizedBox(height: 12),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Alege altă imagine')),
      ],
    );
  }

  Widget _buildResult() {
    final p = _prediction!;
    final classId = p.displayClassId;
    final color = _colorFor(p);
    final auth = ref.watch(authControllerProvider);
    final quality = _quality;

    return Column(
      children: [
        ResultCard(
          title: PredictionClasses.labelsRo[classId] ?? 'Rezultat necunoscut',
          subtitle: Recommendations().get(classId),
          icon: p.isInconclusive ? '🤔' : '🩺',
          color: color,
        ),
        const SizedBox(height: 8),
        Text(
          [
            if (p.topScore != null) 'scor model ${(p.topScore! * 100).toStringAsFixed(0)}%',
            'model ${p.modelName}/${p.modelVersion}',
            'rezultat orientativ, nu un diagnostic',
          ].join(' · '),
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        if (quality != null && !quality.acceptable) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final w in quality.warningMessages)
                Chip(
                  avatar: const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                  label: Text(w, style: const TextStyle(fontSize: 12)),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        if (auth.isPatient)
          ElevatedButton.icon(
            onPressed: () {
              if (widget.lesionId != null) {
                context.pop();
              } else {
                context.go('/');
                context.push('/lesions/$_lesionId');
              }
            },
            icon: const Icon(Icons.folder_open),
            label: const Text('Vezi leziunea'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          )
        else
          ElevatedButton.icon(
            onPressed: _openGuestSaveDialog,
            icon: const Icon(Icons.save_alt),
            label: const Text('Salvează rezultatul'),
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
          ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.camera_alt_outlined),
          label: const Text('Scanează altă imagine'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
        ),
        if (!auth.isAuthenticated) ...[
          const SizedBox(height: 20),
          _AccountNudge(onTap: () => context.push('/register')),
        ],
      ],
    );
  }

  Color _colorFor(Prediction p) {
    if (p.isInconclusive) return Colors.blueGrey.shade300;
    final confidence = (p.topScore ?? 0).clamp(0.0, 1.0);
    switch (p.predictedClass) {
      case 0:
        return Color.lerp(Colors.yellow, const Color.fromARGB(211, 0, 176, 18), confidence)!;
      case 1:
        return Color.lerp(Colors.orange, const Color.fromARGB(255, 198, 36, 36), confidence)!;
      case 2:
        return Color.lerp(Colors.grey.shade300, const Color.fromARGB(255, 58, 189, 176), confidence)!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildConsent(AuthState auth) {
    return Column(
      children: [
        SvgPicture.asset('assets/images/info.svg', height: 60),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          color: Colors.blue.shade50,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _consentGiven = !_consentGiven),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: _consentGiven,
                    onChanged: (value) => setState(() => _consentGiven = value ?? false),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Confirm că am înțeles și sunt de acord cu faptul că această aplicație are un scop exclusiv informativ și educativ, fără a oferi un diagnostic medical validat clinic. '
                      'În cazul oricărei suspiciuni legate de sănătatea pielii, mă angajez să consult un medic specialist.',
                      style: TextStyle(fontSize: 14, height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          // Wait for the session to be restored so a patient is never
          // treated as a guest.
          onPressed: _consentGiven && !auth.isLoading ? _start : null,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Obține rezultatul'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Reîncarcă / Refă poză'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    // Watching here keeps the session provider alive from the first frame.
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Previzualizare scanare')),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                // a square-ish preview that never takes more than a third
                // of short (landscape) screens
                height: (screenHeight * 0.4).clamp(160.0, 420.0),
                width: double.infinity,
                child: ScanImage(path: widget.imageFile.path),
              ),
              ResponsiveCenter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(key: ValueKey(_stage), child: _buildBody(auth)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccountNudge extends StatelessWidget {
  final VoidCallback onTap;
  const _AccountNudge({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent2.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Vrei părerea unui medic?', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
          const SizedBox(height: 6),
          const Text(
            'Cu un cont poți urmări evoluția leziunii în timp și poți trimite fotografia unui medic dermatolog pentru evaluare.',
            style: TextStyle(fontSize: 13, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const Text('Creează un cont'),
            ),
          ),
        ],
      ),
    );
  }
}
