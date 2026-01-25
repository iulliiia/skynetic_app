import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SavedScan {
  final String imagePath;
  final int classId;
  final String locationLabel; // Ex: "Anterior (Față) - Stânga - Cap - Scalp"
  final String uniqueTag;
  final String bodySide; // 'Anterior (Față)' sau 'Posterior (Spate)'
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
      bodySide: json['bodySide'],
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
  static List<SavedScan> list = [];

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_storageKey) ?? [];
    list = saved.map((e) => SavedScan.fromJson(jsonDecode(e))).toList();
  }

  static Future<void> save(SavedScan scan) async {
    final prefs = await SharedPreferences.getInstance();
    list.add(scan);
    final encodedList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encodedList);
  }

  static Future<void> remove(SavedScan scan) async {
    final prefs = await SharedPreferences.getInstance();
    list.remove(scan);
    final encodedList = list.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_storageKey, encodedList);
  }

  static List<String> getDistinctLocations() {
    return list.map((e) => e.locationLabel).toSet().toList();
  }
}
