import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/lesions/prediction_models.dart';

/// Lesion, scan and guest-scan endpoints of the platform API.
abstract class LesionRepository {
  Future<List<AnatomicalSite>> anatomicalSites();
  Future<List<Lesion>> lesions({bool includeArchived = false});
  Future<Lesion> lesion(String id);
  Future<Lesion> createLesion(LesionInput input);
  Future<Lesion> updateLesion(String id, Map<String, dynamic> patch);
  Future<List<Scan>> scans(String lesionId);
  Future<Scan> uploadScan(String lesionId, XFile image, {String source = 'unknown', String? notes});
  Future<Uint8List> scanImage(String scanId);
  /// Any protected image path (e.g. a case image for the assigned doctor).
  Future<Uint8List> imageBytes(String path);
  Future<void> deleteScan(String scanId);
  Future<GuestScan> uploadGuestScan(XFile image, {String source = 'unknown'});
  Future<Prediction> analyzeScan(String scanId);
  Future<Prediction> analyzeGuestScan(String scanId, String claimToken);
  Future<List<Prediction>> predictions(String scanId);
  Future<Scan> claimGuestScan({
    required String scanId,
    required String claimToken,
    String? lesionId,
    LesionInput? newLesion,
  });
}

class ApiLesionRepository implements LesionRepository {
  final ApiClient _client;
  List<AnatomicalSite>? _sitesCache;

  ApiLesionRepository(this._client);

  @override
  Future<List<AnatomicalSite>> anatomicalSites() async {
    if (_sitesCache != null) return _sitesCache!;
    final res = await _client.getJson('/anatomical-sites');
    return _sitesCache = _list(res, AnatomicalSite.fromJson);
  }

  @override
  Future<List<Lesion>> lesions({bool includeArchived = false}) async {
    final res = await _client.getJson('/lesions', query: {'include_archived': includeArchived});
    return _list(res, Lesion.fromJson);
  }

  @override
  Future<Lesion> lesion(String id) async => Lesion.fromJson(await _client.getJson('/lesions/$id'));

  @override
  Future<Lesion> createLesion(LesionInput input) async =>
      Lesion.fromJson(await _client.postJson('/lesions', body: input.toJson()));

  @override
  Future<Lesion> updateLesion(String id, Map<String, dynamic> patch) async =>
      Lesion.fromJson(await _client.patchJson('/lesions/$id', body: patch));

  @override
  Future<List<Scan>> scans(String lesionId) async =>
      _list(await _client.getJson('/lesions/$lesionId/scans'), Scan.fromJson);

  @override
  Future<Scan> uploadScan(String lesionId, XFile image, {String source = 'unknown', String? notes}) async {
    final form = await _form(image, source: source, notes: notes);
    return Scan.fromJson(await _client.postJson('/lesions/$lesionId/scans', body: form));
  }

  @override
  Future<Uint8List> scanImage(String scanId) => imageBytes('/scans/$scanId/image');

  @override
  Future<Uint8List> imageBytes(String path) async => Uint8List.fromList(await _client.getBytes(path));

  @override
  Future<void> deleteScan(String scanId) => _client.delete('/scans/$scanId');

  @override
  Future<GuestScan> uploadGuestScan(XFile image, {String source = 'unknown'}) async {
    final form = await _form(image, source: source);
    return GuestScan.fromJson(await _client.postJson('/guest/scans', body: form, noAuth: true));
  }

  @override
  Future<Prediction> analyzeScan(String scanId) async =>
      Prediction.fromJson(await _client.postJson('/scans/$scanId/analyze'));

  @override
  Future<Prediction> analyzeGuestScan(String scanId, String claimToken) async => Prediction.fromJson(
        await _client.call<Map<String, dynamic>>((d) => d.post(
              '/guest/scans/$scanId/analyze',
              options: Options(extra: {'noAuth': true}, headers: {'X-Claim-Token': claimToken}),
            )),
      );

  @override
  Future<List<Prediction>> predictions(String scanId) async =>
      _list(await _client.getJson('/scans/$scanId/predictions'), Prediction.fromJson);

  @override
  Future<Scan> claimGuestScan({
    required String scanId,
    required String claimToken,
    String? lesionId,
    LesionInput? newLesion,
  }) async {
    assert((lesionId == null) != (newLesion == null), 'exactly one target');
    final res = await _client.postJson('/guest/scans/claim', body: {
      'scan_id': scanId,
      'claim_token': claimToken,
      if (lesionId != null) 'lesion_id': lesionId,
      if (newLesion != null) 'new_lesion': newLesion.toJson(),
    });
    return Scan.fromJson(res);
  }

  Future<FormData> _form(XFile image, {required String source, String? notes}) async {
    return FormData.fromMap({
      'image': await MultipartFile.fromFile(image.path, filename: image.name),
      'source': source,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    });
  }

  static List<T> _list<T>(Map<String, dynamic> res, T Function(Map<String, dynamic>) f) =>
      (res['items'] as List? ?? const []).cast<Map<String, dynamic>>().map(f).toList();
}
