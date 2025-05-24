import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Widget _buildDialogOption(String text, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        margin: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accent1.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }

  List<SavedScan> _displayedScans = [];
  String _filter = 'Toate';
  String _sortOrder = 'newest';
  Set<SavedScan> _selectedScans = {};

  @override
  void initState() {
    super.initState();
    _loadAndApplyFilters();
  }

  Future<void> _loadAndApplyFilters() async {
    await SavedScans.load();
    _applyFilters();
  }

  void _applyFilters() {
    List<SavedScan> scans = List.from(SavedScans.list);

    if (_filter == 'Pozitive') {
      scans = scans.where((scan) => scan.classId != 1).toList();
    } else if (_filter == 'Negative') {
      scans = scans.where((scan) => scan.classId == 1).toList();
    }

    if (_sortOrder == 'newest') {
      scans = scans.reversed.toList();
    }

    setState(() {
      _displayedScans = scans;
    });
  }

  Future<void> _deleteSelectedScans() async {
    for (final scan in _selectedScans) {
      await SavedScans.remove(scan);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Scanările selectate au fost șterse cu succes.'),
    ));

    _selectedScans.clear();
    _applyFilters();
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent1.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filtrare după diagnostic',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDialogOption('Toate', () {
                setState(() => _filter = 'Toate');
                Navigator.pop(context);
                _applyFilters();
              }),
              _buildDialogOption('Pozitive', () {
                setState(() => _filter = 'Pozitive');
                Navigator.pop(context);
                _applyFilters();
              }),
              _buildDialogOption('Negative', () {
                setState(() => _filter = 'Negative');
                Navigator.pop(context);
                _applyFilters();
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showSortDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent1.withOpacity(0.1),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Sortare după dată',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              _buildDialogOption('Cele mai noi', () {
                setState(() => _sortOrder = 'newest');
                Navigator.pop(context);
                _applyFilters();
              }),
              _buildDialogOption('Cele mai vechi', () {
                setState(() => _sortOrder = 'oldest');
                Navigator.pop(context);
                _applyFilters();
              }),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilul tău'),
        actions: _selectedScans.isNotEmpty
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: _deleteSelectedScans,
                )
              ]
            : null,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Scanări salvate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _showFilterDialog,
                      icon: const Icon(Icons.filter_alt_outlined),
                    ),
                    IconButton(
                      onPressed: _showSortDialog,
                      icon: const Icon(Icons.sort),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _displayedScans.isEmpty
                  ? const Center(
                      child: Text('Nu ai salvat nicio scanare încă.'))
                  : GridView.builder(
                      itemCount: _displayedScans.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemBuilder: (context, index) {
                        final scan = _displayedScans[index];
                        final isSelected = _selectedScans.contains(scan);
                        return GestureDetector(
                          onLongPress: () {
                            setState(() {
                              if (isSelected) {
                                _selectedScans.remove(scan);
                              } else {
                                _selectedScans.add(scan);
                              }
                            });
                          },
                          onTap: () {
                            if (_selectedScans.isNotEmpty) {
                              setState(() {
                                if (isSelected) {
                                  _selectedScans.remove(scan);
                                } else {
                                  _selectedScans.add(scan);
                                }
                              });
                            } else {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => PhotoDetailScreen(
                                    imagePath: scan.imagePath,
                                    classId: scan.classId,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(scan.imagePath),
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                ),
                              ),
                              if (isSelected)
                                const Positioned(
                                  top: 4,
                                  right: 4,
                                  child: Icon(Icons.check_circle,
                                      color: Colors.redAccent),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
