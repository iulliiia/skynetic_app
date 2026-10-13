import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/features/auth/login_screen.dart';
import 'package:skynetic_app/features/auth/register_screen.dart';
import 'package:skynetic_app/features/doctor/doctor_home_screen.dart';
import 'package:skynetic_app/features/guest/claim_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_form_screen.dart';
import 'package:skynetic_app/features/chat/chat_screen.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
import 'package:skynetic_app/features/privacy/privacy.dart';
import 'package:skynetic_app/features/review/assessment_form_screen.dart';
import 'package:skynetic_app/features/review/my_requests_screen.dart';
import 'package:skynetic_app/features/review/request_detail_screen.dart';
import 'package:skynetic_app/screens/home_screen.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_screen.dart';
import 'package:skynetic_app/screens/scan_result_screen.dart';
import 'package:skynetic_app/theme/app_theme.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

/// Route table + role-based redirects. The router rebuilds its redirect
/// decision whenever the auth state changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, __) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) => _redirect(ref.read(authControllerProvider), state.matchedLocation),
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
        path: '/login',
        builder: (_, state) => LoginScreen(next: state.uri.queryParameters['next']),
      ),
      GoRoute(
        path: '/register',
        builder: (_, state) => RegisterScreen(
          initialRole: state.uri.queryParameters['role'],
          next: state.uri.queryParameters['next'],
        ),
      ),
      GoRoute(path: '/doctor', builder: (_, __) => const DoctorHomeScreen()),
      GoRoute(path: '/review-requests', builder: (_, __) => const MyRequestsScreen()),
      GoRoute(
        path: '/review-requests/:id',
        builder: (_, state) => RequestDetailScreen(requestId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'assess',
            builder: (_, state) => AssessmentFormScreen(requestId: state.pathParameters['id']!),
          ),
          GoRoute(
            path: 'chat',
            builder: (_, state) => ChatScreen(requestId: state.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(path: '/notifications', builder: (_, __) => const NotificationsScreen()),
      GoRoute(path: '/privacy', builder: (_, __) => const PrivacyScreen()),
      GoRoute(path: '/claim', builder: (_, __) => const ClaimScreen()),
      GoRoute(path: '/lesions/new', builder: (_, __) => const LesionFormScreen()),
      GoRoute(
        path: '/lesions/:id',
        builder: (_, state) => LesionDetailScreen(lesionId: state.pathParameters['id']!),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (_, state) => LesionFormScreen(lesionId: state.pathParameters['id']),
          ),
        ],
      ),
      GoRoute(
        path: '/scan/result',
        builder: (_, state) {
          final args = state.extra as ScanResultArgs?;
          if (args == null) return const HomeScreen();
          return ScanResultScreen(imageFile: args.imageFile, lesionId: args.lesionId);
        },
      ),
    ],
  );
});

/// Arguments for `/scan/result`, passed via `extra`.
class ScanResultArgs {
  final XFile imageFile;
  final String? lesionId;
  const ScanResultArgs(this.imageFile, {this.lesionId});
}

/// Pure redirect logic (unit-tested).
String? _redirect(AuthState auth, String location) {
  if (auth.isLoading) return location == '/splash' ? null : '/splash';
  if (location == '/splash') return '/';

  final isAuthScreen = location == '/login' || location == '/register';
  if (auth.isDoctor || auth.isAdmin) {
    // Doctors and admins have no patient surface in the app; doctors work in
    // the doctor area and on the review requests assigned to them.
    final allowed = location.startsWith('/doctor') ||
        location.startsWith('/review-requests') ||
        location == '/notifications' ||
        location == '/privacy';
    return allowed ? null : '/doctor';
  }
  if (location.startsWith('/doctor')) return '/';
  if (auth.isAuthenticated && isAuthScreen) return '/';

  if (auth.isGuest) {
    if (!SharedPrefs.isOnboardingCompleted() && location != '/onboarding' && !isAuthScreen) {
      return '/onboarding';
    }
    final patientOnly = location.startsWith('/lesions') ||
        location == '/claim' ||
        location.startsWith('/review-requests') ||
        location == '/notifications' ||
        location == '/privacy';
    if (patientOnly) return '/login?next=${Uri.encodeComponent(location)}';
  } else if (location == '/onboarding') {
    return '/';
  }
  return null;
}

/// Exposed for tests.
String? redirectFor(AuthState auth, String location) => _redirect(auth, location);

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image(image: AssetImage('assets/images/skynetic_logo.png'), height: 96),
            SizedBox(height: 24),
            CircularProgressIndicator(color: AppColors.accent2),
          ],
        ),
      ),
    );
  }
}
