import 'dart:developer';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/models/scan_result.dart';

class Api {
  static final Api _instance = Api._internal();

  factory Api() => _instance;

  late final Dio _dio;

  // Private constructor
  Api._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl:
            kDebugMode ? 'http://10.0.2.2:5000' : 'http://192.168.1.230:5000',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );
  }

  Future<ScanResult> predictImage(XFile img) async {
    final file = await MultipartFile.fromFile(img.path, filename: img.name);

    final formData = FormData.fromMap({
      'image': file,
    });

    final response = await _dio.post(
      '/predict',
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
      ),
    );

    log(response.data.toString());

    return ScanResult.fromJson(response.data as Map<String, dynamic>);
  }
}
