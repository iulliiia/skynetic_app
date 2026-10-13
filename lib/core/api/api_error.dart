import 'package:dio/dio.dart';

/// Error raised by API calls. Mirrors the backend envelope
/// `{"error": {"code", "message", "details"}}` and adds network failures.
class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  final Map<String, String> details;

  const ApiException({
    required this.code,
    required this.message,
    this.statusCode,
    this.details = const {},
  });

  bool get isNetwork => code == 'network_error';
  bool get isUnauthorized => statusCode == 401;

  /// Builds a user-facing exception from a Dio failure.
  factory ApiException.fromDio(DioException err, {required String baseUrl}) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return ApiException(
          code: 'network_error',
          message:
              'Nu s-a putut realiza conexiunea cu serverul ($baseUrl). Verifică conexiunea și dacă serverul este pornit.',
        );
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          code: 'timeout',
          message: 'Serverul a răspuns prea greu. Încearcă din nou.',
        );
      case DioExceptionType.badResponse:
        final data = err.response?.data;
        if (data is Map && data['error'] is Map) {
          final e = data['error'] as Map;
          final rawDetails = e['details'];
          return ApiException(
            code: e['code']?.toString() ?? 'error',
            message: _translate(e['code']?.toString(), e['message']?.toString()),
            statusCode: err.response?.statusCode,
            details: rawDetails is Map
                ? rawDetails.map((k, v) => MapEntry(k.toString(), v.toString()))
                : const {},
          );
        }
        return ApiException(
          code: 'http_${err.response?.statusCode}',
          message: 'Serverul a returnat o eroare (${err.response?.statusCode}).',
          statusCode: err.response?.statusCode,
        );
      case DioExceptionType.cancel:
        return const ApiException(code: 'cancelled', message: 'Cererea a fost anulată.');
      default:
        return const ApiException(
          code: 'unknown',
          message: 'A apărut o eroare neașteptată. Încearcă din nou.',
        );
    }
  }

  /// Romanian copy for the backend's error codes; falls back to the server
  /// message (English) so nothing is swallowed.
  static String _translate(String? code, String? fallback) {
    const ro = <String, String>{
      'invalid_credentials': 'Email sau parolă incorecte.',
      'email_taken': 'Există deja un cont cu această adresă de email.',
      'account_suspended': 'Contul este suspendat. Contactează administratorul.',
      'account_closed': 'Contul este închis.',
      'invalid_refresh_token': 'Sesiunea a expirat. Autentifică-te din nou.',
      'unauthorized': 'Trebuie să fii autentificat.',
      'forbidden': 'Nu ai permisiunea pentru această acțiune.',
      'not_found': 'Resursa nu a fost găsită.',
      'validation_failed': 'Unele câmpuri nu sunt valide.',
      'rate_limited': 'Prea multe încercări. Așteaptă puțin și reîncearcă.',
      'payload_too_large': 'Imaginea este prea mare (maximum 10 MB).',
      'unsupported_image': 'Sunt acceptate doar imagini JPEG sau PNG.',
      'image_too_small': 'Imaginea este prea mică (minimum 224×224 pixeli).',
      'image_corrupt': 'Imaginea nu a putut fi citită.',
      'claim_invalid': 'Scanarea nu a fost găsită, a expirat sau a fost deja asociată unui cont.',
      'scan_in_use': 'Scanarea face parte dintr-o evaluare medicală și nu poate fi ștearsă.',
      'doctor_not_verified': 'Contul de medic nu a fost încă aprobat.',
      'service_unavailable': 'Un serviciu este momentan indisponibil. Încearcă mai târziu.',
    };
    return ro[code] ?? fallback ?? 'A apărut o eroare.';
  }

  @override
  String toString() => message;
}
