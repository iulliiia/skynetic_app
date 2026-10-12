import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/models/saved_scans.dart';
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
import 'package:skynetic_app/theme/app_theme.dart';

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

final _screens =
    <String, (Widget Function(), Future<void> Function(WidgetTester)?)>{
  'Home': (() => const HomeScreen(), null),
  'Scan': (() => const ScanScreen(), null),
  'Learn': (() => const LearnScreen(), null),
  'Profile (filters open)': (
    () => const ProfileScreen(),
    (t) async {
      await t.tap(find.byIcon(Icons.expand_more));
      await t.pumpAndSettle();
    }
  ),
  'ABCDE': (() => const ABCDEScreen(), null),
  'Prevention': (() => const PreventionScreen(), null),
  'Skin care': (() => const SkinCareScreen(), null),
  'Doctor': (() => const WhenToSeeDoctorScreen(), null),
  'Photo detail': (() => PhotoDetailScreen(scan: _scan), null),
  'Onboarding': (() => const OnboardingScreen(), null),
  'Scan result': (
    () => ScanResultScreen(imageFile: XFile('/nonexistent.jpg')),
    null
  ),
};

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ro_RO', null);
  });

  for (final scale in [1.0, 1.3]) {
    for (final size in _sizes.entries) {
      for (final screen in _screens.entries) {
        testWidgets('${screen.key} @ ${size.key} x$scale', (tester) async {
          SharedPreferences.setMockInitialValues({
            'saved_scans_v3': List.filled(4, jsonEncode(_scan.toJson())),
          });
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

          await tester.pumpWidget(MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: screen.value.$1(),
          ));
          await tester.pumpAndSettle();
          await screen.value.$2?.call(tester);

          FlutterError.onError = original;
          expect(overflows, isEmpty);
        });
      }
    }
  }
}
