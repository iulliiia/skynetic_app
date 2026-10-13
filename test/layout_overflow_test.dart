import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/core/auth/auth_models.dart';
import 'package:skynetic_app/features/auth/login_screen.dart';
import 'package:skynetic_app/features/auth/register_screen.dart';
import 'package:skynetic_app/features/doctor/doctor_home_screen.dart';
import 'package:skynetic_app/features/guest/claim_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_form_screen.dart';
import 'package:skynetic_app/features/lesions/lesions_screen.dart';
import 'package:skynetic_app/features/chat/chat_screen.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
import 'package:skynetic_app/features/privacy/privacy.dart';
import 'package:skynetic_app/features/review/assessment_form_screen.dart';
import 'package:skynetic_app/features/review/my_requests_screen.dart';
import 'package:skynetic_app/features/review/request_detail_screen.dart';
import 'package:skynetic_app/features/review/review_models.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/core/api/api_error.dart';
import 'package:skynetic_app/screens/home_screen.dart';
import 'package:skynetic_app/screens/learn/abcde_screen.dart';
import 'package:skynetic_app/screens/learn/prevention_screen.dart';
import 'package:skynetic_app/screens/learn/skin_care_screen.dart';
import 'package:skynetic_app/screens/learn/when_to_see_doctor_screen.dart';
import 'package:skynetic_app/screens/learn_screen.dart';
import 'package:skynetic_app/screens/onboarding/onboarding_screen.dart';
import 'package:skynetic_app/screens/photo_detail_screen.dart';
import 'package:skynetic_app/screens/profile_screen.dart';
import 'package:skynetic_app/screens/scan_result_screen.dart';
import 'package:skynetic_app/screens/scan_screen.dart';
import 'package:skynetic_app/utils/shared_prefs.dart';

import 'support/fakes.dart';

/// Every screen/state × viewport × text scale must render without a
/// RenderFlex overflow. This is the UI regression gate for all phases.

final _scan = SavedScan(
  imagePath: '/nonexistent.jpg',
  classId: 2,
  locationLabel: 'Posterior - Stânga - Încheietura mâinii - Dosul mâinii',
  uniqueTag: 'Aluniță foarte lungă pe spatele mâinii stângi',
  bodySide: 'Posterior',
  lateralSide: 'Stânga',
  bodyPart: 'Încheietura mâinii',
  notes: 'Pare mai mare decât luna trecută, de verificat la control.',
  scanDate: DateTime(2026, 5, 1),
  remoteScanId: 'guest-1',
  claimToken: 'tok',
  claimExpiresAt: DateTime.now().add(const Duration(hours: 20)),
);

const _sizes = {
  'iPhone SE 1st gen': (Size(320, 568), EdgeInsets.only(top: 20)),
  'iPhone SE 3rd gen': (Size(375, 667), EdgeInsets.only(top: 20)),
  'iPhone 16 Pro': (Size(402, 874), EdgeInsets.only(top: 62, bottom: 34)),
  'iPhone landscape': (
    Size(874, 402),
    EdgeInsets.only(left: 62, right: 62, bottom: 21)
  ),
  'iPad': (Size(1024, 1366), EdgeInsets.only(top: 24, bottom: 20)),
};

const _keyboard = FakeViewPadding(bottom: 300);

typedef _Hook = Future<void> Function(WidgetTester);

class _Case {
  final String name;
  final Widget Function() build;
  final AuthUser? user;
  final _Hook? hook;
  /// Tweaks the fake lesion repository before the screen is pumped.
  final void Function(FakeLesionRepository)? setup;
  /// Review requests visible to the screen.
  final List<ReviewRequest> Function()? requests;
  final FakeChatRepository Function()? chat;
  final List<AppNotification> Function()? notifications;
  const _Case(this.name, this.build, {this.user, this.hook, this.setup, this.requests, this.chat, this.notifications});
}

ScanResultScreen _resultScreen({String? lesionId}) =>
    ScanResultScreen(imageFile: XFile('/nonexistent.jpg'), lesionId: lesionId);

