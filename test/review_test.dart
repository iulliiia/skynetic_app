import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/features/doctor/doctor_home_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart';
import 'package:skynetic_app/features/review/assessment_form_screen.dart';
import 'package:skynetic_app/features/review/request_detail_screen.dart';
import 'package:skynetic_app/features/review/review_models.dart';
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

  /// Detail screens are lazy ListViews: bring a widget into the tree, then
  /// fully into view (scrollUntilVisible stops at partial visibility and a
  /// tap at the centre could still miss).
  Future<void> scrollTo(WidgetTester t, Finder f) async {
    await t.scrollUntilVisible(f, 300, scrollable: find.byType(Scrollable).first);
    await t.ensureVisible(f);
    await t.pumpAndSettle(); // geometry must be re-laid out before a tap
  }

  test('doctors may open review requests; guests are sent to login', () {
    const doc = AuthState.authenticated(approvedDoctor);
    expect(redirectFor(doc, '/review-requests/abc'), isNull);
    expect(redirectFor(doc, '/review-requests/abc/assess'), isNull);
    expect(redirectFor(doc, '/lesions/abc'), '/doctor');
    expect(redirectFor(const AuthState.guest(), '/review-requests'), '/login?next=%2Freview-requests');
    expect(redirectFor(const AuthState.authenticated(patientUser), '/review-requests'), isNull);
  });

  testWidgets('patient requests a review from a scan', (tester) async {
    final lesions = FakeLesionRepository(lesions: [sampleLesion()], scans: {'l1': [sampleScan()]});
    final reviews = FakeReviewRepository();
    await tester.pumpWidget(testApp(const LesionDetailScreen(lesionId: 'l1'),
        user: patientUser, lesions: lesions, reviews: reviews));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('1 mai 2026')); // the scan tile's date
    await tester.tap(find.text('1 mai 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Închide'), findsOneWidget, reason: 'scan dialog opened');
    await tester.ensureVisible(find.text('Evaluare medicală'));
    await tester.tap(find.text('Evaluare medicală'));
    await tester.pumpAndSettle();
    expect(find.text('Ce vede medicul'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'A crescut.');
    await tester.ensureVisible(find.text('Trimite cererea'));
    await tester.tap(find.text('Trimite cererea'));
    await tester.pumpAndSettle();
    expect(reviews.requests, hasLength(1));
    expect(reviews.requests.single.patientMessage, 'A crescut.');
    expect(find.text('request-rq1'), findsOneWidget, reason: 'navigates to the new request');
  });

  testWidgets('patient sees status, doctor and can cancel while pending', (tester) async {
    final reviews = FakeReviewRepository(requests: [sampleRequest()]);
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: patientUser, reviews: reviews));
    await tester.pumpAndSettle();
    expect(find.text('În așteptare'), findsWidgets);
    expect(find.textContaining('Dr. Ana Popescu'), findsOneWidget);
    expect(find.text('Pacient'), findsNothing, reason: 'patients do not see their own profile section');
    expect(find.text('Preia cazul'), findsNothing);

    await scrollTo(tester, find.text('Retrage cererea'));
    await tester.tap(find.text('Retrage cererea'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Da'));
    await tester.pumpAndSettle();
    expect(reviews.requests.single.status, ReviewStatus.cancelled);
    expect(find.text('Retrasă'), findsWidgets);
  });

  testWidgets('completed request shows the assessment and the disclaimer', (tester) async {
    final reviews = FakeReviewRepository(requests: [sampleRequest(status: ReviewStatus.completed, withReview: true)]);
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: patientUser, reviews: reviews));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Suspiciune de melanom'));
    expect(find.text('Suspiciune de melanom'), findsOneWidget);
    expect(find.text('Consult în curând'), findsOneWidget);
    await scrollTo(tester, find.textContaining('nu înlocuiește un consult'));
    expect(find.textContaining('nu înlocuiește un consult'), findsOneWidget);
    expect(find.text('Retrage cererea'), findsNothing);
  });

  testWidgets('doctor dashboard lists cases; accept then assess completes the case', (tester) async {
    final reviews = FakeReviewRepository(requests: [sampleRequest()]);
    await tester.pumpWidget(testApp(const DoctorHomeScreen(), user: approvedDoctor, reviews: reviews));
    await tester.pumpAndSettle();
    expect(find.text('Cazurile mele'), findsOneWidget);
    expect(find.textContaining('Maria Ionescu'), findsOneWidget, reason: 'doctor view shows the patient');

    // Open the case directly (the list pushes a route stub in tests).
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: approvedDoctor, reviews: reviews));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Pacient'));
    expect(find.text('Pacient'), findsOneWidget);
    expect(find.text('Melanom în antecedente'), findsOneWidget);
    await scrollTo(tester, find.text('Preia cazul'));
    await tester.tap(find.text('Preia cazul'));
    await tester.pumpAndSettle();
    expect(reviews.requests.single.status, ReviewStatus.accepted);
    await scrollTo(tester, find.text('Scrie evaluarea'));
    expect(find.text('Scrie evaluarea'), findsOneWidget);

    // Assessment form validates and submits.
    await tester.pumpWidget(testApp(const AssessmentFormScreen(requestId: 'rq1'), user: approvedDoctor, reviews: reviews));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Trimite evaluarea'));
    await tester.tap(find.text('Trimite evaluarea'));
    await tester.pumpAndSettle();
    expect(find.text('Completează impresia clinică'), findsOneWidget);
    expect(reviews.submitted, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'Leziune pigmentară asimetrică.');
    for (final (label, choice) in [('Categorie suspectată *', 'Suspiciune de melanom'), ('Certitudine *', 'Moderată'), ('Recomandare *', 'Consult în curând')]) {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(choice).last);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.text('Trimite evaluarea'));
    await tester.tap(find.text('Trimite evaluarea'));
    await tester.pumpAndSettle();
    expect(reviews.submitted, hasLength(1));
    expect(reviews.submitted.single.suspectedCategory, 'melanoma_suspected');
    expect(reviews.requests.single.status, ReviewStatus.completed);
  });

  testWidgets('needs-info asks for a note and the patient sees it', (tester) async {
    final reviews = FakeReviewRepository(requests: [sampleRequest(status: ReviewStatus.accepted)]);
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: approvedDoctor, reviews: reviews));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Cere informații'));
    await tester.tap(find.text('Cere informații'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Te rog o poză cu riglă.');
    await tester.tap(find.text('Trimite'));
    await tester.pumpAndSettle();
    expect(reviews.requests.single.status, ReviewStatus.needsInfo);

    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: patientUser, reviews: reviews));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Mesajul medicului'));
    expect(find.text('Mesajul medicului'), findsOneWidget);
    expect(find.text('Te rog o poză cu riglă.'), findsWidgets);
  });
}
