import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/core/auth/auth_repository.dart';
import 'package:skynetic_app/core/auth/token_storage.dart';
import 'package:skynetic_app/core/providers.dart';
import 'package:skynetic_app/features/chat/chat_models.dart';
import 'package:skynetic_app/features/chat/chat_repository.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
import 'package:skynetic_app/features/privacy/privacy.dart';
import 'package:skynetic_app/features/lesions/lesion_repository.dart';
import 'package:skynetic_app/features/lesions/prediction_models.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/features/review/review_repository.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/theme/app_theme.dart';

/// Test doubles for the repositories plus helpers to pump screens with a
/// ProviderScope and a minimal GoRouter.

/// Local scans keep no image directory in tests (path_provider has no
/// platform implementation here and would otherwise block forever).
void installTestLocalStorage() {
  SavedScans.directoryResolver = () async => null;
}

const patientUser = AuthUser(
  id: 'u-patient', email: 'maria@test.ro', role: UserRole.patient, status: 'active',
  firstName: 'Maria', lastName: 'Ionescu',
);
const pendingDoctor = AuthUser(
  id: 'u-doc', email: 'dr@test.ro', role: UserRole.doctor, status: 'active',
  firstName: 'Ana', lastName: 'Popescu', doctorStatus: DoctorVerificationStatus.pending,
);
const approvedDoctor = AuthUser(
  id: 'u-doc2', email: 'dr2@test.ro', role: UserRole.doctor, status: 'active',
  firstName: 'Ana', lastName: 'Popescu', doctorStatus: DoctorVerificationStatus.approved,
);

const testPassword = 'Skynetic!2026';

class FakeAuthRepository implements AuthRepository {
  AuthUser? current;
  final Map<String, AuthUser> accounts;
  int loginCalls = 0;

  FakeAuthRepository({this.current, Map<String, AuthUser>? accounts})
      : accounts = accounts ?? {patientUser.email: patientUser, pendingDoctor.email: pendingDoctor};

  @override
  Future<AuthUser> login(String email, String password) async {
    loginCalls++;
    final user = accounts[email.trim().toLowerCase()];
    if (user == null || password != testPassword) {
      throw const ApiException(code: 'invalid_credentials', message: 'Email sau parolă incorecte.', statusCode: 401);
    }
    return current = user;
  }

  @override
  Future<AuthUser> registerPatient(String email, String password, PatientRegistration p) async {
    if (accounts.containsKey(email.toLowerCase())) {
      throw const ApiException(code: 'email_taken', message: 'Există deja un cont cu această adresă de email.', statusCode: 409);
    }
    return current = AuthUser(id: 'new', email: email, role: UserRole.patient, status: 'active',
        firstName: p.firstName, lastName: p.lastName);
  }

  @override
  Future<AuthUser> registerDoctor(String email, String password, DoctorRegistration d) async {
    return current = AuthUser(id: 'new-doc', email: email, role: UserRole.doctor, status: 'active',
        firstName: d.firstName, lastName: d.lastName, doctorStatus: DoctorVerificationStatus.pending);
  }

  @override
  Future<AuthUser?> restoreSession() async => current;

  @override
  Future<void> logout() async => current = null;
}

/// 1×1 transparent PNG, enough for Image.memory.
final Uint8List tinyPng = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==');

class FakeLesionRepository implements LesionRepository {
  final List<Lesion> lesionList;
  final Map<String, List<Scan>> scansByLesion;
  final List<String> claimed = [];
  int uploads = 0;

  // Analysis behaviour: scores returned, an error to throw, or a gate that
  // keeps the request pending (loading state).
  List<double> scores = [0.1, 0.8, 0.1];
  ApiException? analysisError;
  Completer<void>? holdAnalysis;
  int analyses = 0;

  FakeLesionRepository({List<Lesion>? lesions, Map<String, List<Scan>>? scans})
      : lesionList = lesions ?? [],
        scansByLesion = scans ?? {};

