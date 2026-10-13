import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';

/// Reference data (cached by the repository).
final anatomicalSitesProvider = FutureProvider<List<AnatomicalSite>>(
  (ref) => ref.watch(lesionRepositoryProvider).anatomicalSites(),
);

/// The patient's active lesions. Invalidate after create/update/upload.
final lesionsProvider = FutureProvider<List<Lesion>>(
  (ref) => ref.watch(lesionRepositoryProvider).lesions(),
);

final archivedLesionsProvider = FutureProvider<List<Lesion>>(
  (ref) async => (await ref.watch(lesionRepositoryProvider).lesions(includeArchived: true))
      .where((l) => l.isArchived)
      .toList(),
);

final lesionProvider = FutureProvider.family<Lesion, String>(
  (ref, id) => ref.watch(lesionRepositoryProvider).lesion(id),
);

final lesionScansProvider = FutureProvider.family<List<Scan>, String>(
  (ref, lesionId) => ref.watch(lesionRepositoryProvider).scans(lesionId),
);

/// Protected image bytes, cached for the session so lists don't re-download
/// on every rebuild.
final scanImageProvider = FutureProvider.family<Uint8List, String>(
  (ref, scanId) => ref.watch(protectedImageProvider('/scans/$scanId/image').future),
);

/// Any protected image, keyed by its API path.
final protectedImageProvider = FutureProvider.family<Uint8List, String>(
  (ref, path) => ref.watch(lesionRepositoryProvider).imageBytes(path),
);

/// Drops every lesion-related cache (after mutations or sign-out).
void invalidateLesionData(WidgetRef ref) {
  ref.invalidate(lesionsProvider);
  ref.invalidate(archivedLesionsProvider);
  ref.invalidate(lesionProvider);
  ref.invalidate(lesionScansProvider);
}
