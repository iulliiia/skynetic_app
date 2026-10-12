import 'package:flutter/material.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:intl/intl.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:skynetic_app/widgets/scan_image.dart';

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
  // bumped to reset the dropdowns when filters are cleared
  int _filtersVersion = 0;

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

  @override
  void dispose() {
    tagSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadScans() async {
    await SavedScans.load();
    if (!mounted) return;
    setState(() {
      // newest first
      _allScans = List.from(SavedScans.list.reversed);
      if (selectedBodyPart != null &&
          !_allScans.any((scan) => scan.bodyPart == selectedBodyPart)) {
        selectedBodyPart = null;
        _filtersVersion++;
      }
    });
    _applyFilters();
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
      _filtersVersion++;
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
                const Expanded(
                  child: Text(
                    'Filtrează scanările',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
                key: ValueKey('side-$_filtersVersion'),
                decoration: const InputDecoration(
                  labelText: 'Partea corpului',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                initialValue: selectedBodySide,
                items: ['Anterior', 'Posterior'].map((side) {
                  return DropdownMenuItem(
                    value: side,
                    child: Text(side, overflow: TextOverflow.ellipsis));
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
                key: ValueKey('lateral-$_filtersVersion'),
                decoration: const InputDecoration(
                  labelText: 'Lateralitate',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                initialValue: selectedLateralSide,
                items: ['Stânga', 'Dreapta', 'Centru'].map((side) {
                  return DropdownMenuItem(
                    value: side,
                    child: Text(side, overflow: TextOverflow.ellipsis));
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
                key: ValueKey('part-$_filtersVersion'),
                decoration: const InputDecoration(
                  labelText: 'Regiunea anatomică',
                  border: OutlineInputBorder(),
                ),
                isExpanded: true,
                initialValue: selectedBodyPart,
                items: _allScans
                    .map((scan) => scan.bodyPart)
                    .toSet()
                    .map((part) => DropdownMenuItem(
                        value: part,
                        child: Text(part, overflow: TextOverflow.ellipsis)))
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
                contentPadding: EdgeInsets.zero,
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
              // filters apply as soon as they change
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: const Text('Șterge filtrele'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelectedScans() async {
    final count = _selectedScans.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge scanările'),
        content: Text(count == 1
            ? 'Ești sigur că vrei să ștergi scanarea selectată?'
            : 'Ești sigur că vrei să ștergi cele $count scanări selectate?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Anulează'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    for (final scan in _selectedScans) {
      await SavedScans.remove(scan);
    }
    if (!mounted) return;
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
        title: Text(_selectedScans.isEmpty
            ? 'Arhiva ta'
            : '${_selectedScans.length} selectate'),
        leading: _selectedScans.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(_selectedScans.clear),
              ),
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
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: ResponsiveCenter(child: _buildFilterSection()),
          ),
          _displayedScans.isEmpty
              ? const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Nicio scanare de afișat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16.0),
                  sliver: SliverGrid.builder(
                    itemCount: _displayedScans.length,
                    // 2 columns on phones, more on tablets / landscape
                    // A fixed tile height that grows with the font size, so the
                    // caption below the photo never overflows the tile.
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 220,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      mainAxisExtent: 140 +
                          MediaQuery.textScalerOf(context).scale(1) * 76,
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
                            Navigator.of(context)
                                .push(
                                  MaterialPageRoute(
                                    builder: (_) => PhotoDetailScreen(
                                      scan: scan,
                                    ),
                                  ),
                                )
                                .then((_) => _loadScans());
                          }
                        },
                        child: Card(
                          margin: EdgeInsets.zero,
                          clipBehavior: Clip.antiAlias,
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
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ScanImage(path: scan.imagePath),
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
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
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
                                    const SizedBox(height: 4),
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
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ],
      ),
    );
  }
}
