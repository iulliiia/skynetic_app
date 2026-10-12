import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/api/api.dart';
import 'package:skynetic_app/models/recommendation.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/models/scan_result.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/widgets/result_card.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

typedef ImagePredictor = Future<ScanResult> Function(XFile image);

class ScanResultScreen extends StatefulWidget {
  final XFile imageFile;

  /// Sends the image to the model. Defaults to the backend API; tests can
  /// pass a fake.
  final ImagePredictor? predictor;

  const ScanResultScreen({super.key, required this.imageFile, this.predictor});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _loading = false;
  ScanResult? _scanResult;
  String? _errorMessage;
  bool _consentGiven = false;

  Future<void> _getResult() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final predictor = widget.predictor ?? Api().predictImage;
      final result = await predictor(widget.imageFile);
      if (!mounted) return;
      setState(() {
        _scanResult = result;
      });
    } catch (err) {
      log(err.toString());
      if (!mounted) return;
      setState(() {
        _errorMessage = err is ApiException
            ? err.message
            : 'Ceva nu a funcționat. Încearcă din nou.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _openSaveScanDialog() {
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
      'Gât',
      'Piept',
      'Axilă',
      'Umăr',
      'Coapsă',
      'Gambă',
      'Cot',
      'Antebraț',
      'Încheietura mâinii',
      'Șold',
      'Genunchi',
      'Gleznă',
      'Zona inghinală',
      'Zona genitală',
      'Zona perianală',
    ];

    void showError(BuildContext context, String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              // Validări
              if (tagController.text.trim().isEmpty) {
                return showError(context, 'Eticheta unică este obligatorie');
              }
              if (selectedBodySide == null) {
                return showError(context, 'Selectează partea corpului');
              }
              if (selectedLateralSide == null) {
                return showError(context, 'Selectează lateralitatea');
              }
              if (selectedMainBodyPart == null) {
                return showError(context, 'Selectează regiunea anatomică');
              }

              final String fullBodyPart = selectedSubBodyPart != null
                  ? '$selectedMainBodyPart - $selectedSubBodyPart'
                  : selectedMainBodyPart!;
              final locationLabel =
                  '$selectedBodySide - $selectedLateralSide - $fullBodyPart';

              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              setDialogState(() => saving = true);

              try {
                final imagePath =
                    await SavedScans.persistImage(widget.imageFile.path);
                await SavedScans.save(SavedScan(
                  imagePath: imagePath,
                  classId: _scanResult!.classId,
                  locationLabel: locationLabel,
                  uniqueTag: tagController.text.trim(),
                  bodySide: selectedBodySide!,
                  lateralSide: selectedLateralSide!,
                  bodyPart: selectedMainBodyPart!,
                  subBodyPart: selectedSubBodyPart,
                  notes: notesController.text.trim().isEmpty
                      ? null
                      : notesController.text.trim(),
                  scanDate: DateTime.now(),
                ));
              } catch (err) {
                log(err.toString());
                setDialogState(() => saving = false);
                messenger.showSnackBar(const SnackBar(
                    content: Text('Scanarea nu a putut fi salvată.')));
                return;
              }

              messenger.showSnackBar(const SnackBar(
                  content: Text('Scanarea a fost salvată în arhivă.')));
              navigator.pop(); // Închide dialog
              if (mounted) navigator.pop(); // Închide ecran
            }

            return AlertDialog(
              scrollable: true,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Text(
                'Salvează scanarea',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Etichetă
                    TextFormField(
                      controller: tagController,
                      decoration: const InputDecoration(
                        labelText: 'Etichetă unică *',
                        hintText: 'Ex: Semn spate, Aluniță braț',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Partea corpului
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Partea corpului *',
                        prefixIcon: Icon(Icons.accessibility_new),
                      ),
                      initialValue: selectedBodySide,
                      isExpanded: true,
                      items: bodySideOptions.map((side) {
                        return DropdownMenuItem(
                          value: side,
                          child: Text(side, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedBodySide = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Lateralitate
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Lateralitate *',
                        prefixIcon: Icon(Icons.compare_arrows),
                      ),
                      initialValue: selectedLateralSide,
                      isExpanded: true,
                      items: lateralSideOptions.map((side) {
                        return DropdownMenuItem(
                          value: side,
                          child: Text(side, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedLateralSide = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),

                    // Regiune principală
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'Regiunea anatomică *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      initialValue: selectedMainBodyPart,
                      isExpanded: true,
                      items: mainBodyParts.map((part) {
                        return DropdownMenuItem(
                          value: part,
                          child: Text(part, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedMainBodyPart = value;
                          selectedSubBodyPart = null;
                        });
                      },
                    ),

                    // Regiune secundară (dacă e cazul)
                    if (selectedMainBodyPart != null &&
                        bodyPartsHierarchy
                            .containsKey(selectedMainBodyPart!)) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        // a new key resets the field when the region changes
                        key: ValueKey(selectedMainBodyPart),
                        decoration: const InputDecoration(
                          labelText: 'Detaliu regiune',
                          prefixIcon: Icon(Icons.segment),
                        ),
                        initialValue: selectedSubBodyPart,
                        isExpanded: true,
                        items: bodyPartsHierarchy[selectedMainBodyPart!]!
                            .map((subPart) {
                          return DropdownMenuItem(
                            value: subPart,
                            child:
                                Text(subPart, overflow: TextOverflow.ellipsis),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedSubBodyPart = value;
                          });
                        },
                      ),
                    ],
                    const SizedBox(height: 16),

                    // Note
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
                    const Text(
                      '* Câmpuri obligatorii',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 16),
                    // The buttons scroll with the form (instead of being
                    // dialog actions) so they stay reachable when the
                    // keyboard leaves little room, e.g. in landscape.
                    Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        TextButton(
                          onPressed:
                              saving ? null : () => Navigator.of(context).pop(),
                          child: const Text('Anulează'),
                        ),
                        ElevatedButton(
                          onPressed: saving ? null : save,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                          child: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
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

  Color getColorForClassConfidence(int classId, double confidence) {
    final clampedConfidence = confidence.clamp(0.0, 1.0);
    switch (classId) {
      case 0:
        return Color.lerp(Colors.yellow, const Color.fromARGB(211, 0, 176, 18),
            clampedConfidence)!;
      case 1:
        return Color.lerp(Colors.orange, const Color.fromARGB(255, 198, 36, 36),
            clampedConfidence)!;
      case 2:
        return Color.lerp(Colors.grey.shade300,
            const Color.fromARGB(255, 58, 189, 176), clampedConfidence)!;
      default:
        return Colors.grey;
    }
  }

  Widget _buildBody() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Se analizează imaginea...', textAlign: TextAlign.center),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Column(
        children: [
          const Icon(Icons.cloud_off, size: 48, color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _getResult,
            icon: const Icon(Icons.refresh),
            label: const Text('Reîncearcă'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 56),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Alege altă imagine'),
          ),
        ],
      );
    }

    if (_scanResult != null) {
      return Column(
        children: [
          ResultCard(
            title: classes[_scanResult!.classId] ?? 'Rezultat necunoscut',
            subtitle: Recommendations().get(_scanResult!.classId),
            icon: '🩺',
            color: getColorForClassConfidence(
              _scanResult!.classId,
              _scanResult!.confidence,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Încredere model: ${(_scanResult!.confidence * 100).toStringAsFixed(0)}%',
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _openSaveScanDialog,
            icon: const Icon(Icons.save_alt),
            label: const Text('Salvează rezultatul'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Scanează altă imagine'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(double.infinity, 48),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        SvgPicture.asset(
          'assets/images/info.svg',
          height: 60,
        ),
        const SizedBox(height: 12),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
                    onChanged: (value) {
                      setState(() {
                        _consentGiven = value ?? false;
                      });
                    },
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
          onPressed: _consentGiven ? _getResult : null,
          icon: const Icon(Icons.analytics_outlined),
          label: const Text('Obține rezultatul'),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.refresh),
          label: const Text('Reîncarcă / Refă poză'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 56),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

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
                    child: KeyedSubtree(
                      key: ValueKey(
                          '$_loading-$_errorMessage-${_scanResult != null}'),
                      child: _buildBody(),
                    ),
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
