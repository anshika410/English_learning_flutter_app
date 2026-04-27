import 'package:ella_flutter/providers/chat_provider.dart';
import 'package:ella_flutter/screens/conversation_screen.dart';
import 'package:ella_flutter/screens/end_screen.dart';
import 'package:ella_flutter/screens/profile_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ella_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

Widget _testApp(Widget child) {
  return ChangeNotifierProvider(
    create: (_) => ChatProvider(),
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('App renders', (WidgetTester tester) async {
    await tester.pumpWidget(const EllaApp());
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('Empty end screen shows centered content and bottom CTAs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const EndScreen(
          topic: 'Daily routine',
          durationLabel: '0s',
          sessionType: SessionType.empty,
        ),
      ),
    );

    expect(find.text('Looks like we lost you there.'), findsOneWidget);
    expect(
      find.text('No chat happened — that\'s okay. Want to try a fresh start?'),
      findsOneWidget,
    );
    expect(find.text('PICK NEW TOPIC'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
  });

  testWidgets('Empty end screen retry restarts with retry topic', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const EndScreen(
          topic: 'Generated Header',
          retryTopic: 'Original Topic',
          durationLabel: '0s',
          sessionType: SessionType.empty,
        ),
      ),
    );

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump(const Duration(milliseconds: 500));

    final screen = tester.widget<ConversationScreen>(
      find.byType(ConversationScreen, skipOffstage: false),
    );
    expect(screen.topic, 'Original Topic');
  });

  testWidgets('Empty end screen pick new topic navigates without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _testApp(
        const EndScreen(
          topic: 'Daily routine',
          durationLabel: '0s',
          sessionType: SessionType.empty,
        ),
      ),
    );

    await tester.tap(find.text('PICK NEW TOPIC'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('Profile logout footer is left aligned and not stretched', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_testApp(const ProfileScreen()));

    final logoutRect = tester.getRect(
      find.byKey(const ValueKey('profile_logout_button')),
    );

    expect(logoutRect.left, 24);
    expect(logoutRect.width, lessThan(390 - 48));
    expect(find.text('LOGOUT'), findsOneWidget);
  });

  testWidgets('Profile edit sheet uses title case and uppercase CTA', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(_testApp(const ProfileScreen()));

    await tester.tap(find.text('Edit Profile'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Your Profile'), findsOneWidget);
    expect(find.text('SAVE PROFILE'), findsOneWidget);
  });
}
