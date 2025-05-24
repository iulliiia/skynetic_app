import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
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

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

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

  void _saveScan() async {
    if (_scanResult == null) return;

    final diagnosis = classes[_scanResult!.classId];

    if (diagnosis == null) return;

    final scan = SavedScan(
      imagePath: widget.imageFile.path,
      classId: _scanResult!.classId,
    );

    await SavedScans.save(scan);

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args == 'saved') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Scanarea a fost salvată cu succes!')),
        );
      });
    }
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      appBar: AppBar(title: const Text('Previzualizare scanare')),
      body: Column(
        children: [
          SizedBox(
            height: screenHeight * 0.4,
            width: double.infinity,
            child: Image.file(
              File(widget.imageFile.path),
              fit: BoxFit.cover,
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text('Ceva nu a functionat...'),
                              const SizedBox(height: 12),
                              OutlinedButton.icon(
                                onPressed: () => setState(() {
                                  _error = false;
                                }),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Reîncearca'),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 56),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _showResult
                          ? Column(
                              children: [
                                Expanded(
                                  child: PageView(
                                    controller: _pageController,
                                    children: [
                                      ResultCard(
                                        title:
                                            "Diagnostic: ${classes[_scanResult!.classId]!}",
                                        subtitle:
                                            "Acuratete: ${(_scanResult!.confidence * 100).toStringAsFixed(2)}%",
                                        icon: '🩺',
                                      ),
                                      ResultCard(
                                        title: "Recomandare:",
                                        subtitle:
                                            " ${Recommendations().get(_scanResult!.classId)}",
                                        icon: '📋',
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: _saveScan,
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
                                ElevatedButton.icon(
                                  onPressed: _getResult,
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
        ],
      ),
    );
  }
}
