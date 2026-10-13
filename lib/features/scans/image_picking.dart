import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Picks a photo from the camera or gallery and lets the user crop it.
/// Returns null when the user cancels. Shows a snackbar on permission errors.
Future<XFile?> pickAndCropImage(BuildContext context, ImageSource source) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    // the model works on 180x180 images, so there is no need to upload
    // full-resolution photos
    final picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 90,
    );
    if (picked == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Decupează imaginea',
          toolbarColor: AppColors.primary,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.accent2,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
        ),
        IOSUiSettings(
          title: 'Decupează imaginea',
          doneButtonTitle: 'Gata',
          cancelButtonTitle: 'Anulează',
        ),
      ],
    );
    return cropped == null ? null : XFile(cropped.path);
  } catch (_) {
    messenger.showSnackBar(SnackBar(
      content: Text(source == ImageSource.camera
          ? 'Nu s-a putut deschide camera. Verifică permisiunile aplicației.'
          : 'Nu s-a putut deschide galeria. Verifică permisiunile aplicației.'),
    ));
    return null;
  }
}

/// Bottom sheet asking camera vs. gallery, then picks and crops.
Future<XFile?> pickImageWithSourceSheet(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
            title: const Text('Fotografiază'),
            onTap: () => Navigator.pop(ctx, ImageSource.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined, color: AppColors.primary),
            title: const Text('Alege din galerie'),
            onTap: () => Navigator.pop(ctx, ImageSource.gallery),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (source == null || !context.mounted) return null;
  return pickAndCropImage(context, source);
}
