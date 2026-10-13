import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/features/auth/login_screen.dart';
import 'package:skynetic_app/features/auth/register_screen.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

import 'support/fakes.dart';

void main() {
  setUpAll(() {
    installTestLocalStorage();
    return initializeDateFormatting('ro_RO', null);
  });
  setUp(() async {
    SharedPreferences.setMockInitialValues({'onboarding_completed': true});
    await SharedPrefs.init();
  });

  AuthState authOf(WidgetTester t) =>
      ProviderScope.containerOf(t.element(find.byType(Scaffold).first)).read(authControllerProvider);

  group('LoginScreen', () {
    testWidgets('validates before calling the API', (tester) async {
      final auth = FakeAuthRepository();
      await tester.pumpWidget(testApp(const LoginScreen(), auth: auth));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(find.text('Introdu adresa de email'), findsOneWidget);
      expect(find.text('Introdu parola'), findsOneWidget);
      expect(auth.loginCalls, 0);

      await tester.enterText(find.byType(TextFormField).at(0), 'not-an-email');
      await tester.pumpAndSettle();
      expect(find.text('Adresa de email nu este validă'), findsOneWidget);
    });

    testWidgets('shows the server error for wrong credentials', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), patientUser.email);
      await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(find.text('Email sau parolă incorecte.'), findsOneWidget);
      expect(authOf(tester).isGuest, isTrue);
    });

    testWidgets('signs in and updates the auth state', (tester) async {
      await tester.pumpWidget(testApp(const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), patientUser.email);
      await tester.enterText(find.byType(TextFormField).at(1), testPassword);
      await tester.tap(find.text('Intră în cont'));
      await tester.pumpAndSettle();
      expect(find.text('Email sau parolă incorecte.'), findsNothing);
      // The screen navigated away; read the state from the new route.
      final state = authOf(tester);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.role, UserRole.patient);
    });
  });

  group('RegisterScreen', () {
    testWidgets('requires the processing notice and a 10+ char password', (tester) async {
      await tester.pumpWidget(testApp(const RegisterScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ionescu');
      await tester.enterText(find.byType(TextFormField).at(2), 'new@test.ro');
      await tester.enterText(find.byType(TextFormField).at(3), 'short');
      await tester.ensureVisible(find.text('Creează contul'));
      await tester.tap(find.text('Creează contul'));
      await tester.pumpAndSettle();
      expect(find.text('Parola trebuie să aibă cel puțin 10 caractere'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField).at(3), testPassword);
      await tester.ensureVisible(find.text('Creează contul'));
      await tester.tap(find.text('Creează contul'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Trebuie să accepți nota'), findsOneWidget);
      // Nothing on this screen has touched the auth provider yet, so it may
      // still be in its initial loading state; what matters is no session.
      expect(authOf(tester).isAuthenticated, isFalse);
    });

    testWidgets('creates a patient account', (tester) async {
      await tester.pumpWidget(testApp(const RegisterScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'Maria');
      await tester.enterText(find.byType(TextFormField).at(1), 'Ionescu');
      await tester.enterText(find.byType(TextFormField).at(2), 'new@test.ro');
      await tester.enterText(find.byType(TextFormField).at(3), testPassword);
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Creează contul'));
      await tester.tap(find.text('Creează contul'));
      await tester.pumpAndSettle();
      final state = authOf(tester);
      expect(state.isAuthenticated, isTrue);
      expect(state.user?.firstName, 'Maria');
    });

    testWidgets('doctor role shows professional fields and ends pending', (tester) async {
      await tester.pumpWidget(testApp(const RegisterScreen(initialRole: 'doctor')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Număr de înregistrare'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Ana');
      await tester.enterText(find.byType(TextFormField).at(1), 'Popescu');
      await tester.enterText(find.byType(TextFormField).at(2), 'dr-new@test.ro');
      await tester.enterText(find.byType(TextFormField).at(3), testPassword);
      await tester.enterText(find.byType(TextFormField).at(5), 'RO-12345');
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(find.text('Creează contul'));
      await tester.tap(find.text('Creează contul'));
      await tester.pumpAndSettle();
      final state = authOf(tester);
      expect(state.isDoctor, isTrue);
      expect(state.user?.doctorStatus, DoctorVerificationStatus.pending);
    });
  });
}
