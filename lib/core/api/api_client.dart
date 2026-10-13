import 'dart:async';

import 'package:dio/dio.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/core/auth/token_storage.dart';

/// Dio wrapper for the platform API.
///
/// * attaches the access token to every request,
/// * on 401 refreshes the session once (single-flight) and retries,
/// * converts every failure into [ApiException],
/// * tells [onSessionExpired] when a refresh is rejected so the auth state
///   can fall back to guest.
class ApiClient {
  final Dio _dio;
  final TokenStorage _storage;
  final String baseUrl;
  final void Function()? onSessionExpired;

  Future<bool>? _refreshing;

  ApiClient({
    required this.baseUrl,
    required TokenStorage storage,
    this.onSessionExpired,
    Dio? dio,
  })  : _storage = storage,
        _dio = dio ??
            Dio(BaseOptions(
              baseUrl: '$baseUrl/api/v1',
              connectTimeout: const Duration(seconds: 10),
              sendTimeout: const Duration(seconds: 60),
              receiveTimeout: const Duration(seconds: 60),
              headers: {'Accept': 'application/json'},
            )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        if (options.extra['noAuth'] != true) {
          final tokens = await _storage.read();
          if (tokens != null) {
            options.headers['Authorization'] = 'Bearer ${tokens.accessToken}';
          }
        }
        handler.next(options);
      },
      onError: (err, handler) async {
        final isAuthRoute = err.requestOptions.path.startsWith('/auth/');
        final alreadyRetried = err.requestOptions.extra['retried'] == true;
        if (err.response?.statusCode == 401 && !isAuthRoute && !alreadyRetried) {
          final ok = await _refreshSession();
          if (ok) {
            try {
              final opts = err.requestOptions..extra['retried'] = true;
              final tokens = await _storage.read();
              opts.headers['Authorization'] = 'Bearer ${tokens?.accessToken}';
              final response = await _dio.fetch(opts);
              return handler.resolve(response);
            } on DioException catch (retryErr) {
              return handler.next(retryErr);
            }
          }
        }
        handler.next(err);
      },
    ));
  }

  Dio get dio => _dio;

  /// Refreshes once even when several requests fail at the same time.
  Future<bool> _refreshSession() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<bool> _doRefresh() async {
    final tokens = await _storage.read();
    if (tokens == null) return false;
    try {
      final res = await _dio.post(
        '/auth/refresh',
        data: {'refresh_token': tokens.refreshToken},
        options: Options(extra: {'noAuth': true}),
      );
      final pair = StoredTokens.fromJson(res.data['tokens'] as Map<String, dynamic>);
      await _storage.write(pair);
      return true;
    } on DioException {
      await _storage.clear();
      onSessionExpired?.call();
      return false;
    }
  }

  /// Runs a request and maps failures to [ApiException].
  Future<T> call<T>(Future<Response<T>> Function(Dio dio) request) async {
    try {
      final res = await request(_dio);
      return res.data as T;
    } on DioException catch (err) {
      throw ApiException.fromDio(err, baseUrl: baseUrl);
    }
  }

  Future<Map<String, dynamic>> getJson(String path, {Map<String, dynamic>? query}) =>
      call<Map<String, dynamic>>((d) => d.get(path, queryParameters: query));

  Future<Map<String, dynamic>> postJson(String path, {Object? body, bool noAuth = false}) =>
      call<Map<String, dynamic>>(
          (d) => d.post(path, data: body, options: Options(extra: {'noAuth': noAuth})));

  Future<Map<String, dynamic>> patchJson(String path, {Object? body}) =>
      call<Map<String, dynamic>>((d) => d.patch(path, data: body));

  Future<void> delete(String path) => call<dynamic>((d) => d.delete(path));

  /// Downloads a protected binary (scan image) with the Bearer token.
  Future<List<int>> getBytes(String path, {Map<String, String>? headers}) async {
    final data = await call<List<int>>((d) => d.get<List<int>>(
          path,
          options: Options(responseType: ResponseType.bytes, headers: headers),
        ));
    return data;
  }
}
