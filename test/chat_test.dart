import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:skynetic_app/core/auth/auth_controller.dart';
import 'package:skynetic_app/core/router/app_router.dart';
import 'package:skynetic_app/features/chat/chat_models.dart';
import 'package:skynetic_app/features/chat/chat_screen.dart';
import 'package:skynetic_app/features/notifications/notifications.dart';
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

  test('chat and inbox routes follow the role rules', () {
    expect(redirectFor(const AuthState.authenticated(approvedDoctor), '/review-requests/x/chat'), isNull);
    expect(redirectFor(const AuthState.authenticated(approvedDoctor), '/notifications'), isNull);
    expect(redirectFor(const AuthState.authenticated(patientUser), '/notifications'), isNull);
    expect(redirectFor(const AuthState.guest(), '/notifications'), '/login?next=%2Fnotifications');
  });

  testWidgets('chat loads history, marks read, sends optimistically and receives live messages', (tester) async {
    final chat = FakeChatRepository(messages: [sampleMessage(id: 'm0', mine: false, body: 'Bună ziua!')]);
    final reviews = FakeReviewRepository(requests: [sampleRequest(status: ReviewStatus.accepted)]);
    await tester.pumpWidget(testApp(const ChatScreen(requestId: 'rq1'), user: patientUser, reviews: reviews, chat: chat));
    await tester.pumpAndSettle();
    expect(find.text('Bună ziua!'), findsOneWidget);
    expect(find.textContaining('Dr. Ana Popescu'), findsOneWidget, reason: 'counterpart in the title');
    expect(chat.readCalls, contains('rq1'), reason: 'opening the chat marks the doctor messages read');
    expect(chat.connects, 1);

    await tester.enterText(find.byType(TextField), 'Mulțumesc, am o întrebare.');
    await tester.tap(find.byTooltip('Trimite'));
    await tester.pump(); // optimistic bubble, before the fake "network" completes
    expect(find.text('Mulțumesc, am o întrebare.'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(chat.sends, 1);
    expect(find.text('Mulțumesc, am o întrebare.'), findsOneWidget, reason: 'server echo replaced the optimistic bubble, no duplicate');
    expect(find.byIcon(Icons.done), findsOneWidget, reason: 'delivered, unread tick');

    chat.receive('Spuneți, vă rog.');
    await tester.pumpAndSettle();
    expect(find.text('Spuneți, vă rog.'), findsOneWidget);
    expect(chat.readCalls, contains('ws:rq1'), reason: 'incoming message is acknowledged as read over the socket');

    // A read event from the doctor turns my tick blue (done_all).
    chat.live.add(const ChatEvent(type: 'read', requestId: 'rq1', readerUserId: 'u-doc2'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.done_all), findsOneWidget);
  });

  testWidgets('a failed send stays visible and can be retried', (tester) async {
    final chat = FakeChatRepository()..failSends = true;
    final reviews = FakeReviewRepository(requests: [sampleRequest(status: ReviewStatus.accepted)]);
    await tester.pumpWidget(testApp(const ChatScreen(requestId: 'rq1'), user: patientUser, reviews: reviews, chat: chat));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Test');
    await tester.tap(find.byTooltip('Trimite'));
    await tester.pumpAndSettle();
    expect(find.text('Test'), findsOneWidget);
    expect(find.byIcon(Icons.refresh), findsOneWidget, reason: 'retry affordance');
    expect(find.text('Fără conexiune.'), findsOneWidget, reason: 'error surfaced as a snackbar');

    chat.failSends = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsNothing);
    expect(chat.sends, 2);
  });

  testWidgets('request detail shows the conversation button with the unread badge once accepted', (tester) async {
    final reviews = FakeReviewRepository(requests: [sampleRequest(status: ReviewStatus.accepted)]);
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: patientUser, reviews: reviews));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Conversație cu medicul'), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Conversație cu medicul'), findsOneWidget);
    expect(find.text('2'), findsOneWidget, reason: 'unread badge from /messages/unread');

    final pending = FakeReviewRepository(requests: [sampleRequest()]);
    await tester.pumpWidget(testApp(const RequestDetailScreen(requestId: 'rq1'), user: patientUser, reviews: pending));
    await tester.pumpAndSettle();
    expect(find.text('Conversație cu medicul'), findsNothing, reason: 'no chat before acceptance');
  });

  testWidgets('inbox lists notifications, marks read on tap and navigates', (tester) async {
    final repo = FakeNotificationRepository(items: [sampleNotification(), sampleNotification(id: 'n2', unread: false, type: 'message.new')]);
    await tester.pumpWidget(testApp(const NotificationsScreen(), user: patientUser, notifications: repo));
    await tester.pumpAndSettle();
    expect(find.text('Cererea ta a fost preluată'), findsNWidgets(2));
    expect(find.byTooltip('Marchează tot citit'), findsOneWidget);

    await tester.tap(find.text('Cererea ta a fost preluată').first);
    await tester.pumpAndSettle();
    expect(repo.read, ['n1']);
    expect(find.text('request-rq1'), findsOneWidget, reason: 'navigates to the request');
  });
}
