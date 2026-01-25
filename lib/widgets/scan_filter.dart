import 'package:flutter/material.dart';
import 'package:skynetic_app/models/saved_scans.dart';

class ScanFilterWidget extends StatefulWidget {
  final Function(List<SavedScan>) onFilteredScans;
  final List<SavedScan> allScans;

  const ScanFilterWidget({
    Key? key,
    required this.onFilteredScans,
    required this.allScans,
  }) : super(key: key);

  @override
  State<ScanFilterWidget> createState() => _ScanFilterWidgetState();
}

class _ScanFilterWidgetState extends State<ScanFilterWidget> {
  String? selectedBodySide;
  String? selectedLateralSide;
  String? selectedBodyPart;
  DateTimeRange? selectedDateRange;
  final TextEditingController tagSearchController = TextEditingController();

  void _applyFilters() {
    List<SavedScan> filteredScans = widget.allScans;

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

    widget.onFilteredScans(filteredScans);
  }

  void _clearFilters() {
    setState(() {
      selectedBodySide = null;
      selectedLateralSide = null;
      selectedBodyPart = null;
      selectedDateRange = null;
      tagSearchController.clear();
    });
    widget.onFilteredScans(widget.allScans);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtrează scanările',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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
              value: selectedBodySide,
              items: ['Anterior (Față)', 'Posterior (Spate)'].map((side) {
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
              value: selectedLateralSide,
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

            // Date range picker
            ListTile(
              title: Text(selectedDateRange == null
                  ? 'Selectează perioada'
                  : 'Perioada: ${selectedDateRange!.start.day}/${selectedDateRange!.start.month}/${selectedDateRange!.start.year} - ${selectedDateRange!.end.day}/${selectedDateRange!.end.month}/${selectedDateRange!.end.year}'),
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
        ),
      ),
    );
  }
}
