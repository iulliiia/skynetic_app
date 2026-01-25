import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skynetic_app/models/recommendation.dart';
import 'package:skynetic_app/models/scan_result.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/screens/clinics_map_screen.dart';
import 'package:intl/intl.dart';

class PhotoDetailScreen extends StatelessWidget {
  final SavedScan scan;

  const PhotoDetailScreen({
    super.key,
    required this.scan,
  });

  bool get isDangerous => scan.classId == 1;

  Color _getStatusColor() {
    switch (scan.classId) {
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

  Widget _buildInfoCard(String title, String content, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor();

    return Scaffold(
      appBar: AppBar(
        title: Text(scan.uniqueTag),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Implement sharing functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content:
                        Text('Funcționalitate de partajare în dezvoltare')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image with status overlay
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Stack(
                  children: [
                    Image.file(
                      File(scan.imagePath),
                      height: 300,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Scan Information Section
            const Text(
              'Informații scanare',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Info cards
            _buildInfoCard(
              'Etichetă',
              scan.uniqueTag,
              Icons.label_outline,
            ),
            _buildInfoCard(
              'Localizare',
              scan.locationLabel,
              Icons.place_outlined,
            ),
            _buildInfoCard(
              'Data scanării',
              DateFormat('dd MMMM yyyy, HH:mm', 'ro_RO').format(scan.scanDate),
              Icons.calendar_today_outlined,
            ),
            if (scan.notes != null && scan.notes!.isNotEmpty)
              _buildInfoCard(
                'Note',
                scan.notes!,
                Icons.note_outlined,
              ),

            const SizedBox(height: 24),

            // Diagnosis Section
            const Text(
              'Diagnostic',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        isDangerous
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                        color: statusColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${classes[scan.classId]}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isDangerous
                        ? 'Această leziune poate fi periculoasă. Îți recomandăm să consulți un medic dermatolog cât mai curând.'
                        : 'Această leziune nu pare a fi periculoasă. Totuși, monitorizarea periodică este importantă.',
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Recommendations
            const Text(
              'Recomandări',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text(
                          'Sfaturi pentru monitorizare',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Recommendations().get(scan.classId) ??
                          'Nicio recomandare disponibilă.',
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (context) => const DermatologistMapScreen()),
                  );
                },
                icon: const Icon(Icons.local_hospital),
                label: const Text('Caută un dermatolog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent1,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
