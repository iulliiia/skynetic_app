import 'dart:io';

import 'package:flutter/material.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Shows a scan photo from disk, with a placeholder if the file is missing.
class ScanImage extends StatelessWidget {
  final String path;
  final double? width;
  final double? height;
  final BoxFit fit;

  const ScanImage({
    super.key,
    required this.path,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    return Image.file(
      File(path),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) => Container(
        width: width,
        height: height,
        color: AppColors.accent1.withValues(alpha: 0.1),
        alignment: Alignment.center,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: AppColors.accent1.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}