  static const sites = [
    AnatomicalSite(code: 'head', labelRo: 'Cap', sortOrder: 10),
    AnatomicalSite(code: 'head.scalp', labelRo: 'Scalp', parentCode: 'head', sortOrder: 11),
    AnatomicalSite(code: 'back', labelRo: 'Spate', sortOrder: 60),
    AnatomicalSite(code: 'back.upper', labelRo: 'Spate superior', parentCode: 'back', sortOrder: 61),
    AnatomicalSite(code: 'arm.upper', labelRo: 'Braț superior', parentCode: 'arm', sortOrder: 91),
  ];

  @override
  Future<List<AnatomicalSite>> anatomicalSites() async => sites;

  @override
  Future<List<Lesion>> lesions({bool includeArchived = false}) async =>
      lesionList.where((l) => includeArchived || !l.isArchived).toList();

  @override
  Future<Lesion> lesion(String id) async => lesionList.firstWhere((l) => l.id == id,
      orElse: () => throw const ApiException(code: 'not_found', message: 'Resursa nu a fost găsită.', statusCode: 404));

  @override
  Future<Lesion> createLesion(LesionInput input) async {
    final l = Lesion(
      id: 'l${lesionList.length + 1}', label: input.label, anatomicalSiteCode: input.anatomicalSiteCode,
      anatomicalSiteLabel: sites.firstWhere((s) => s.code == input.anatomicalSiteCode).labelRo,
      bodySide: input.bodySide, laterality: input.laterality, firstNoticedOn: input.firstNoticedOn,
      symptoms: input.symptoms, notes: input.notes, scanCount: 0, createdAt: DateTime.now(),
    );
    lesionList.add(l);
    return l;
  }

  @override
  Future<Lesion> updateLesion(String id, Map<String, dynamic> patch) async {
    final old = await lesion(id);
    final updated = Lesion(
      id: old.id, label: patch['label'] as String? ?? old.label,
      anatomicalSiteCode: old.anatomicalSiteCode, anatomicalSiteLabel: old.anatomicalSiteLabel,
      bodySide: old.bodySide, laterality: old.laterality, firstNoticedOn: old.firstNoticedOn,
      symptoms: old.symptoms, notes: old.notes, scanCount: old.scanCount, latestScanAt: old.latestScanAt,
      archivedAt: patch['archived'] == true ? DateTime.now() : (patch['archived'] == false ? null : old.archivedAt),
      createdAt: old.createdAt,
    );
    lesionList[lesionList.indexOf(old)] = updated;
    return updated;
  }

  @override
  Future<List<Scan>> scans(String lesionId) async => scansByLesion[lesionId] ?? const [];

  @override
  Future<Scan> uploadScan(String lesionId, XFile image, {String source = 'unknown', String? notes}) async {
    uploads++;
    final s = Scan(id: 's$uploads', lesionId: lesionId, source: source, createdAt: DateTime.now(),
        quality: const ScanQuality(blurScore: 500, warnings: [], acceptable: true), width: 640, height: 640);
    (scansByLesion[lesionId] ??= []).insert(0, s);
    return s;
  }

  @override
  Future<Uint8List> scanImage(String scanId) async => tinyPng;

  @override
  Future<Uint8List> imageBytes(String path) async => tinyPng;

  @override
  Future<void> deleteScan(String scanId) async {
    for (final list in scansByLesion.values) {
      list.removeWhere((s) => s.id == scanId);
    }
  }

  Future<Prediction> _analyze(String scanId) async {
    analyses++;
    if (holdAnalysis != null) await holdAnalysis!.future;
    if (analysisError != null) throw analysisError!;
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final sorted = [...scores]..sort((a, b) => b.compareTo(a));
    final margin = sorted.length > 1 ? sorted[0] - sorted[1] : 1.0;
    final p = Prediction(
      id: 'p$analyses', scanId: scanId, status: margin < 0.1 ? 'inconclusive' : 'completed',
      predictedClass: best, predictedLabel: const ['low_risk', 'high_risk', 'clear_skin'][best], scores: scores,
      topMargin: margin, modelName: 'skynetic-cnn', modelVersion: 'model2', inferenceMs: 42, createdAt: DateTime.now(),
    );
    final summary = PredictionSummary(id: p.id, status: p.status, predictedClass: best, predictedLabel: p.predictedLabel,
        modelVersion: 'model2', createdAt: p.createdAt);
    for (final list in scansByLesion.values) {
      final i = list.indexWhere((s) => s.id == scanId);
      if (i != -1) list[i] = list[i].copyWith(latestPrediction: summary);
    }
    return p;
  }

