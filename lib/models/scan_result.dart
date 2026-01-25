class ScanResult {
  final int classId;
  final double confidence;

  const ScanResult({required this.classId, required this.confidence});

  factory ScanResult.fromJson(Map<String, dynamic> json) {
    return ScanResult(
      classId: json['predicted_class_id'] as int,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

final classes = <int, String>{
  0: 'Grad de risc scăzut',
  1: 'Grad de risc crescut',
  2: 'Piele curată (nicio leziune detectată)',
};
