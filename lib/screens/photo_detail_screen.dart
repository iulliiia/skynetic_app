import 'dart:io';
import 'package:flutter/material.dart';
import 'package:skynetic_app/models/recommendation.dart';
import 'package:skynetic_app/models/scan_result.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class PhotoDetailScreen extends StatelessWidget {
  final String imagePath;
  final int classId;

  const PhotoDetailScreen({
    super.key,
    required this.imagePath,
    required this.classId,
  });

  bool get isDangerous => classId == 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalii scanare'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(
                File(imagePath),
                height: 300,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Rezultat: ${classes[classId]}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isDangerous)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Această leziune poate fi periculoasă. Îți recomandăm să consulți un medic dermatolog cât mai curând.',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_circle_outline, color: Colors.green),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Această leziune nu pare a fi periculoasă. Totuși, monitorizarea periodică este importantă.',
                        style: TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.local_hospital),
                label: const Text('Caută un dermatolog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accent1,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