  @override
  Future<Prediction> analyzeScan(String scanId) => _analyze(scanId);

  @override
  Future<Prediction> analyzeGuestScan(String scanId, String claimToken) => _analyze(scanId);

  @override
  Future<List<Prediction>> predictions(String scanId) async => const [];

  @override
  Future<GuestScan> uploadGuestScan(XFile image, {String source = 'unknown'}) async => GuestScan(
        scanId: 'guest-1', claimToken: 'tok', expiresAt: DateTime.now().add(const Duration(hours: 24)),
        quality: const ScanQuality(blurScore: 500, warnings: [], acceptable: true));

  @override
  Future<Scan> claimGuestScan({required String scanId, required String claimToken, String? lesionId, LesionInput? newLesion}) async {
    claimed.add(scanId);
    return Scan(id: scanId, lesionId: lesionId ?? 'new', source: 'gallery', createdAt: DateTime.now(),
        quality: const ScanQuality(blurScore: 500, warnings: [], acceptable: true));
  }
}

Lesion sampleLesion({String id = 'l1', int scanCount = 2}) => Lesion(
      id: id, label: 'Aluniță umăr drept foarte lungă denumire', anatomicalSiteCode: 'back.upper',
      anatomicalSiteLabel: 'Spate superior', bodySide: 'posterior', laterality: 'right',
      firstNoticedOn: '2024-06-01', symptoms: const ['itching', 'growth'],
      notes: 'Pare mai mare decât luna trecută, de verificat la control.', scanCount: scanCount,
      latestScanAt: DateTime(2026, 5, 1), createdAt: DateTime(2026, 1, 1),
    );

Scan sampleScan({String id = 's1', bool poor = false}) => Scan(
      id: id, lesionId: 'l1', source: 'camera', capturedAt: DateTime(2026, 5, 1, 10), createdAt: DateTime(2026, 5, 1, 10),
      quality: ScanQuality(blurScore: poor ? 10 : 500, warnings: poor ? const ['blurry', 'too_dark'] : const [], acceptable: !poor),
      width: 640, height: 640, patientNotes: poor ? 'Lumina slabă' : null,
    );

/// In-memory review workflow, same rules as the backend (simplified).
class FakeReviewRepository implements ReviewRepository {
  final List<ReviewRequest> requests;
  final List<MedicalReview> submitted = [];
  final DoctorRef doctor = const DoctorRef(userId: 'u-doc2', firstName: 'Ana', lastName: 'Popescu', specialty: 'Dermatovenerologie');
  int created = 0;

  FakeReviewRepository({List<ReviewRequest>? requests}) : requests = requests ?? [];

  ReviewRequest _find(String id) => requests.firstWhere((r) => r.id == id,
      orElse: () => throw const ApiException(code: 'not_found', message: 'Resursa nu a fost găsită.', statusCode: 404));

  ReviewRequest _replace(ReviewRequest old, ReviewRequest updated) {
    requests[requests.indexOf(old)] = updated;
    return updated;
  }

  ReviewRequest _withStatus(ReviewRequest r, String status, {String? note}) => ReviewRequest(
        id: r.id, status: status, patientMessage: r.patientMessage, submittedAt: r.submittedAt,
        acceptedAt: status == ReviewStatus.accepted ? (r.acceptedAt ?? DateTime.now()) : r.acceptedAt,
        completedAt: status == ReviewStatus.completed ? DateTime.now() : r.completedAt,
        scan: r.scan, lesion: r.lesion, patient: r.patient, doctor: r.doctor, latestReview: r.latestReview,
        events: [...r.events, ReviewEvent(fromStatus: r.status, toStatus: status, note: note, occurredAt: DateTime.now())],
      );

