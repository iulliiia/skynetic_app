import 'package:flutter/material.dart';
import 'package:skynetic_app/features/lesions/lesion_models.dart';

/// Status vocabulary of a review request, with Romanian labels and colours.
class ReviewStatus {
  const ReviewStatus._();

  static const pending = 'pending';
  static const accepted = 'accepted';
  static const needsInfo = 'needs_info';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
  static const rejected = 'rejected';
  static const expired = 'expired';

  static const open = {pending, accepted, needsInfo};

  static const labelsRo = {
    pending: 'În așteptare',
    accepted: 'În evaluare',
    needsInfo: 'Informații necesare',
    completed: 'Finalizată',
    cancelled: 'Retrasă',
    rejected: 'Respinsă',
    expired: 'Expirată',
  };

  static String label(String s) => labelsRo[s] ?? s;

  static Color color(String s) {
    switch (s) {
      case pending:
        return Colors.orange;
      case accepted:
        return Colors.blue;
      case needsInfo:
        return Colors.deepPurple;
      case completed:
        return Colors.green;
      case rejected:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

/// Clinical vocabularies (mirror the backend CHECK constraints).
class ClinicalVocab {
  const ClinicalVocab._();

  static const suspectedCategories = {
    'benign_nevus': 'Nev benign',
    'seborrheic_keratosis': 'Keratoză seboreică',
    'dermatofibroma': 'Dermatofibrom',
    'vascular_lesion': 'Leziune vasculară',
    'actinic_keratosis': 'Keratoză actinică',
    'basal_cell_carcinoma': 'Carcinom bazocelular',
    'squamous_cell_carcinoma': 'Carcinom spinocelular',
    'melanoma_suspected': 'Suspiciune de melanom',
    'other_benign': 'Altă leziune benignă',
    'other_malignant_suspected': 'Altă suspiciune de malignitate',
    'no_lesion': 'Fără leziune',
    'indeterminate': 'Nedeterminat',
  };

  static const certainties = {'low': 'Scăzută', 'moderate': 'Moderată', 'high': 'Ridicată'};

  static const recommendations = {
    'no_action': 'Nu este necesară nicio acțiune',
    'self_monitor': 'Auto-monitorizare',
    'routine_consultation': 'Consult de rutină',
    'prompt_consultation': 'Consult în curând',
    'urgent_consultation': 'Consult urgent',
  };

  static const provenances = {
    'image_based': 'Evaluare pe baza imaginii',
    'clinical_exam': 'Examen clinic',
    'dermoscopy': 'Dermatoscopie',
    'histopathology': 'Histopatologie',
  };

  static const healthAnswers = {'yes': 'Da', 'no': 'Nu', 'unknown': 'Nu știu', 'prefer_not_to_say': 'Nu răspund'};
}

class LesionRef {
  final String id;
  final String label;
  final String siteLabelRo;
  final String? bodySide;
  final String? laterality;
  final String? firstNoticedOn;
  final List<String> symptoms;
  final String? notes;

  const LesionRef({
    required this.id,
    required this.label,
    required this.siteLabelRo,
    this.bodySide,
    this.laterality,
    this.firstNoticedOn,
    this.symptoms = const [],
    this.notes,
  });

  String get locationLabel => [
        siteLabelRo,
        if (bodySide != null) LesionVocab.bodySides[bodySide!],
        if (laterality != null) LesionVocab.lateralities[laterality!],
      ].whereType<String>().join(' · ');

  factory LesionRef.fromJson(Map<String, dynamic> j) => LesionRef(
        id: j['id'] as String,
        label: j['label'] as String,
        siteLabelRo: j['anatomical_site_label_ro'] as String? ?? '',
        bodySide: j['body_side'] as String?,
        laterality: j['laterality'] as String?,
        firstNoticedOn: j['first_noticed_on'] as String?,
        symptoms: (j['symptoms'] as List?)?.cast<String>() ?? const [],
        notes: j['notes'] as String?,
      );
}

/// What the assigned doctor sees about the patient.
class PatientRef {
  final String userId;
  final String firstName;
  final String lastName;
  final int? age;
  final String? sex;
  final int? fitzpatrickType;
  final String? historyMelanoma;
  final String? historyOtherSkinCancer;
  final String? familyHistorySkinCancer;
  final String? immunosuppression;
  final String? uvExposure;

  const PatientRef({
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.age,
    this.sex,
    this.fitzpatrickType,
    this.historyMelanoma,
    this.historyOtherSkinCancer,
    this.familyHistorySkinCancer,
    this.immunosuppression,
    this.uvExposure,
  });

  String get displayName => '$firstName $lastName';

  factory PatientRef.fromJson(Map<String, dynamic> j) => PatientRef(
        userId: j['user_id'] as String,
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        age: (j['age'] as num?)?.toInt(),
        sex: j['sex'] as String?,
        fitzpatrickType: (j['fitzpatrick_type'] as num?)?.toInt(),
        historyMelanoma: j['history_melanoma'] as String?,
        historyOtherSkinCancer: j['history_other_skin_cancer'] as String?,
        familyHistorySkinCancer: j['family_history_skin_cancer'] as String?,
        immunosuppression: j['immunosuppression'] as String?,
        uvExposure: j['uv_exposure'] as String?,
      );
}

class DoctorRef {
  final String userId;
  final String firstName;
  final String lastName;
  final String specialty;
  final String? institution;

  const DoctorRef({required this.userId, required this.firstName, required this.lastName, required this.specialty, this.institution});

  String get displayName => 'Dr. $firstName $lastName';

  factory DoctorRef.fromJson(Map<String, dynamic> j) => DoctorRef(
        userId: j['user_id'] as String,
        firstName: j['first_name'] as String? ?? '',
        lastName: j['last_name'] as String? ?? '',
        specialty: j['specialty'] as String? ?? '',
        institution: j['institution'] as String?,
      );
}

class ReviewEvent {
  final String? fromStatus;
  final String toStatus;
  final String? actorRole;
  final String? note;
  final DateTime occurredAt;

  const ReviewEvent({this.fromStatus, required this.toStatus, this.actorRole, this.note, required this.occurredAt});

  factory ReviewEvent.fromJson(Map<String, dynamic> j) => ReviewEvent(
        fromStatus: j['from_status'] as String?,
        toStatus: j['to_status'] as String,
        actorRole: j['actor_role'] as String?,
        note: j['note'] as String?,
        occurredAt: DateTime.tryParse(j['occurred_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

class MedicalReview {
  final String id;
  final int version;
  final String clinicalImpression;
  final String suspectedCategory;
  final String certainty;
  final String recommendation;
  final bool inPersonConsultationAdvised;
  final String provenance;
  final String? confirmedDiagnosis;
  final String? additionalComments;
  final DateTime createdAt;

  const MedicalReview({
    required this.id,
    required this.version,
    required this.clinicalImpression,
    required this.suspectedCategory,
    required this.certainty,
    required this.recommendation,
    required this.inPersonConsultationAdvised,
    required this.provenance,
    this.confirmedDiagnosis,
    this.additionalComments,
    required this.createdAt,
  });

  factory MedicalReview.fromJson(Map<String, dynamic> j) => MedicalReview(
        id: j['id'] as String,
        version: (j['version'] as num).toInt(),
        clinicalImpression: j['clinical_impression'] as String,
        suspectedCategory: j['suspected_category'] as String,
        certainty: j['certainty'] as String,
        recommendation: j['recommendation'] as String,
        inPersonConsultationAdvised: j['in_person_consultation_advised'] as bool? ?? false,
        provenance: j['provenance'] as String? ?? 'image_based',
        confirmedDiagnosis: j['confirmed_diagnosis'] as String?,
        additionalComments: j['additional_comments'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}

/// Assessment payload (doctor).
class AssessmentInput {
  final String clinicalImpression;
  final String suspectedCategory;
  final String certainty;
  final String recommendation;
  final bool inPersonConsultationAdvised;
  final String provenance;
  final String? confirmedDiagnosis;
  final String? additionalComments;

  const AssessmentInput({
    required this.clinicalImpression,
    required this.suspectedCategory,
    required this.certainty,
    required this.recommendation,
    required this.inPersonConsultationAdvised,
    this.provenance = 'image_based',
    this.confirmedDiagnosis,
    this.additionalComments,
  });

  Map<String, dynamic> toJson() => {
        'clinical_impression': clinicalImpression,
        'suspected_category': suspectedCategory,
        'certainty': certainty,
        'recommendation': recommendation,
        'in_person_consultation_advised': inPersonConsultationAdvised,
        'provenance': provenance,
        if (confirmedDiagnosis != null && confirmedDiagnosis!.isNotEmpty) 'confirmed_diagnosis': confirmedDiagnosis,
        if (additionalComments != null && additionalComments!.isNotEmpty) 'additional_comments': additionalComments,
      };
}

class ReviewRequest {
  final String id;
  final String status;
  final String? patientMessage;
  final DateTime submittedAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? closedAt;
  final Scan? scan;
  final LesionRef lesion;
  final PatientRef? patient;
  final DoctorRef? doctor;
  final MedicalReview? latestReview;
  final List<ReviewEvent> events;

  const ReviewRequest({
    required this.id,
    required this.status,
    this.patientMessage,
    required this.submittedAt,
    this.acceptedAt,
    this.completedAt,
    this.closedAt,
    this.scan,
    required this.lesion,
    this.patient,
    this.doctor,
    this.latestReview,
    this.events = const [],
  });

  bool get isOpen => ReviewStatus.open.contains(status);
  String get statusLabel => ReviewStatus.label(status);

  /// The reason a doctor gave when rejecting / asking for information.
  String? get latestNote {
    for (final e in events.reversed) {
      if (e.note != null && e.note!.isNotEmpty && !e.note!.startsWith('assessment v')) return e.note;
    }
    return null;
  }

  factory ReviewRequest.fromJson(Map<String, dynamic> j) => ReviewRequest(
        id: j['id'] as String,
        status: j['status'] as String,
        patientMessage: j['patient_message'] as String?,
        submittedAt: _date(j['submitted_at']) ?? DateTime.now(),
        acceptedAt: _date(j['accepted_at']),
        completedAt: _date(j['completed_at']),
        closedAt: _date(j['closed_at']),
        scan: j['scan'] is Map<String, dynamic> ? Scan.fromJson(j['scan'] as Map<String, dynamic>) : null,
        lesion: LesionRef.fromJson(j['lesion'] as Map<String, dynamic>),
        patient: j['patient'] is Map<String, dynamic> ? PatientRef.fromJson(j['patient'] as Map<String, dynamic>) : null,
        doctor: j['doctor'] is Map<String, dynamic> ? DoctorRef.fromJson(j['doctor'] as Map<String, dynamic>) : null,
        latestReview:
            j['latest_review'] is Map<String, dynamic> ? MedicalReview.fromJson(j['latest_review'] as Map<String, dynamic>) : null,
        events: (j['events'] as List?)?.cast<Map<String, dynamic>>().map(ReviewEvent.fromJson).toList() ?? const [],
      );
}

class DoctorDashboard {
  final int pending;
  final int accepted;
  final int needsInfo;
  final int completed;
  final int unreadNotifications;

  const DoctorDashboard({
    required this.pending,
    required this.accepted,
    required this.needsInfo,
    required this.completed,
    required this.unreadNotifications,
  });

  factory DoctorDashboard.fromJson(Map<String, dynamic> j) => DoctorDashboard(
        pending: (j['pending'] as num?)?.toInt() ?? 0,
        accepted: (j['accepted'] as num?)?.toInt() ?? 0,
        needsInfo: (j['needs_info'] as num?)?.toInt() ?? 0,
        completed: (j['completed'] as num?)?.toInt() ?? 0,
        unreadNotifications: (j['unread_notifications'] as num?)?.toInt() ?? 0,
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
