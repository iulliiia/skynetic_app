import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';

/// Review-request endpoints for patients and doctors.
abstract class ReviewRepository {
  // patient
  Future<ReviewRequest> createRequest(String scanId, {String? message});
  Future<List<ReviewRequest>> myRequests();
  Future<ReviewRequest> cancel(String id);
  // shared (participants)
  Future<ReviewRequest> request(String id);
  Future<List<MedicalReview>> reviews(String id);
  Future<List<Scan>> lesionScans(String id);
  // doctor
  Future<DoctorDashboard> dashboard();
  Future<List<ReviewRequest>> assigned({List<String> statuses = const []});
  Future<ReviewRequest> accept(String id);
  Future<ReviewRequest> needsInfo(String id, String note);
  Future<ReviewRequest> resume(String id);
  Future<ReviewRequest> reject(String id, String reason);
  Future<MedicalReview> submitAssessment(String id, AssessmentInput input);

  /// Path of a case scan image, fetched through the protected image provider.
  static String caseImagePath(String requestId, String scanId) => '/review-requests/$requestId/scans/$scanId/image';
}

class ApiReviewRepository implements ReviewRepository {
  final ApiClient _client;
  ApiReviewRepository(this._client);

  @override
  Future<ReviewRequest> createRequest(String scanId, {String? message}) async => ReviewRequest.fromJson(
        await _client.postJson('/review-requests', body: {'scan_id': scanId, if (message != null) 'message': message}),
      );

  @override
  Future<List<ReviewRequest>> myRequests() async => _list(await _client.getJson('/review-requests'), ReviewRequest.fromJson);

  @override
  Future<ReviewRequest> cancel(String id) async => ReviewRequest.fromJson(await _client.postJson('/review-requests/$id/cancel'));

  @override
  Future<ReviewRequest> request(String id) async => ReviewRequest.fromJson(await _client.getJson('/review-requests/$id'));

  @override
  Future<List<MedicalReview>> reviews(String id) async =>
      _list(await _client.getJson('/review-requests/$id/reviews'), MedicalReview.fromJson);

  @override
  Future<List<Scan>> lesionScans(String id) async =>
      _list(await _client.getJson('/review-requests/$id/lesion-scans'), Scan.fromJson);

  @override
  Future<DoctorDashboard> dashboard() async => DoctorDashboard.fromJson(await _client.getJson('/doctor/dashboard'));

  @override
  Future<List<ReviewRequest>> assigned({List<String> statuses = const []}) async => _list(
        await _client.getJson('/doctor/review-requests', query: {if (statuses.isNotEmpty) 'status': statuses.join(',')}),
        ReviewRequest.fromJson,
      );

  @override
  Future<ReviewRequest> accept(String id) async =>
      ReviewRequest.fromJson(await _client.postJson('/doctor/review-requests/$id/accept'));

  @override
  Future<ReviewRequest> needsInfo(String id, String note) async =>
      ReviewRequest.fromJson(await _client.postJson('/doctor/review-requests/$id/needs-info', body: {'note': note}));

  @override
  Future<ReviewRequest> resume(String id) async =>
      ReviewRequest.fromJson(await _client.postJson('/doctor/review-requests/$id/resume'));

  @override
  Future<ReviewRequest> reject(String id, String reason) async =>
      ReviewRequest.fromJson(await _client.postJson('/doctor/review-requests/$id/reject', body: {'reason': reason}));

  @override
  Future<MedicalReview> submitAssessment(String id, AssessmentInput input) async =>
      MedicalReview.fromJson(await _client.postJson('/doctor/review-requests/$id/reviews', body: input.toJson()));

  static List<T> _list<T>(Map<String, dynamic> res, T Function(Map<String, dynamic>) f) =>
      (res['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(f).toList();
}