  @override
  Future<ReviewRequest> createRequest(String scanId, {String? message}) async {
    if (requests.any((r) => r.scan?.id == scanId && r.isOpen)) {
      throw const ApiException(code: 'review_already_open', message: 'Această scanare are deja o cerere deschisă.', statusCode: 409);
    }
    created++;
    final r = ReviewRequest(
      id: 'rq$created', status: ReviewStatus.pending, patientMessage: message, submittedAt: DateTime.now(),
      scan: sampleScan(id: scanId), lesion: const LesionRef(id: 'l1', label: 'Aluniță umăr drept', siteLabelRo: 'Spate superior', bodySide: 'posterior'),
      doctor: doctor, events: [ReviewEvent(toStatus: ReviewStatus.pending, occurredAt: DateTime.now())],
    );
    requests.add(r);
    return r;
  }

  @override
  Future<List<ReviewRequest>> myRequests() async => requests.reversed.toList();

  @override
  Future<ReviewRequest> cancel(String id) async {
    final r = _find(id);
    if (r.status != ReviewStatus.pending) {
      throw const ApiException(code: 'invalid_transition', message: 'Cererea nu permite această acțiune.', statusCode: 409);
    }
    return _replace(r, _withStatus(r, ReviewStatus.cancelled));
  }

  @override
  Future<ReviewRequest> request(String id) async => _find(id);

  @override
  Future<List<MedicalReview>> reviews(String id) async => submitted.where((m) => true).toList();

  @override
  Future<List<Scan>> lesionScans(String id) async => [sampleScan(), sampleScan(id: 's2', poor: true)];

  @override
  Future<DoctorDashboard> dashboard() async => DoctorDashboard(
        pending: requests.where((r) => r.status == ReviewStatus.pending).length,
        accepted: requests.where((r) => r.status == ReviewStatus.accepted).length,
        needsInfo: requests.where((r) => r.status == ReviewStatus.needsInfo).length,
        completed: requests.where((r) => r.status == ReviewStatus.completed).length,
        unreadNotifications: 1,
      );

  @override
  Future<List<ReviewRequest>> assigned({List<String> statuses = const []}) async =>
      requests.where((r) => statuses.isEmpty || statuses.contains(r.status)).toList();

  @override
  Future<ReviewRequest> accept(String id) async {
    final r = _find(id);
    if (r.status != ReviewStatus.pending) throw const ApiException(code: 'invalid_transition', message: 'Cererea nu permite această acțiune.', statusCode: 409);
    return _replace(r, _withStatus(r, ReviewStatus.accepted));
  }

  @override
  Future<ReviewRequest> needsInfo(String id, String note) async => _replace(_find(id), _withStatus(_find(id), ReviewStatus.needsInfo, note: note));

  @override
  Future<ReviewRequest> resume(String id) async => _replace(_find(id), _withStatus(_find(id), ReviewStatus.accepted));

  @override
  Future<ReviewRequest> reject(String id, String reason) async => _replace(_find(id), _withStatus(_find(id), ReviewStatus.rejected, note: reason));

  @override
  Future<MedicalReview> submitAssessment(String id, AssessmentInput input) async {
    final r = _find(id);
    final m = MedicalReview(
      id: 'mr${submitted.length + 1}', version: submitted.length + 1, clinicalImpression: input.clinicalImpression,
      suspectedCategory: input.suspectedCategory, certainty: input.certainty, recommendation: input.recommendation,
      inPersonConsultationAdvised: input.inPersonConsultationAdvised, provenance: input.provenance,
      confirmedDiagnosis: input.confirmedDiagnosis, additionalComments: input.additionalComments, createdAt: DateTime.now(),
    );
    submitted.add(m);
    final done = _withStatus(r, ReviewStatus.completed, note: 'assessment v${m.version}');
    _replace(r, ReviewRequest(
      id: done.id, status: done.status, patientMessage: done.patientMessage, submittedAt: done.submittedAt,
      acceptedAt: done.acceptedAt, completedAt: done.completedAt, scan: done.scan, lesion: done.lesion,
      patient: done.patient, doctor: done.doctor, latestReview: m, events: done.events,
    ));
    return m;
  }
}

/// In-memory conversation with a controllable live stream.
class FakeChatRepository implements ChatRepository {
  final List<ChatMessage> messages;
  final StreamController<ChatEvent> live = StreamController<ChatEvent>.broadcast();
  bool failSends = false;
  int sends = 0;
  int connects = 0;
  final List<String> readCalls = [];

