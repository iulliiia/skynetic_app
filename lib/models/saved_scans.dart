import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedScan {
  final String imagePath;
  final int classId;
  final String locationLabel; // Ex: "Anterior - Stânga - Cap - Scalp"
  final String uniqueTag;
  final String bodySide; // 'Anterior' sau 'Posterior'
  final String lateralSide; // 'Stânga', 'Dreapta', 'Centru'
  final String bodyPart; // Regiunea principală
  final String? subBodyPart; // Detaliu regiunii (ex: Scalp, Frunte, etc.)
  final String? notes;
  final DateTime scanDate;

  SavedScan({
    required this.imagePath,
    required this.classId,
    required this.locationLabel,
    required this.uniqueTag,
    required this.bodySide,
    required this.lateralSide,
    required this.bodyPart,
    this.subBodyPart,
    this.notes,
    required this.scanDate,
  });

  SavedScan copyWith({String? imagePath}) {
    return SavedScan(
      imagePath: imagePath ?? this.imagePath,
      classId: classId,
      locationLabel: locationLabel,
      uniqueTag: uniqueTag,
      bodySide: bodySide,
      lateralSide: lateralSide,
      bodyPart: bodyPart,
      subBodyPart: subBodyPart,
      notes: notes,
      scanDate: scanDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'imagePath': imagePath,
      'classId': classId,
      'locationLabel': locationLabel,
      'uniqueTag': uniqueTag,
      'bodySide': bodySide,
      'lateralSide': lateralSide,
      'bodyPart': bodyPart,
      'subBodyPart': subBodyPart,
      'notes': notes,
      'scanDate': scanDate.toIso8601String(),
    };
  }

  factory SavedScan.fromJson(Map<String, dynamic> json) {
    return SavedScan(
      imagePath: json['imagePath'],
      classId: json['classId'],
      locationLabel: json['locationLabel'],
      uniqueTag: json['uniqueTag'],
      // older versions saved 'Posterior ' with a trailing space
      bodySide: (json['bodySide'] as String).trim(),
      lateralSide: json['lateralSide'],
      bodyPart: json['bodyPart'],
      subBodyPart: json['subBodyPart'],
      notes: json['notes'],
      scanDate: DateTime.parse(json['scanDate']),
    );
  }
}

class SavedScans {
  static const _storageKey = 'saved_scans_v3';
  static const _imagesDirName = 'scans';
  static List<SavedScan> list = [];

  static Future<Directory?> _imagesDir() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final dir = Directory('${docs.path}/$_imagesDirName');
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    } catch (_) {
      // path_provider is unavailable (e.g. in widget tests)
      return null;
    }
  }

  /// Copies a picked/cropped image (which lives in a temporary cache folder
  /// the OS may clear) into the app's documents folder and returns the new
  /// path.
  static Future<String> persistImage(String sourcePath) async {
    final dir = await _imagesDir();
    if (dir == null) return sourcePath;
    final extension =
        sourcePath.contains('.') ? sourcePath.split('.').last : 'jpg';
    final target =
        '${dir.path}/scan_${DateTime.now().millisecondsSinceEpoch}.$extension';
    await File(sourcePath).copy(target);
    return target;
  }

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];
    final scans = saved.map((e) => SavedScan.fromJson(jsonDecode(e))).toList();

    // On iOS the app's container path changes between installs/updates, so
    // re-point images that were moved together with the documents folder.
    final dir = await _imagesDir();
    if (dir != null) {
      for (var i = 0; i < scans.length; i++) {
        final path = scans[i].imagePath;
        if (File(path).existsSync()) continue;
        final relocated = '${dir.path}/${path.split('/').last}';
        if (File(relocated).existsSync()) {
          scans[i] = scans[i].copyWith(imagePath: relocated);
        }
      }
    }
    list = scans;
  }

  static Future<void> save(SavedScan scan) async {
    list.add(scan);
    await _persist();
  }

  static Future<void> remove(SavedScan scan) async {
    list.remove(scan);
    final file = File(scan.imagePath);
    final dir = await _imagesDir();
    if (dir != null && scan.imagePath.startsWith(dir.path)) {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
    await _persist();
  }

  static Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final encodedList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encodedList);
  }

  static List<String> getDistinctLocations() {
    return list.map((e) => e.locationLabel).toSet().toList();
  }
}
