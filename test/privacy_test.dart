import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/features/privacy/privacy.dart';
import 'package:skynetic_app/screens/home_screen.dart';
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

  /// The privacy screen is a lazy ListView: a tall surface builds every tile.
  void tall(WidgetTester t) {
    t.view.devicePixelRatio = 1;
    t.view.physicalSize = const Size(800, 2000);
    addTearDown(t.view.reset);
  }

  testWidgets('consents: mandatory purpose is locked, optional ones toggle through the notice sheet', (tester) async {
    tall(tester);
    final privacy = FakePrivacyRepository();
    await tester.pumpWidget(testApp(const PrivacyScreen(), user: patientUser, privacy: privacy));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.lock_outline), findsOneWidget, reason: 'service consent cannot be withdrawn');
    expect(find.byType(Switch), findsNWidgets(3));
    expect(find.text('Nu ai decis încă'), findsNWidgets(3));

    // Turning research on shows the notice; "Nu acum" records nothing.
    final researchSwitch = find.byType(Switch).at(1);
    await tester.tap(researchSwitch);
    await tester.pumpAndSettle();
    expect(find.text('Utilizarea datelor în scop de cercetare'), findsWidgets);
    expect(find.textContaining('Ce NU se exportă'), findsOneWidget);
    await tester.tap(find.text('Nu acum'));
    await tester.pumpAndSettle();
    expect(privacy.granted, isEmpty);

    await tester.tap(researchSwitch);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sunt de acord'));
    await tester.pumpAndSettle();
    expect(privacy.granted, ['research']);
    expect(find.textContaining('Acord dat'), findsOneWidget);

    // Withdrawing asks for confirmation and records the withdrawal.
    await tester.tap(find.byType(Switch).at(1));
    await tester.pumpAndSettle();
    expect(find.textContaining('nu vor mai fi incluse'), findsOneWidget);
    await tester.tap(find.text('Retrage'));
    await tester.pumpAndSettle();
    expect(privacy.withdrawn, ['research']);
    expect(find.textContaining('Acord retras'), findsOneWidget);
  });

  testWidgets('export and deletion request', (tester) async {
    tall(tester);
    final privacy = FakePrivacyRepository();
    final auth = FakeAuthRepository(current: patientUser);
    await tester.pumpWidget(testApp(const PrivacyScreen(), user: patientUser, privacy: privacy, auth: auth));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Descarcă o copie a datelor mele'));
    await tester.pumpAndSettle();
    expect(privacy.exports, 1);
    expect(find.textContaining('Export generat'), findsOneWidget);

    await tester.tap(find.text('Solicită ștergerea contului'));
    await tester.pumpAndSettle();
    expect(find.textContaining('formă pseudonimizată'), findsOneWidget, reason: 'retention rule is explained');
    await tester.tap(find.text('Trimite cererea'));
    await tester.pumpAndSettle();
    expect(privacy.requests.single.type, 'deletion');
    expect(auth.current, isNull, reason: 'signed out after requesting deletion');
  });

  testWidgets('home shows the research banner only while undecided', (tester) async {
    final privacy = FakePrivacyRepository();
    await tester.pumpWidget(testApp(const HomeScreen(), user: patientUser, privacy: privacy));
    await tester.pumpAndSettle();
    expect(find.textContaining('contribui la cercetare'), findsOneWidget);

    privacy.status['research'] = 'withdrawn';
    await tester.pumpWidget(const SizedBox()); // tear the scope down so providers refetch
    await tester.pumpWidget(testApp(const HomeScreen(), user: patientUser, privacy: privacy));
    await tester.pumpAndSettle();
    expect(find.textContaining('contribui la cercetare'), findsNothing);
  });
}