  FakeChatRepository({List<ChatMessage>? messages}) : messages = messages ?? [];

  @override
  Future<List<ChatMessage>> history(String requestId, {DateTime? before}) async => List.of(messages);

  @override
  Future<ChatMessage> send(String requestId, String body, String clientMessageId) async {
    sends++;
    if (failSends) throw const ApiException(code: 'network_error', message: 'Fără conexiune.');
    final m = ChatMessage(id: 'm$sends', requestId: requestId, senderUserId: patientUser.id, senderRole: 'patient',
        body: body, clientMessageId: clientMessageId, createdAt: DateTime.now());
    messages.add(m);
    return m;
  }

  @override
  Future<void> markRead(String requestId) async => readCalls.add(requestId);

  @override
  Future<Map<String, int>> unreadByRequest() async => {'rq1': 2};

  @override
  Future<ChatConnection> connect(String requestId) async {
    connects++;
    return _FakeConnection(live.stream, readCalls, requestId);
  }

  /// Simulates a message arriving from the other participant.
  void receive(String body, {String senderId = 'u-doc2', String role = 'doctor'}) {
    final m = ChatMessage(id: 'in${messages.length + 1}', requestId: 'rq1', senderUserId: senderId, senderRole: role,
        body: body, clientMessageId: 'c-in${messages.length + 1}', createdAt: DateTime.now());
    messages.add(m);
    live.add(ChatEvent(type: 'message', requestId: 'rq1', message: m));
  }
}

class _FakeConnection implements ChatConnection {
  final Stream<ChatEvent> _events;
  final List<String> _reads;
  final String _requestId;
  _FakeConnection(this._events, this._reads, this._requestId);
  @override
  Stream<ChatEvent> get events => _events;
  @override
  void markRead() => _reads.add('ws:$_requestId');
  @override
  Future<void> close() async {}
}

ChatMessage sampleMessage({String id = 'm1', bool mine = true, String body = 'Bună ziua, am o întrebare despre aluniță.', DateTime? at, bool read = false}) =>
    ChatMessage(id: id, requestId: 'rq1', senderUserId: mine ? patientUser.id : 'u-doc2', senderRole: mine ? 'patient' : 'doctor',
        body: body, clientMessageId: 'c-$id', createdAt: at ?? DateTime(2026, 5, 2, 10), readAt: read ? DateTime(2026, 5, 2, 11) : null);

class FakeNotificationRepository implements NotificationRepository {
  final List<AppNotification> items;
  final List<String> read = [];
  bool readAll = false;
  FakeNotificationRepository({List<AppNotification>? items}) : items = items ?? [];

  @override
  Future<Inbox> inbox() async => Inbox(items: List.of(items), unreadCount: items.where((n) => n.isUnread).length);
  @override
  Future<void> markRead(String id) async {
    read.add(id);
    final i = items.indexWhere((n) => n.id == id);
    if (i != -1) {
      final n = items[i];
      items[i] = AppNotification(id: n.id, type: n.type, title: n.title, body: n.body, resourceType: n.resourceType,
          resourceId: n.resourceId, readAt: DateTime.now(), createdAt: n.createdAt);
    }
  }
  @override
  Future<void> markAllRead() async => readAll = true;
  @override
  Future<void> registerDevice(String platform, String token) async {}
}

AppNotification sampleNotification({String id = 'n1', bool unread = true, String type = 'review.accepted'}) => AppNotification(
      id: id, type: type, title: 'Cererea ta a fost preluată', body: 'Un medic a preluat cererea ta de evaluare.',
      resourceType: 'review_request', resourceId: 'rq1', readAt: unread ? null : DateTime(2026, 5, 2, 12), createdAt: DateTime(2026, 5, 2, 12),
    );

class FakePrivacyRepository implements PrivacyRepository {
  final Map<String, String> status = {'service': 'granted', 'doctor_review': 'undecided', 'research': 'undecided', 'communications': 'undecided'};
  final List<String> granted = [];
  final List<String> withdrawn = [];
  final List<DataRequest> requests = [];
  int exports = 0;

