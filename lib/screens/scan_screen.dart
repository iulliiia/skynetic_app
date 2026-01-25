import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:skynetic_app/screens/scan_result_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      // Crop the image
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.deepOrange,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedFile != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                ScanResultScreen(imageFile: XFile(croppedFile.path)),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analizează-ți pielea'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Descoperă puterea tehnologiei pentru sănătatea ta',
              textAlign: TextAlign.center,
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
            const Text(
              'Alfă dacă este sau nu este cazul să consulți un medic dermatolog.',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            const Text(
              '        Rapid, accesibil și orientat spre prevenție!',
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
      shadowColor: AppColors.primary.withOpacity(0.25),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 140,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 18),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
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
