import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ella_app/screens/login_screen.dart';
import 'package:ella_app/services/ella_api_service.dart';

class _FakeEllaApiService extends EllaApiService {
  _FakeEllaApiService() : super(baseUrl: 'https://example.invalid');

  String? requestedEmail;

  @override
  Future<bool> requestMagicLink(String email) async {
    requestedEmail = email;
    return true;
  }
}

Widget _harness(_FakeEllaApiService api, {Size size = const Size(430, 932)}) {
  return MaterialApp(
    home: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MediaQuery(
          data: MediaQueryData(size: size, disableAnimations: true),
          child: LoginScreen(api: api, enableGoogleAuth: false),
        ),
      ),
    ),
  );
}

Future<void> _pumpLogin(
  WidgetTester tester,
  _FakeEllaApiService api, {
  Size size = const Size(430, 932),
}) async {
  await tester.pumpWidget(_harness(api, size: size));
  await tester.pump();
}

void main() {
  testWidgets('initial login state shows auth options and privacy copy', (
    tester,
  ) async {
    await _pumpLogin(tester, _FakeEllaApiService());

    expect(find.text('ZoSpeak'), findsOneWidget);
    expect(find.text('Continue With Google'), findsOneWidget);
    expect(find.text('Continue With Email'), findsOneWidget);
    expect(
      find.textContaining('Your learning data stays private'),
      findsOneWidget,
    );
    expect(find.text('Sign In With Email'), findsNothing);
  });

  testWidgets('email state opens and back returns to login options', (
    tester,
  ) async {
    await _pumpLogin(tester, _FakeEllaApiService());

    await tester.tap(find.text('Continue With Email'));
    await tester.pump();

    expect(find.text('Sign In With Email'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('auth-back-button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('auth-back-button')));
    await tester.pump();

    expect(find.text('Continue With Google'), findsOneWidget);
    expect(find.text('Continue With Email'), findsOneWidget);
    expect(find.text('Sign In With Email'), findsNothing);
  });

  testWidgets('magic link success state uses entered email', (tester) async {
    final api = _FakeEllaApiService();
    await _pumpLogin(tester, api);

    await tester.tap(find.text('Continue With Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'xyz@gmail.com');
    await tester.tap(find.text('Send Me a Link'));
    await tester.pump();
    await tester.pump();

    expect(api.requestedEmail, 'xyz@gmail.com');
    expect(find.text('Check your Inbox!'), findsOneWidget);
    expect(find.text('Use a Different Email'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is RichText &&
            widget.text.toPlainText().contains('xyz@gmail.com'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('compact phones can still reach the email form', (tester) async {
    await _pumpLogin(tester, _FakeEllaApiService(), size: const Size(320, 568));

    await tester.tap(find.text('Continue With Email'));
    await tester.pump();

    expect(find.text('Sign In With Email'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Send Me a Link'), findsOneWidget);
  });
}