  static const notices = {
    'service': ConsentNotice(purpose: 'service', version: '1.0', titleRo: 'Prelucrarea datelor pentru funcționarea aplicației', bodyRo: 'Datele contului și imaginile sunt prelucrate pentru funcțiile aplicației.', isMandatory: true),
    'doctor_review': ConsentNotice(purpose: 'doctor_review', version: '1.0', titleRo: 'Transmiterea datelor către un medic', bodyRo: 'La cererea ta, datele sunt transmise medicului.', isMandatory: false),
    'research': ConsentNotice(purpose: 'research', version: '1.0', titleRo: 'Utilizarea datelor în scop de cercetare', bodyRo: 'Opțional, datele pseudonimizate pot fi folosite pentru cercetare.', isMandatory: false),
    'communications': ConsentNotice(purpose: 'communications', version: '1.0', titleRo: 'Notificări', bodyRo: 'Primești notificări despre cererile tale.', isMandatory: false),
  };

  @override
  Future<List<ConsentState>> states() async => [
        for (final e in notices.entries)
          ConsentState(purpose: e.key, status: status[e.key]!, noticeVersion: status[e.key] == 'undecided' ? null : '1.0', notice: e.value, outdated: false),
      ];
  @override
  Future<void> grant(String purpose, String noticeVersion) async { granted.add(purpose); status[purpose] = 'granted'; }
  @override
  Future<void> withdraw(String purpose) async { withdrawn.add(purpose); status[purpose] = 'withdrawn'; }
  @override
  Future<List<DataRequest>> myRequests() async => List.of(requests);
  @override
  Future<DataRequest> openRequest(String type) async {
    final r = DataRequest(id: 'dr${requests.length + 1}', type: type, status: 'open', requestedAt: DateTime.now());
    requests.add(r);
    return r;
  }
  @override
  Future<Map<String, dynamic>> export() async { exports++; return {'account': {'email': patientUser.email}, 'lesions': []}; }
}

/// A request as the assigned doctor sees it (patient profile included).
ReviewRequest sampleRequest({String id = 'rq1', String status = ReviewStatus.pending, bool withReview = false}) => ReviewRequest(
      id: id, status: status, patientMessage: 'A crescut în ultimele luni și mă mâncărime.', submittedAt: DateTime(2026, 5, 2, 9),
      acceptedAt: status == ReviewStatus.pending ? null : DateTime(2026, 5, 2, 12),
      completedAt: status == ReviewStatus.completed ? DateTime(2026, 5, 3, 10) : null,
      scan: sampleScan().copyWith(latestPrediction: PredictionSummary(id: 'p1', status: 'completed', predictedClass: 1, predictedLabel: 'high_risk', modelVersion: 'model2', createdAt: DateTime(2026, 5, 1, 11))),
      lesion: const LesionRef(id: 'l1', label: 'Aluniță umăr drept foarte lungă denumire', siteLabelRo: 'Spate superior', bodySide: 'posterior', laterality: 'right', firstNoticedOn: '2024-06-01', symptoms: ['itching', 'growth'], notes: 'Pare mai mare decât luna trecută.'),
      patient: const PatientRef(userId: 'u-patient', firstName: 'Maria', lastName: 'Ionescu', age: 36, sex: 'female', fitzpatrickType: 2, historyMelanoma: 'no', familyHistorySkinCancer: 'unknown'),
      doctor: const DoctorRef(userId: 'u-doc2', firstName: 'Ana', lastName: 'Popescu', specialty: 'Dermatovenerologie', institution: 'Clinica de test'),
      latestReview: withReview
          ? MedicalReview(id: 'mr1', version: 1, clinicalImpression: 'Leziune pigmentară asimetrică, cu margini neregulate și policromie.', suspectedCategory: 'melanoma_suspected', certainty: 'moderate', recommendation: 'prompt_consultation', inPersonConsultationAdvised: true, provenance: 'image_based', additionalComments: 'Vă rog programați un consult în următoarele 2 săptămâni.', createdAt: DateTime(2026, 5, 3, 10))
          : null,
      events: [
        ReviewEvent(toStatus: ReviewStatus.pending, occurredAt: DateTime(2026, 5, 2, 9)),
        if (status != ReviewStatus.pending) ReviewEvent(fromStatus: ReviewStatus.pending, toStatus: ReviewStatus.accepted, actorRole: 'doctor', occurredAt: DateTime(2026, 5, 2, 12)),
        if (status == ReviewStatus.needsInfo) ReviewEvent(fromStatus: ReviewStatus.accepted, toStatus: ReviewStatus.needsInfo, actorRole: 'doctor', note: 'Te rog o fotografie cu o riglă lângă leziune.', occurredAt: DateTime(2026, 5, 2, 13)),
        if (status == ReviewStatus.completed) ReviewEvent(fromStatus: ReviewStatus.accepted, toStatus: ReviewStatus.completed, actorRole: 'doctor', note: 'assessment v1', occurredAt: DateTime(2026, 5, 3, 10)),
      ],
    );

