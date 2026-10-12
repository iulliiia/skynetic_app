import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:intl/intl.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<SavedScan> _displayedScans = [];
  List<SavedScan> _allScans = [];
  final Set<SavedScan> _selectedScans = {};
  bool _showFilters = false;

  // Filter variables
  String? selectedBodySide;
  String? selectedLateralSide;
  String? selectedBodyPart;
  DateTimeRange? selectedDateRange;
  final TextEditingController tagSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadScans();
  }

  Future<void> _loadScans() async {
    await SavedScans.load();
    setState(() {
      _allScans = List.from(SavedScans.list);
      _displayedScans = List.from(SavedScans.list);
    });
  }

  void _applyFilters() {
    List<SavedScan> filteredScans = _allScans;

    // Filter by body side
    if (selectedBodySide != null) {
      filteredScans = filteredScans
          .where((scan) => scan.bodySide == selectedBodySide)
          .toList();
    }

    // Filter by lateral side
    if (selectedLateralSide != null) {
      filteredScans = filteredScans
          .where((scan) => scan.lateralSide == selectedLateralSide)
          .toList();
    }

    // Filter by body part
    if (selectedBodyPart != null) {
      filteredScans = filteredScans
          .where((scan) => scan.bodyPart == selectedBodyPart)
          .toList();
    }

    // Filter by date range
    if (selectedDateRange != null) {
      filteredScans = filteredScans.where((scan) {
        return scan.scanDate.isAfter(
                selectedDateRange!.start.subtract(const Duration(days: 1))) &&
            scan.scanDate
                .isBefore(selectedDateRange!.end.add(const Duration(days: 1)));
      }).toList();
    }

    // Filter by tag search
    if (tagSearchController.text.isNotEmpty) {
      final searchTerm = tagSearchController.text.toLowerCase();
      filteredScans = filteredScans
          .where((scan) => scan.uniqueTag.toLowerCase().contains(searchTerm))
          .toList();
    }

    setState(() {
      _displayedScans = filteredScans;
    });
  }

  void _clearFilters() {
    setState(() {
      selectedBodySide = null;
      selectedLateralSide = null;
      selectedBodyPart = null;
      selectedDateRange = null;
      tagSearchController.clear();
      _displayedScans = _allScans;
    });
  }

  Color _getColorForClassId(int classId) {
    switch (classId) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.red;
      case 2:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Widget _buildFilterSection() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Filtrează scanările',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: Icon(
                      _showFilters ? Icons.expand_less : Icons.expand_more),
                  onPressed: () {
                    setState(() {
                      _showFilters = !_showFilters;
                    });
                  },
                ),
              ],
            ),
            if (_showFilters) ...[
              const SizedBox(height: 16),

              // Tag search
              TextField(
                controller: tagSearchController,
                decoration: const InputDecoration(
                  labelText: 'Caută după etichetă',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => _applyFilters(),
              ),
              const SizedBox(height: 12),

              // Body side filter
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Partea corpului',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedBodySide,
                items: ['Anterior', 'Posterior'].map((side) {
                  return DropdownMenuItem(value: side, child: Text(side));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBodySide = value;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),

              // Lateral side filter
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Lateralitate',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedLateralSide,
                items: ['Stânga', 'Dreapta', 'Centru'].map((side) {
                  return DropdownMenuItem(value: side, child: Text(side));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedLateralSide = value;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),

              // Body part filter
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: 'Regiunea anatomică',
                  border: OutlineInputBorder(),
                ),
                initialValue: selectedBodyPart,
                items: _allScans
                    .map((scan) => scan.bodyPart)
                    .toSet()
                    .map((part) =>
                        DropdownMenuItem(value: part, child: Text(part)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedBodyPart = value;
                  });
                  _applyFilters();
                },
              ),
              const SizedBox(height: 12),

              // Date range picker
              ListTile(
                title: Text(selectedDateRange == null
                    ? 'Selectează perioada'
                    : 'Perioada: ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(selectedDateRange!.end)}'),
                leading: const Icon(Icons.date_range),
                onTap: () async {
                  final DateTimeRange? picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDateRange = picked;
                    });
                    _applyFilters();
                  }
                },
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _clearFilters,
                      child: const Text('Șterge filtrele'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      child: const Text('Aplică filtrele'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedScans() async {
    for (final scan in _selectedScans) {
      await SavedScans.remove(scan);
    }
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Scanările selectate au fost șterse cu succes.'),
    ));

    _selectedScans.clear();
    _loadScans();
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
            : [
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadScans,
                )
              ],
      ),
      body: Column(
        children: [
          _buildFilterSection(),
          Expanded(
            child: _displayedScans.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Nu ai salvat nicio scanare încă.',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: GridView.builder(
                      itemCount: _displayedScans.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.8,
                      ),
                      itemBuilder: (context, index) {
                        final scan = _displayedScans[index];
                        final isSelected = _selectedScans.contains(scan);
                        final statusColor = _getColorForClassId(scan.classId);

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
                                    scan: scan,
                                  ),
                                ),
                              );
                            }
                          },
                          child: Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: statusColor,
                                width: 3,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(12),
                                          topRight: Radius.circular(12),
                                        ),
                                        child: Image.file(
                                          File(scan.imagePath),
                                          fit: BoxFit.cover,
                                          width: double.infinity,
                                          height: double.infinity,
                                        ),
                                      ),
                                      if (isSelected)
                                        const Positioned(
                                          top: 8,
                                          left: 8,
                                          child: Icon(
                                            Icons.check_circle,
                                            color: Colors.blue,
                                            size: 24,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          scan.uniqueTag,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          scan.locationLabel,
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const Spacer(),
                                        Text(
                                          DateFormat('dd/MM/yyyy')
                                              .format(scan.scanDate),
                                          style: const TextStyle(
                                            fontSize: 10,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
