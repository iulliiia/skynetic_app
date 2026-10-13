import 'package:skynetic_app/features/lesions/prediction_models.dart';

/// Coded anatomical site from `GET /anatomical-sites`.
class AnatomicalSite {
  final String code;
  final String labelRo;
  final String? parentCode;
  final int sortOrder;

  const AnatomicalSite({
    required this.code,
    required this.labelRo,
    this.parentCode,
    required this.sortOrder,
  });

  bool get isTopLevel => parentCode == null;

  factory AnatomicalSite.fromJson(Map<String, dynamic> j) => AnatomicalSite(
        code: j['code'] as String,
        labelRo: j['label_ro'] as String,
        parentCode: j['parent_code'] as String?,
        sortOrder: (j['sort_order'] as num).toInt(),
      );
}

/// Vocabularies shared with the backend (CHECK constraints / validation).
class LesionVocab {
  const LesionVocab._();

  static const bodySides = {'anterior': 'Anterior (față)', 'posterior': 'Posterior (spate)'};
  static const lateralities = {'left': 'Stânga', 'right': 'Dreapta', 'midline': 'Centru'};
  static const symptoms = {
    'itching': 'Mâncărime',
    'bleeding': 'Sângerare',
    'pain': 'Durere',
    'growth': 'Creștere în dimensiune',
    'color_change': 'Schimbarea culorii',
    'shape_change': 'Schimbarea formei',
    'crusting': 'Cruste',
    'ulceration': 'Ulcerație',
    'other': 'Altceva',
  };
}

class Lesion {
  final String id;
  final String label;
  final String anatomicalSiteCode;
  final String anatomicalSiteLabel;
  final String? bodySide;
  final String? laterality;
  final String? firstNoticedOn; // YYYY-MM-DD
  final List<String> symptoms;
  final String? notes;
  final DateTime? archivedAt;
  final int scanCount;
  final DateTime? latestScanAt;
  final DateTime createdAt;

  const Lesion({
    required this.id,
    required this.label,
    required this.anatomicalSiteCode,
    required this.anatomicalSiteLabel,
    this.bodySide,
    this.laterality,
    this.firstNoticedOn,
    required this.symptoms,
    this.notes,
    this.archivedAt,
    required this.scanCount,
    this.latestScanAt,
    required this.createdAt,
  });

  bool get isArchived => archivedAt != null;

  /// "Spate superior · Posterior (spate) · Stânga"
  String get locationLabel => [
        anatomicalSiteLabel,
        if (bodySide != null) LesionVocab.bodySides[bodySide!],
        if (laterality != null) LesionVocab.lateralities[laterality!],
      ].whereType<String>().join(' · ');

  factory Lesion.fromJson(Map<String, dynamic> j) => Lesion(
        id: j['id'] as String,
        label: j['label'] as String,
        anatomicalSiteCode: j['anatomical_site_code'] as String,
        anatomicalSiteLabel: j['anatomical_site_label_ro'] as String? ?? '',
        bodySide: j['body_side'] as String?,
        laterality: j['laterality'] as String?,
        firstNoticedOn: j['first_noticed_on'] as String?,
        symptoms: (j['symptoms'] as List?)?.cast<String>() ?? const [],
        notes: j['notes'] as String?,
        archivedAt: _date(j['archived_at']),
        scanCount: (j['scan_count'] as num?)?.toInt() ?? 0,
        latestScanAt: _date(j['latest_scan_at']),
        createdAt: _date(j['created_at']) ?? DateTime.now(),
      );
}

/// Payload for create / patch.
class LesionInput {
  final String label;
  final String anatomicalSiteCode;
  final String? bodySide;
  final String? laterality;
  final String? firstNoticedOn;
  final List<String> symptoms;
  final String? notes;

  const LesionInput({
    required this.label,
    required this.anatomicalSiteCode,
    this.bodySide,
    this.laterality,
    this.firstNoticedOn,
    this.symptoms = const [],
    this.notes,
  });

