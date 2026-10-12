import 'dart:developer';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/models/scan_result.dart';

/// Error shown to the user when a prediction request fails.
class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

class Api {
  static final Api _instance = Api._internal();

  factory Api() => _instance;

  late final Dio _dio;

  /// Backend address. Override it when running the app, e.g. on a physical
  /// phone connected to the same Wi-Fi as the computer running the backend:
  ///   flutter run --dart-define=API_URL=http://192.168.1.230:5001
  static const String _apiUrlOverride = String.fromEnvironment('API_URL');

  static String get baseUrl {
    if (_apiUrlOverride.isNotEmpty) return _apiUrlOverride;
    if (kReleaseMode) return 'https://eldie.ro/api/v1/skynetic';
    // The Android emulator reaches the host machine through 10.0.2.2,
    // the iOS simulator through localhost.
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:5001';
    return 'http://localhost:5001';
  }

  // Private constructor
  Api._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 30),
        // the first prediction after the server starts can take a while
        receiveTimeout: const Duration(seconds: 60),
      ),
    );
  }

  Future<ScanResult> predictImage(XFile img) async {
    final file = await MultipartFile.fromFile(img.path, filename: img.name);

    final formData = FormData.fromMap({
      'image': file,
    });

    try {
      final response = await _dio.post(
        '/predict',
        data: formData,
      );

      log(response.data.toString());

      return ScanResult.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (err) {
      log('predictImage failed: $err');
      throw ApiException(_messageFor(err));
    }
  }

  String _messageFor(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return 'Nu s-a putut realiza conexiunea cu serverul de analiză ($baseUrl). '
            'Verifică dacă serverul este pornit și dacă telefonul are acces la el.';
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Serverul a răspuns prea greu. Încearcă din nou.';
      case DioExceptionType.badResponse:
        final data = err.response?.data;
        final serverError =
            data is Map && data['error'] != null ? ' (${data['error']})' : '';
        return 'Serverul nu a putut analiza imaginea$serverError.';
      default:
        return 'A apărut o eroare neașteptată. Încearcă din nou.';
    }
  }
}
