import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/features/auth/login_screen.dart';
import 'package:skynetic_app/features/doctor/doctor_home_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart';
import 'package:skynetic_app/main.dart';
import 'package:skynetic_app/screens/home_screen.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_screen.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() {
    installTestLocalStorage();
    return initializeDateFormatting('ro_RO', null);
  });

  Future<void> prefs({bool onboarded = true}) async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': onboarded});
    await SharedPrefs.init();
  }

  group('redirect rules', () {
    setUp(() => prefs());

    test('loading goes to splash and nowhere else', () {
      expect(redirectFor(const AuthState.loading(), '/'), '/splash');
      expect(redirectFor(const AuthState.loading(), '/splash'), isNull);
    });

    test('guest can browse but not patient-only routes', () {
      const guest = AuthState.guest();
      expect(redirectFor(guest, '/'), isNull);
      expect(redirectFor(guest, '/login'), isNull);
      expect(redirectFor(guest, '/lesions/abc'), '/login?next=%2Flesions%2Fabc');
      expect(redirectFor(guest, '/claim'), '/login?next=%2Fclaim');
      expect(redirectFor(guest, '/doctor'), '/');
    });

    test('guest without onboarding is sent to onboarding first', () async {
      await prefs(onboarded: false);
      expect(redirectFor(const AuthState.guest(), '/'), '/onboarding');
      expect(redirectFor(const AuthState.guest(), '/login'), isNull, reason: 'auth screens stay reachable');
    });

    test('patient is kept off auth screens and doctor area', () {
      const patient = AuthState.authenticated(patientUser);
      expect(redirectFor(patient, '/'), isNull);
      expect(redirectFor(patient, '/lesions/abc'), isNull);
      expect(redirectFor(patient, '/login'), '/');
      expect(redirectFor(patient, '/register'), '/');
      expect(redirectFor(patient, '/doctor'), '/');
      expect(redirectFor(patient, '/onboarding'), '/');
    });

    test('doctor only sees the doctor area', () {
      const doc = AuthState.authenticated(pendingDoctor);
      expect(redirectFor(doc, '/doctor'), isNull);
      expect(redirectFor(doc, '/'), '/doctor');
      expect(redirectFor(doc, '/lesions/abc'), '/doctor');
      expect(redirectFor(doc, '/login'), '/doctor');
    });
  });

  group('app wiring', () {
    testWidgets('guest without onboarding starts on onboarding', (tester) async {
      await prefs(onboarded: false);
      await tester.pumpWidget(testScope(const SkyneticApp()));
      await tester.pumpAndSettle();
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });

    testWidgets('guest lands on home', (tester) async {
      await prefs();
      await tester.pumpWidget(testScope(const SkyneticApp()));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.text('Cont'), findsOneWidget, reason: 'guest sees the sign-in button');
    });

    testWidgets('restored patient session shows the patient home', (tester) async {
      await prefs();
      final lesions = FakeLesionRepository(lesions: [sampleLesion()]);
      await tester.pumpWidget(testScope(const SkyneticApp(), user: patientUser, lesions: lesions));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Bine ai venit, Maria'), findsOneWidget);
      expect(find.text('Leziunile mele'), findsOneWidget);
      expect(find.textContaining('Aluniță umăr drept'), findsOneWidget);

      // Tapping a lesion opens its detail route.
      await tester.ensureVisible(find.textContaining('Aluniță umăr drept').first);
      await tester.tap(find.textContaining('Aluniță umăr drept').first);
      await tester.pumpAndSettle();
      expect(find.byType(LesionDetailScreen), findsOneWidget);
    });

    testWidgets('doctor session is routed to the doctor home', (tester) async {
      await prefs();
      await tester.pumpWidget(testScope(const SkyneticApp(), user: pendingDoctor));
      await tester.pumpAndSettle();
      expect(find.byType(DoctorHomeScreen), findsOneWidget);
      expect(find.text('În curs de verificare'), findsOneWidget);
    });

    testWidgets('guest tapping the account button reaches login; logout returns to guest', (tester) async {
      await prefs();
      final auth = FakeAuthRepository();
      await tester.pumpWidget(testScope(const SkyneticApp(), auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cont'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(0), patientUser.email);
      await tester.enterText(find.byType(TextFormField).at(1), testPassword);
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.textContaining('Bine ai venit, Maria'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deconectare'));
      await tester.pumpAndSettle();
      expect(find.text('Cont'), findsOneWidget);
      expect(auth.current, isNull);
    });
  });
}