/// ProviderScope with fake infrastructure for a given signed-in user
/// (null = guest). Riverpod 3 does not export its `Override` type, so the
/// list is built inline where its type is inferred.
Widget testScope(Widget child,
    {AuthUser? user, FakeAuthRepository? auth, FakeLesionRepository? lesions, FakeReviewRepository? reviews,
    FakeChatRepository? chat, FakeNotificationRepository? notifications, FakePrivacyRepository? privacy}) {
  return ProviderScope(
    overrides: [
      privacyRepositoryProvider.overrideWithValue(privacy ?? FakePrivacyRepository()),
      tokenStorageProvider.overrideWithValue(InMemoryTokenStorage(
          user == null ? null : const StoredTokens(accessToken: 'a', refreshToken: 'r'))),
      authRepositoryProvider.overrideWithValue(auth ?? FakeAuthRepository(current: user)),
      lesionRepositoryProvider.overrideWithValue(lesions ?? FakeLesionRepository()),
      reviewRepositoryProvider.overrideWithValue(reviews ?? FakeReviewRepository()),
      chatRepositoryProvider.overrideWithValue(chat ?? FakeChatRepository()),
      notificationRepositoryProvider.overrideWithValue(notifications ?? FakeNotificationRepository()),
    ],
    child: child,
  );
}

/// Wraps [screen] in a ProviderScope and a one-route GoRouter so widgets may
/// call `context.push/go` (navigation targets are not needed for layout).
Widget testApp(
  Widget screen, {
  AuthUser? user,
  FakeAuthRepository? auth,
  FakeLesionRepository? lesions,
  FakeReviewRepository? reviews,
  FakeChatRepository? chat,
  FakeNotificationRepository? notifications,
  FakePrivacyRepository? privacy,
  double textScale = 1.0,
}) {
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/login', builder: (_, __) => const Scaffold(body: Text('login-route'))),
    GoRoute(path: '/register', builder: (_, __) => const Scaffold(body: Text('register-route'))),
    GoRoute(path: '/claim', builder: (_, __) => const Scaffold(body: Text('claim-route'))),
    GoRoute(path: '/lesions/new', builder: (_, __) => const Scaffold(body: Text('new-lesion-route'))),
    GoRoute(path: '/lesions/:id', builder: (_, s) => Scaffold(body: Text('lesion-${s.pathParameters['id']}'))),
    GoRoute(path: '/scan/result', builder: (_, __) => const Scaffold(body: Text('scan-result-route'))),
    GoRoute(path: '/review-requests', builder: (_, __) => const Scaffold(body: Text('requests-route'))),
    GoRoute(path: '/review-requests/:id', builder: (_, s) => Scaffold(body: Text('request-${s.pathParameters['id']}'))),
    GoRoute(path: '/review-requests/:id/assess', builder: (_, s) => Scaffold(body: Text('assess-${s.pathParameters['id']}'))),
    GoRoute(path: '/review-requests/:id/chat', builder: (_, s) => Scaffold(body: Text('chat-${s.pathParameters['id']}'))),
    GoRoute(path: '/notifications', builder: (_, __) => const Scaffold(body: Text('notifications-route'))),
    GoRoute(path: '/privacy', builder: (_, __) => const Scaffold(body: Text('privacy-route'))),
  ]);
  return testScope(
    MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
    user: user,
    auth: auth,
    lesions: lesions,
    reviews: reviews,
    chat: chat,
    notifications: notifications,
    privacy: privacy,
  );
}
