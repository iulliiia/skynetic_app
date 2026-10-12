import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/api/api.dart';
import 'package:skynetic_app/models/recommendation.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/models/scan_result.dart';
import 'package:skynetic_app/widgets/result_card.dart';

class ScanResultScreen extends StatefulWidget {
  final XFile imageFile;

  const ScanResultScreen({super.key, required this.imageFile});

  @override
  State<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends State<ScanResultScreen> {
  bool _loading = false;
  ScanResult? _scanResult;
  bool _error = false;
  bool _showResult = false;
  bool _consentGiven = false;

  void _getResult() async {
    setState(() {
      _loading = true;
    });

    try {
      final result = await Api().predictImage(widget.imageFile);
      setState(() {
        _scanResult = result;
        _showResult = true;
      });
    } catch (err) {
      log(err.toString());
      setState(() {
        _error = true;
      });
    }

    setState(() {
      _loading = false;
    });
  }

  void _openSaveScanDialog() {
    final TextEditingController tagController = TextEditingController();
    final TextEditingController notesController = TextEditingController();

    String? selectedBodySide;
    String? selectedLateralSide;
    String? selectedMainBodyPart;
    String? selectedSubBodyPart;

    final bodySideOptions = ['Anterior', 'Posterior '];
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

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          contentPadding: const EdgeInsets.all(20),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text(
            'Salvează scanarea',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SizedBox(
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: Column(
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
                        items: bodySideOptions.map((side) {
                          return DropdownMenuItem(
                            value: side,
                            child: Text(side),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
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
                        items: lateralSideOptions.map((side) {
                          return DropdownMenuItem(
                            value: side,
                            child: Text(side),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
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
                            child: Text(part),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedMainBodyPart = value;
                            selectedSubBodyPart = null;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Regiune secundară (dacă e cazul)
                      if (selectedMainBodyPart != null &&
                          bodyPartsHierarchy.containsKey(selectedMainBodyPart!))
                        DropdownButtonFormField<String>(
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
                              child: Text(subPart),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedSubBodyPart = value;
                            });
                          },
                        ),
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
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Anulează'),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validări
                if (tagController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Eticheta unică este obligatorie')),
                  );
                  return;
                }

                if (selectedBodySide == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selectează partea corpului')),
                  );
                  return;
                }

                if (selectedLateralSide == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Selectează lateralitatea')),
                  );
                  return;
                }

                if (selectedMainBodyPart == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Selectează regiunea anatomică')),
                  );
                  return;
                }

                final String fullBodyPart = selectedSubBodyPart != null
                    ? '$selectedMainBodyPart - $selectedSubBodyPart'
                    : selectedMainBodyPart!;
                final locationLabel =
                    '$selectedBodySide - $selectedLateralSide - $fullBodyPart';

                final scan = SavedScan(
                  imagePath: widget.imageFile.path,
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
                );

                final navigator = Navigator.of(context);
                await SavedScans.save(scan);

                if (mounted) {
                  navigator.pop(); // Închide dialog
                  navigator.pop(); // Închide ecran
                }
              },
              child: const Text('Salvează'),
            ),
          ],
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

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(title: const Text('Previzualizare scanare')),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: SizedBox(
              height: screenHeight * 0.4,
              width: double.infinity,
              child: Image.file(
                File(widget.imageFile.path),
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverConstrainedCrossAxis(
            maxExtent: 600,
            sliver: SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _error
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                const Text('Ceva nu a funcționat...'),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () => setState(() {
                                    _error = false;
                                  }),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reîncearcă'),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize:
                                        const Size(double.infinity, 56),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : _showResult
                            ? Column(
                                children: [
                                  Expanded(
                                    child: ResultCard(
                                      title: classes[_scanResult!.classId]!,
                                      subtitle: Recommendations()
                                          .get(_scanResult!.classId),
                                      icon: '🩺',
                                      color: getColorForClassConfidence(
                                        _scanResult!.classId,
                                        _scanResult!.confidence,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: _openSaveScanDialog,
                                    icon: const Icon(Icons.save_alt),
                                    label: const Text('Salvează rezultatul'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 48),
                                    ),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.end,
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
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
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
                                              style: TextStyle(
                                                  fontSize: 14, height: 1.4),
                                              textAlign: TextAlign.justify,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _consentGiven ? _getResult : null,
                                    icon: const Icon(Icons.analytics_outlined),
                                    label: const Text('Obține rezultatul'),
                                    style: ElevatedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 56),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: () => Navigator.pop(context),
                                    icon: const Icon(Icons.refresh),
                                    label: const Text('Reîncarcă / Refă poză'),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize:
                                          const Size(double.infinity, 56),
                                    ),
                                  ),
                                ],
                              ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