  Map<String, dynamic> toJson() => {
        'label': label,
        'anatomical_site_code': anatomicalSiteCode,
        'body_side': bodySide ?? '',
        'laterality': laterality ?? '',
        'first_noticed_on': firstNoticedOn ?? '',
        'symptoms': symptoms,
        'notes': notes ?? '',
      };
}

/// Upload-time quality indicators (heuristics, not a clinical judgement).
class ScanQuality {
  final double blurScore;
  final List<String> warnings;
  final bool acceptable;

  const ScanQuality({required this.blurScore, required this.warnings, required this.acceptable});

  factory ScanQuality.fromJson(Map<String, dynamic>? j) => j == null
      ? const ScanQuality(blurScore: 0, warnings: [], acceptable: true)
      : ScanQuality(
          blurScore: (j['blur_score'] as num?)?.toDouble() ?? 0,
          warnings: (j['warnings'] as List?)?.cast<String>() ?? const [],
          acceptable: j['acceptable'] as bool? ?? true,
        );

  static const warningLabels = {
    'blurry': 'Imaginea pare neclară',
    'too_dark': 'Imaginea este prea întunecată',
    'overexposed': 'Imaginea este supraexpusă',
  };

  List<String> get warningMessages =>
      warnings.map((w) => warningLabels[w] ?? w).toList(growable: false);
}

class Scan {
  final String id;
  final String? lesionId;
  final String source;
  final DateTime? capturedAt;
  final String? patientNotes;
  final ScanQuality quality;
  final DateTime createdAt;
  final int? width;
  final int? height;
  final PredictionSummary? latestPrediction;

  const Scan({
    required this.id,
    this.lesionId,
    required this.source,
    this.capturedAt,
    this.patientNotes,
    required this.quality,
    required this.createdAt,
    this.width,
    this.height,
    this.latestPrediction,
  });

  DateTime get takenAt => capturedAt ?? createdAt;

  Scan copyWith({PredictionSummary? latestPrediction, String? lesionId}) => Scan(
        id: id, lesionId: lesionId ?? this.lesionId, source: source, capturedAt: capturedAt,
        patientNotes: patientNotes, quality: quality, createdAt: createdAt, width: width, height: height,
        latestPrediction: latestPrediction ?? this.latestPrediction,
      );

  factory Scan.fromJson(Map<String, dynamic> j) {
    final img = j['image'] as Map<String, dynamic>?;
    return Scan(
      id: j['id'] as String,
      lesionId: j['lesion_id'] as String?,
      source: j['source'] as String? ?? 'unknown',
      capturedAt: _date(j['captured_at']),
      patientNotes: j['patient_notes'] as String?,
      quality: ScanQuality.fromJson(j['quality'] as Map<String, dynamic>?),
      createdAt: _date(j['created_at']) ?? DateTime.now(),
      width: (img?['width'] as num?)?.toInt(),
      height: (img?['height'] as num?)?.toInt(),
      latestPrediction: j['latest_prediction'] is Map<String, dynamic>
          ? PredictionSummary.fromJson(j['latest_prediction'] as Map<String, dynamic>)
          : null,
    );
  }
}

/// Result of `POST /guest/scans`.
class GuestScan {
  final String scanId;
  final String claimToken;
  final DateTime expiresAt;
  final ScanQuality quality;

  const GuestScan({
    required this.scanId,
    required this.claimToken,
    required this.expiresAt,
    required this.quality,
  });

  factory GuestScan.fromJson(Map<String, dynamic> j) => GuestScan(
        scanId: j['scan_id'] as String,
        claimToken: j['claim_token'] as String,
        expiresAt: _date(j['expires_at']) ?? DateTime.now(),
        quality: ScanQuality.fromJson(j['quality'] as Map<String, dynamic>?),
      );
}

DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
