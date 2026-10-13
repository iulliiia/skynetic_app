import 'package:skynetic_app/core/api/api_client.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/core/auth/token_storage.dart';
import 'package:skynetic_app/core/config/app_config.dart';

/// Talks to `/auth/*` and `/users/me`; persists tokens.
abstract class AuthRepository {
  Future<AuthUser> login(String email, String password);
  Future<AuthUser> registerPatient(String email, String password, PatientRegistration profile);
  Future<AuthUser> registerDoctor(String email, String password, DoctorRegistration profile);
  Future<AuthUser?> restoreSession();
  Future<void> logout();
}

class ApiAuthRepository implements AuthRepository {
  final ApiClient _client;
  final TokenStorage _storage;

  ApiAuthRepository(this._client, this._storage);

  @override
  Future<AuthUser> login(String email, String password) async {
    final res = await _client.postJson(
      '/auth/login',
      body: {'email': email.trim(), 'password': password},
      noAuth: true,
    );
    return _storeSession(res);
  }

  @override
  Future<AuthUser> registerPatient(String email, String password, PatientRegistration profile) =>
      _register(email, password, 'patient', {'patient': profile.toJson()});

  @override
  Future<AuthUser> registerDoctor(String email, String password, DoctorRegistration profile) =>
      _register(email, password, 'doctor', {'doctor': profile.toJson()});

  Future<AuthUser> _register(
      String email, String password, String role, Map<String, dynamic> profile) async {
    final res = await _client.postJson(
      '/auth/register',
      body: {
        'email': email.trim(),
        'password': password,
        'role': role,
        'service_notice_version': AppConfig.serviceNoticeVersion,
        ...profile,
      },
      noAuth: true,
    );
    return _storeSession(res);
  }

  Future<AuthUser> _storeSession(Map<String, dynamic> res) async {
    await _storage.write(StoredTokens.fromJson(res['tokens'] as Map<String, dynamic>));
    // Fetch the full profile so names/verification status are available.
    try {
      return await me();
    } catch (_) {
      return AuthUser.fromSession(res['user'] as Map<String, dynamic>);
    }
  }

  Future<AuthUser> me() async => AuthUser.fromMe(await _client.getJson('/users/me'));

  /// Returns the current user when stored tokens are still valid (the client
  /// refreshes transparently), null when signed out or the session is gone.
  @override
  Future<AuthUser?> restoreSession() async {
    if (await _storage.read() == null) return null;
    try {
      return await me();
    } catch (_) {
      // Network error: keep the tokens, report unknown; a 401 already
      // cleared them inside the client.
      return (await _storage.read()) == null ? null : _offlineUser;
    }
  }

  /// Placeholder returned when the server is unreachable but tokens exist:
  /// the app stays signed in and screens fetch data when the network is back.
  static const _offlineUser = AuthUser(id: '', email: '', role: UserRole.patient, status: 'active');

  @override
  Future<void> logout() async {
    final tokens = await _storage.read();
    await _storage.clear();
    if (tokens == null) return;
    try {
      await _client.postJson('/auth/logout', body: {'refresh_token': tokens.refreshToken}, noAuth: true);
    } catch (_) {
      // Local sign-out succeeded; the server token expires on its own.
    }
  }
}