/// Accepts the disclaimer and asks for the analysis.
Future<void> _requestResult(WidgetTester t, {bool settle = true}) async {
  await t.ensureVisible(find.byType(Checkbox));
  await t.tap(find.byType(Checkbox));
  await t.pump();
  final button = find.text('Obține rezultatul');
  await t.ensureVisible(button);
  await t.tap(button);
  if (settle) {
    await t.pumpAndSettle();
  } else {
    await t.pump(const Duration(milliseconds: 500));
  }
}

Future<void> _openFilters(WidgetTester t) async {
  await t.tap(find.byIcon(Icons.expand_more));
  await t.pumpAndSettle();
}

/// Opens the dialog of the poor-quality scan. The tile's onTap is invoked
/// directly: on short/landscape viewports the extended FAB overlaps the grid
/// and synthetic taps would hit it — this case checks the dialog's layout,
/// not hit-testing.
Future<void> _openPoorScanDialog(WidgetTester t) async {
  final icon = find.byIcon(Icons.warning_amber_rounded);
  await t.scrollUntilVisible(icon, 200, scrollable: find.byType(Scrollable).first);
  final tile = find.ancestor(of: icon.first, matching: find.byType(InkWell)).first;
  t.widget<InkWell>(tile).onTap!();
  await t.pumpAndSettle();
  expect(find.text('Închide'), findsOneWidget, reason: 'scan dialog must open');
}

Future<void> _showKeyboard(WidgetTester t) async {
  t.view.viewInsets = _keyboard;
  await t.pumpAndSettle();
}

