import 'package:flutter/material.dart';

/// Class ids of the current 3-class model. Index 3 is a client-side
/// pseudo-class for inconclusive results (never produced by the model).
class PredictionClasses {
  const PredictionClasses._();

  static const inconclusive = 3;

  static const labelsRo = <int, String>{
    0: 'Grad de risc scăzut',
    1: 'Grad de risc crescut',
    2: 'Piele curată (nicio leziune detectată)',
    inconclusive: 'Rezultat neconcludent',
  };

  static const shortLabelsRo = <int, String>{
    0: 'Risc scăzut',
    1: 'Risc crescut',
    2: 'Piele curată',
    inconclusive: 'Neconcludent',
  };

  static Color color(int classId) {
    switch (classId) {
      case 0:
        return Colors.green;
      case 1:
        return Colors.red;
      case 2:
        return Colors.teal;
      default:
        return Colors.blueGrey;
    }
  }
}

/// One inference attempt (`POST /scans/{id}/analyze`).
class Prediction {
  final String id;
  final String scanId;
  final String status; // completed | inconclusive | failed
  final int? predictedClass;
  final String? predictedLabel;
  final List<double> scores;
  final double? topMargin;
  final String modelName;
  final String modelVersion;
  final int? inferenceMs;
  final String? errorMessage;
  final DateTime createdAt;

  const Prediction({
    required this.id,
    required this.scanId,
    required this.status,
    this.predictedClass,
    this.predictedLabel,
    this.scores = const [],
    this.topMargin,
    required this.modelName,
    required this.modelVersion,
    this.inferenceMs,
    this.errorMessage,
    required this.createdAt,
  });

  bool get isInconclusive => status == 'inconclusive';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';

  /// Class id to display: the model's class, or the inconclusive pseudo-class.
  int get displayClassId => isCompleted && predictedClass != null ? predictedClass! : PredictionClasses.inconclusive;

  /// Highest raw score (softmax output; not a calibrated probability).
  double? get topScore => scores.isEmpty ? null : scores.reduce((a, b) => a > b ? a : b);

  factory Prediction.fromJson(Map<String, dynamic> j) {
    final model = j['model'] as Map<String, dynamic>? ?? const {};
    return Prediction(
      id: j['id'] as String,
      scanId: j['scan_id'] as String,
      status: j['status'] as String,
      predictedClass: (j['predicted_class'] as num?)?.toInt(),
      predictedLabel: j['predicted_label'] as String?,
      scores: (j['scores'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [],
      topMargin: (j['top_margin'] as num?)?.toDouble(),
      modelName: model['name'] as String? ?? '',
      modelVersion: model['version'] as String? ?? '',
      inferenceMs: (j['inference_ms'] as num?)?.toInt(),
      errorMessage: j['error_message'] as String?,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Latest successful result embedded in scan responses.
class PredictionSummary {
  final String id;
  final String status;
  final int? predictedClass;
  final String? predictedLabel;
  final String modelVersion;
  final DateTime createdAt;

  const PredictionSummary({
    required this.id,
    required this.status,
    this.predictedClass,
    this.predictedLabel,
    required this.modelVersion,
    required this.createdAt,
  });

  bool get isInconclusive => status == 'inconclusive';
  int get displayClassId =>
      status == 'completed' && predictedClass != null ? predictedClass! : PredictionClasses.inconclusive;
  String get shortLabelRo => PredictionClasses.shortLabelsRo[displayClassId] ?? status;

  factory PredictionSummary.fromJson(Map<String, dynamic> j) => PredictionSummary(
        id: j['id'] as String,
        status: j['status'] as String,
        predictedClass: (j['predicted_class'] as num?)?.toInt(),
        predictedLabel: j['predicted_label'] as String?,
        modelVersion: j['model_version'] as String? ?? '',
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal() ?? DateTime.now(),
      );
}
