// 📁 saved_scans.dart
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SavedScan {
  final String imagePath;
  final int classId;

  SavedScan({required this.imagePath, required this.classId});

  Map<String, dynamic> toJson() => {
        'imagePath': imagePath,
        'classId': classId,
      };

  factory SavedScan.fromJson(Map<String, dynamic> json) => SavedScan(
        imagePath: json['imagePath'],
        classId: json['classId'],
      );
}

class SavedScans {
  static const _storageKey = 'saved_scans_v2';
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
}
