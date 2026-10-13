import 'package:flutter/material.dart';
import 'package:skynetic_app/widgets/responsive_center.dart';
import 'package:image_picker/image_picker.dart';

import 'package:go_router/go_router.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/features/scans/image_picking.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final file = await pickAndCropImage(context, source);
    if (file != null && context.mounted) {
      context.push('/scan/result', extra: ScanResultArgs(file));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizează-ți pielea'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: ResponsiveCenter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Descoperă puterea tehnologiei pentru sănătatea ta',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Tehnologia a evoluat, iar acum o poți folosi pentru a avea grijă de pielea ta. '
                'Cu ajutorul unui model de învățare automată creat special pentru analiza leziunilor cutanate, aplicația poate examina o simplă fotografie a pielii tale. ',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Află dacă este sau nu este cazul să consulți un medic dermatolog.',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Rapid, accesibil și orientat spre prevenție!',
                style: TextStyle(
                  fontSize: 15,
                  color: AppColors.textPrimary,
                  height: 1.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              _buildActionCard(
                context,
                icon: Icons.camera_alt_outlined,
                title: 'Fotografiază',
                description: 'Deschide camera pentru a face o poză leziunii',
                onTap: () => _pickImage(context, ImageSource.camera),
              ),
              const SizedBox(height: 20),
              _buildActionCard(
                context,
                icon: Icons.photo_library_outlined,
                title: 'Încarcă din galerie',
                description: 'Selectează o imagine existentă din telefon',
                onTap: () => _pickImage(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 6,
      shadowColor: AppColors.primary.withValues(alpha: 0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 140),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.primary,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        description,
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.accent1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
