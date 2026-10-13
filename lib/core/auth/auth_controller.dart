import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/core/auth/auth_repository.dart';
import 'package:skynetic_app/core/providers.dart';

enum AuthStatus { loading, guest, authenticated }

/// Who is using the app right now.
class AuthState {
  final AuthStatus status;
  final AuthUser? user;

  const AuthState._(this.status, this.user);

  const AuthState.loading() : this._(AuthStatus.loading, null);
  const AuthState.guest() : this._(AuthStatus.guest, null);
  const AuthState.authenticated(AuthUser user) : this._(AuthStatus.authenticated, user);

  bool get isLoading => status == AuthStatus.loading;
  bool get isGuest => status == AuthStatus.guest;
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isPatient => user?.role == UserRole.patient;
  bool get isDoctor => user?.role == UserRole.doctor;
  bool get isAdmin => user?.role == UserRole.admin;
}

/// Restores the session on start and exposes login/register/logout.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Let the API client tell us when a refresh was rejected. The notifier is
    // captured here because ref must not be used inside onDispose.
    final expired = ref.read(sessionExpiredProvider);
    expired.addListener(_onSessionExpired);
    ref.onDispose(() => expired.removeListener(_onSessionExpired));
    Future.microtask(restore);
    return const AuthState.loading();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  void _onSessionExpired() {
    if (state.isAuthenticated) state = const AuthState.guest();
  }

  Future<void> restore() async {
    try {
      final user = await _repo.restoreSession();
      state = user == null ? const AuthState.guest() : AuthState.authenticated(user);
    } catch (_) {
      state = const AuthState.guest();
    }
  }

  Future<void> login(String email, String password) async {
    final user = await _repo.login(email, password);
    state = AuthState.authenticated(user);
  }

  Future<void> registerPatient(String email, String password, PatientRegistration profile) async {
    final user = await _repo.registerPatient(email, password, profile);
    state = AuthState.authenticated(user);
  }

  Future<void> registerDoctor(String email, String password, DoctorRegistration profile) async {
    final user = await _repo.registerDoctor(email, password, profile);
    state = AuthState.authenticated(user);
  }

  /// Re-reads `/users/me` (e.g. after a doctor was approved).
  Future<void> refreshUser() async {
    final user = await _repo.restoreSession();
    if (user != null) state = AuthState.authenticated(user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState.guest();
  }
}

final authControllerProvider = NotifierProvider<AuthController, AuthState>(AuthController.new);