final _cases = <_Case>[
  // --- guest
  const _Case('Home (guest)', HomeScreen.new),
  _Case('Home tabs (guest)', HomeScreen.new, hook: (t) async {
    for (final icon in [Icons.camera_alt, Icons.history, Icons.book, Icons.home]) {
      await t.tap(find.byIcon(icon).last);
      await t.pumpAndSettle();
    }
  }),
  const _Case('Scan', ScanScreen.new),
  const _Case('Learn', LearnScreen.new),
  _Case('Profile (filters open)', ProfileScreen.new, hook: _openFilters),
  _Case('Profile (filters open, keyboard)', ProfileScreen.new, hook: (t) async {
    await _openFilters(t);
    await _showKeyboard(t);
  }),
  const _Case('ABCDE', ABCDEScreen.new),
  const _Case('Prevention', PreventionScreen.new),
  const _Case('Skin care', SkinCareScreen.new),
  const _Case('Doctor', WhenToSeeDoctorScreen.new),
  _Case('Photo detail', () => PhotoDetailScreen(scan: _scan)),
  const _Case('Onboarding', OnboardingScreen.new),
  const _Case('Login', LoginScreen.new),
  _Case('Login (keyboard)', LoginScreen.new, hook: _showKeyboard),
  const _Case('Register (patient)', RegisterScreen.new),
  _Case('Register (doctor, keyboard)', () => const RegisterScreen(initialRole: 'doctor'), hook: _showKeyboard),
  _Case('Scan result', _resultScreen),
  _Case('Scan result (loading)', _resultScreen, setup: (r) => r.holdAnalysis = Completer<void>(),
      hook: (t) => _requestResult(t, settle: false)),
  _Case('Scan result (error)', _resultScreen,
      setup: (r) => r.analysisError = const ApiException(
          code: 'service_unavailable',
          message: 'Nu s-a putut realiza conexiunea cu serverul (http://10.0.2.2:8080). Verifică conexiunea și dacă serverul este pornit.'),
      hook: _requestResult),
  _Case('Scan result (high risk, guest)', _resultScreen, setup: (r) => r.scores = [0.05, 0.93, 0.02], hook: _requestResult),
  _Case('Scan result (inconclusive, guest)', _resultScreen, setup: (r) => r.scores = [0.46, 0.41, 0.13], hook: _requestResult),
  _Case('Save dialog (guest, keyboard)', _resultScreen, setup: (r) => r.scores = [0.61, 0.3, 0.09], hook: (t) async {
    await _requestResult(t);
    final save = find.text('Salvează rezultatul');
    await t.ensureVisible(save);
    await t.tap(save);
    await t.pumpAndSettle();
    await _showKeyboard(t);
  }),
  // --- patient
  const _Case('Home (patient)', HomeScreen.new, user: patientUser),
  const _Case('Lesions', LesionsScreen.new, user: patientUser),
  _Case('Lesions (archived view)', LesionsScreen.new, user: patientUser, hook: (t) async {
    await t.tap(find.byIcon(Icons.inventory_2_outlined));
    await t.pumpAndSettle();
  }),
  _Case('Lesion detail', () => const LesionDetailScreen(lesionId: 'l1'), user: patientUser),
  _Case('Lesion detail (scan dialog)', () => const LesionDetailScreen(lesionId: 'l1'), user: patientUser,
      hook: _openPoorScanDialog),
  const _Case('Lesion form (new)', LesionFormScreen.new, user: patientUser),
  _Case('Lesion form (edit, keyboard)', () => const LesionFormScreen(lesionId: 'l1'), user: patientUser,
      hook: _showKeyboard),
  _Case('Scan result (patient, clear skin)', () => _resultScreen(lesionId: 'l1'), user: patientUser,
      setup: (r) => r.scores = [0.1, 0.1, 0.8], hook: _requestResult),
  const _Case('Claim', ClaimScreen.new, user: patientUser),
  _Case('My requests (empty)', MyRequestsScreen.new, user: patientUser),
  _Case('My requests', MyRequestsScreen.new, user: patientUser,
      requests: () => [sampleRequest(), sampleRequest(id: 'rq2', status: ReviewStatus.completed, withReview: true)]),
  _Case('Request detail (patient, pending)', () => const RequestDetailScreen(requestId: 'rq1'), user: patientUser,
      requests: () => [sampleRequest()]),
  _Case('Request detail (patient, needs info)', () => const RequestDetailScreen(requestId: 'rq1'), user: patientUser,
      requests: () => [sampleRequest(status: ReviewStatus.needsInfo)]),
  _Case('Request detail (patient, completed)', () => const RequestDetailScreen(requestId: 'rq1'), user: patientUser,
      requests: () => [sampleRequest(status: ReviewStatus.completed, withReview: true)]),
  _Case('Lesion detail (request sheet)', () => const LesionDetailScreen(lesionId: 'l1'), user: patientUser, hook: (t) async {
    await _openPoorScanDialog(t);
    await t.ensureVisible(find.text('Evaluare medicală'));
    await t.tap(find.text('Evaluare medicală'));
    await t.pumpAndSettle();
    await _showKeyboard(t);
  }),
  _Case('Chat (patient, empty)', () => const ChatScreen(requestId: 'rq1'), user: patientUser,
      requests: () => [sampleRequest(status: ReviewStatus.accepted)]),
  _Case('Chat (patient, messages, keyboard)', () => const ChatScreen(requestId: 'rq1'), user: patientUser,
      requests: () => [sampleRequest(status: ReviewStatus.accepted)], chat: () => FakeChatRepository(messages: [
        sampleMessage(), sampleMessage(id: 'm2', mine: false, body: 'Bună ziua! Vă rog să-mi spuneți de când ați observat-o și dacă s-a modificat. Mulțumesc.', at: DateTime(2026, 5, 2, 10, 5)),
        sampleMessage(id: 'm3', body: 'De vreo două luni, pare mai mare.', at: DateTime(2026, 5, 3, 9), read: true),
      ]), hook: _showKeyboard),
  const _Case('Privacy', PrivacyScreen.new, user: patientUser),
  _Case('Privacy (notice sheet)', PrivacyScreen.new, user: patientUser, hook: (t) async {
    // Target the research tile by its unique title (several switches may be built).
    final title = find.text('Utilizarea datelor în scop de cercetare');
    await t.scrollUntilVisible(title, 200, scrollable: find.byType(Scrollable).first);
    final sw = find.descendant(of: find.ancestor(of: title, matching: find.byType(Card)).first, matching: find.byType(Switch));
    t.widget<Switch>(sw).onChanged!(true);
    await t.pumpAndSettle();
  }),
  _Case('Privacy (deletion dialog)', PrivacyScreen.new, user: patientUser, hook: (t) async {
    await t.scrollUntilVisible(find.text('Solicită ștergerea contului'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.text('Solicită ștergerea contului'));
    await t.pumpAndSettle();
  }),
  _Case('Notifications (empty)', NotificationsScreen.new, user: patientUser),
  _Case('Notifications', NotificationsScreen.new, user: patientUser,
      notifications: () => [sampleNotification(), sampleNotification(id: 'n2', unread: false, type: 'message.new')]),
  // --- doctor
  const _Case('Doctor home (pending)', DoctorHomeScreen.new, user: pendingDoctor),
  _Case('Doctor dashboard (approved)', DoctorHomeScreen.new, user: approvedDoctor,
      requests: () => [sampleRequest(), sampleRequest(id: 'rq2', status: ReviewStatus.accepted), sampleRequest(id: 'rq3', status: ReviewStatus.completed, withReview: true)]),
  _Case('Doctor dashboard (closed tab)', DoctorHomeScreen.new, user: approvedDoctor,
      requests: () => [sampleRequest(id: 'rq3', status: ReviewStatus.completed, withReview: true)], hook: (t) async {
    await t.tap(find.text('Închise'));
    await t.pumpAndSettle();
  }),
  _Case('Case detail (doctor, pending)', () => const RequestDetailScreen(requestId: 'rq1'), user: approvedDoctor,
      requests: () => [sampleRequest()]),
  _Case('Case detail (doctor, accepted)', () => const RequestDetailScreen(requestId: 'rq1'), user: approvedDoctor,
      requests: () => [sampleRequest(status: ReviewStatus.accepted)]),
  _Case('Chat (doctor)', () => const ChatScreen(requestId: 'rq1'), user: approvedDoctor,
      requests: () => [sampleRequest(status: ReviewStatus.accepted)], chat: () => FakeChatRepository(messages: [sampleMessage()])),
  _Case('Case detail (doctor, completed)', () => const RequestDetailScreen(requestId: 'rq1'), user: approvedDoctor,
      requests: () => [sampleRequest(status: ReviewStatus.completed, withReview: true)]),
  _Case('Assessment form (keyboard)', () => const AssessmentFormScreen(requestId: 'rq1'), user: approvedDoctor,
      requests: () => [sampleRequest(status: ReviewStatus.accepted)], hook: _showKeyboard),
];

void main() {
  setUpAll(() async {
    installTestLocalStorage();
    await initializeDateFormatting('ro_RO', null);
  });

  for (final scale in [1.0, 1.3]) {
    for (final size in _sizes.entries) {
      for (final c in _cases) {
        testWidgets('${c.name} @ ${size.key} x$scale', (tester) async {
          SharedPreferences.setMockInitialValues({
            'saved_scans_v3': List.filled(4, jsonEncode(_scan.toJson())),
            'onboarding_completed': true,
          });
          await SharedPrefs.init();
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size.value.$1;
          tester.view.padding = FakeViewPadding(
            left: size.value.$2.left,
            top: size.value.$2.top,
            right: size.value.$2.right,
            bottom: size.value.$2.bottom,
          );
          addTearDown(tester.view.reset);

          final overflows = <String>[];
          final original = FlutterError.onError;
          FlutterError.onError = (details) {
            final msg = details.exceptionAsString();
            if (msg.contains("overflowed")) overflows.add(msg);
          };

          final lesions = FakeLesionRepository(
            lesions: [sampleLesion(), sampleLesion(id: 'l2', scanCount: 0)],
            scans: {'l1': [sampleScan(), sampleScan(id: 's2', poor: true)]},
          );
          c.setup?.call(lesions);
          final reviews = FakeReviewRepository(requests: c.requests?.call());
          final chat = c.chat?.call();
          final notifications = FakeNotificationRepository(items: c.notifications?.call());
          try {
            await tester.pumpWidget(testApp(
              c.build(),
              user: c.user, lesions: lesions, reviews: reviews, chat: chat, notifications: notifications,
              textScale: scale,
            ));
            await tester.pumpAndSettle();
            await c.hook?.call(tester);
          } finally {
            FlutterError.onError = original;
          }
          expect(overflows, isEmpty);
        });
      }
    }
  }
}
