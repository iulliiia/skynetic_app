import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/features/guest/claim_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_detail_screen.dart';
import 'package:skynetic_app/features/lesions/lesion_form_screen.dart';
import 'package:skynetic_app/features/lesions/lesions_screen.dart';
import 'package:skynetic_app/models/saved_scans.dart';
import 'package:skynetic_app/screens/scan_result_screen.dart';
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

  testWidgets('lesions list renders items and the empty state', (tester) async {
    final repo = FakeLesionRepository(lesions: [sampleLesion(), sampleLesion(id: 'l2', scanCount: 0)]);
    await tester.pumpWidget(testApp(const LesionsScreen(), user: patientUser, lesions: repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Aluniță umăr drept'), findsNWidgets(2));
    expect(find.textContaining('2 scanări'), findsOneWidget);
    expect(find.text('Nicio scanare încă'), findsOneWidget);
    expect(find.textContaining('Spate superior'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.inventory_2_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Nu ai leziuni arhivate.'), findsOneWidget);
  });

  testWidgets('lesion detail shows info, scans, quality warning and deletes a scan', (tester) async {
    final repo = FakeLesionRepository(
      lesions: [sampleLesion()],
      scans: {'l1': [sampleScan(), sampleScan(id: 's2', poor: true)]},
    );
    await tester.pumpWidget(testApp(const LesionDetailScreen(lesionId: 'l1'),
        user: patientUser, lesions: repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Spate superior · Posterior (spate) · Dreapta'), findsOneWidget);
    expect(find.text('Mâncărime, Creștere în dimensiune'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_rounded), findsOneWidget, reason: 'poor-quality scan is flagged');

    await tester.tap(find.byIcon(Icons.warning_amber_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Imaginea pare neclară'), findsOneWidget);
    expect(find.text('Lumina slabă'), findsOneWidget);

    await tester.ensureVisible(find.text('Șterge'));
    await tester.tap(find.text('Șterge'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Șterge').last); // confirm (AlertDialog is centred, always visible)
    await tester.pumpAndSettle();
    expect(repo.scansByLesion['l1']!.length, 1);
    expect(find.text('Scanarea a fost ștearsă.'), findsOneWidget);
  });

  testWidgets('lesion form validates and creates', (tester) async {
    final repo = FakeLesionRepository();
    await tester.pumpWidget(testApp(const LesionFormScreen(), user: patientUser, lesions: repo));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Creează leziunea'));
    await tester.tap(find.text('Creează leziunea'));
    await tester.pumpAndSettle();
    expect(find.text('Completează denumirea'), findsOneWidget);
    expect(find.text('Alege regiunea anatomică'), findsOneWidget);
    expect(repo.lesionList, isEmpty);

    await tester.enterText(find.byType(TextFormField).first, 'Aluniță braț');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Braț superior').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Mâncărime'));
    await tester.tap(find.text('Mâncărime'));
    await tester.ensureVisible(find.text('Creează leziunea'));
    await tester.tap(find.text('Creează leziunea'));
    await tester.pumpAndSettle();
    expect(repo.lesionList, hasLength(1));
    expect(repo.lesionList.single.label, 'Aluniță braț');
    expect(repo.lesionList.single.symptoms, ['itching']);
    // Form had nothing to pop to, so it navigated to the new lesion.
    expect(find.text('lesion-l1'), findsOneWidget);
  });

  testWidgets('patient result screen uploads to the preselected lesion and analyses it', (tester) async {
    final repo = FakeLesionRepository(lesions: [sampleLesion()])..scores = [0.7, 0.2, 0.1];
    await tester.pumpWidget(testApp(
      ScanResultScreen(imageFile: XFile('/nonexistent.jpg'), lesionId: 'l1'),
      user: patientUser, lesions: repo,
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Obține rezultatul'));
    await tester.tap(find.text('Obține rezultatul'));
    await tester.pumpAndSettle();
    expect(repo.uploads, 1, reason: 'photo stored before analysis');
    expect(repo.analyses, 1);
    expect(find.text('Grad de risc scăzut'), findsOneWidget);
    expect(find.textContaining('scor model 70%'), findsOneWidget);
    expect(find.text('Vezi leziunea'), findsOneWidget);
    expect(find.textContaining('Vrei părerea unui medic'), findsNothing, reason: 'nudge is for guests only');
    expect(repo.scansByLesion['l1']!.single.latestPrediction?.predictedClass, 0);
  });

  testWidgets('inconclusive result is shown as such', (tester) async {
    final repo = FakeLesionRepository()..scores = [0.46, 0.41, 0.13];
    await tester.pumpWidget(testApp(ScanResultScreen(imageFile: XFile('/nonexistent.jpg')), lesions: repo));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Obține rezultatul'));
    await tester.tap(find.text('Obține rezultatul'));
    await tester.pumpAndSettle();
    expect(find.text('Rezultat neconcludent'), findsOneWidget);
    expect(find.textContaining('nu a putut distinge'), findsOneWidget);
  });

  testWidgets('guest result screen shows the account nudge', (tester) async {
    final repo = FakeLesionRepository()..scores = [0.05, 0.9, 0.05];
    await tester.pumpWidget(testApp(ScanResultScreen(imageFile: XFile('/nonexistent.jpg')), lesions: repo));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.ensureVisible(find.text('Obține rezultatul'));
    await tester.tap(find.text('Obține rezultatul'));
    await tester.pumpAndSettle();
    expect(find.text('Salvează rezultatul'), findsOneWidget);
    expect(find.text('Grad de risc crescut'), findsOneWidget);
    expect(find.textContaining('Vrei părerea unui medic'), findsOneWidget);
    expect(repo.analyses, 1);
  });

  testWidgets('claim screen attaches a guest scan and marks it claimed', (tester) async {
    final pending = SavedScan(
      imagePath: '/nonexistent.jpg', classId: 1, locationLabel: 'Spate', uniqueTag: 'Semn spate',
      bodySide: 'Posterior', lateralSide: 'Stânga', bodyPart: 'Spate', scanDate: DateTime(2026, 5, 1),
      remoteScanId: 'guest-9', claimToken: 'tok', claimExpiresAt: DateTime.now().add(const Duration(hours: 5)),
    );
    SharedPreferences.setMockInitialValues({'saved_scans_v3': [pending.toJson()].map((e) => e.toString()).toList()});
    // Store via the model so encoding matches.
    SharedPreferences.setMockInitialValues({});
    SavedScans.list = [];
    await SavedScans.save(pending);

    final repo = FakeLesionRepository(lesions: [sampleLesion()]);
    await tester.pumpWidget(testApp(const ClaimScreen(), user: patientUser, lesions: repo));
    await tester.pumpAndSettle();
    expect(find.text('Semn spate'), findsOneWidget);

    await tester.tap(find.text('Asociază'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Aluniță umăr drept').last); // pick the lesion in the sheet
    await tester.pumpAndSettle();
    expect(repo.claimed, ['guest-9']);
    expect(SavedScans.claimable, isEmpty);
    expect(find.text('Nu ai scanări de asociat.'), findsOneWidget);
  });
}
