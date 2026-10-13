import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';

final myRequestsProvider = FutureProvider<List<ReviewRequest>>(
  (ref) => ref.watch(reviewRepositoryProvider).myRequests(),
);

final requestProvider = FutureProvider.family<ReviewRequest, String>(
  (ref, id) => ref.watch(reviewRepositoryProvider).request(id),
);

final requestLesionScansProvider = FutureProvider.family<List<Scan>, String>(
  (ref, id) => ref.watch(reviewRepositoryProvider).lesionScans(id),
);

final doctorDashboardProvider = FutureProvider<DoctorDashboard>(
  (ref) => ref.watch(reviewRepositoryProvider).dashboard(),
);

/// Doctor's cases by status group: 'open' (pending/accepted/needs_info) or 'closed'.
final doctorCasesProvider = FutureProvider.family<List<ReviewRequest>, String>((ref, group) {
  final statuses = group == 'open'
      ? const [ReviewStatus.pending, ReviewStatus.accepted, ReviewStatus.needsInfo]
      : const [ReviewStatus.completed, ReviewStatus.rejected, ReviewStatus.cancelled, ReviewStatus.expired];
  return ref.watch(reviewRepositoryProvider).assigned(statuses: statuses);
});

/// Drops every review cache (after any transition).
void invalidateReviewData(WidgetRef ref) {
  ref.invalidate(myRequestsProvider);
  ref.invalidate(requestProvider);
  ref.invalidate(requestLesionScansProvider);
  ref.invalidate(doctorDashboardProvider);
  ref.invalidate(doctorCasesProvider);
}
