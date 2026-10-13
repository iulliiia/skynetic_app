import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/features/lesions/lesion_providers.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Displays a scan image fetched with the session token (the backend never
/// exposes image URLs). Shows a placeholder while loading or on failure.
class AuthenticatedScanImage extends StatelessWidget {
  final String scanId;
  final BoxFit fit;
  final double? width;
  final double? height;

  const AuthenticatedScanImage({
    super.key,
    required this.scanId,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) =>
      ProtectedImage(path: '/scans/$scanId/image', fit: fit, width: width, height: height);
}

/// Displays any protected image by API path (scan images, case images).
class ProtectedImage extends ConsumerWidget {
  final String path;
  final BoxFit fit;
  final double? width;
  final double? height;

  const ProtectedImage({super.key, required this.path, this.fit = BoxFit.cover, this.width, this.height});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(protectedImageProvider(path));
    return SizedBox(
      width: width,
      height: height,
      child: bytes.when(
        data: (b) => Image.memory(b, fit: fit, gaplessPlayback: true),
        loading: () => Container(
          color: AppColors.accent1.withValues(alpha: 0.08),
          alignment: Alignment.center,
          child: const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => Container(
          color: AppColors.accent1.withValues(alpha: 0.1),
          alignment: Alignment.center,
          child: IconButton(
            tooltip: 'Reîncearcă',
            icon: Icon(Icons.refresh, color: AppColors.accent1.withValues(alpha: 0.7)),
            onPressed: () => ref.invalidate(protectedImageProvider(path)),
          ),
        ),
      ),
    );
  }
}
