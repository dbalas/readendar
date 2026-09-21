import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:readendar/features/feedback/feedback_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Uri> launched;
  late bool launchOk;

  setUp(() {
    launched = <Uri>[];
    launchOk = true;
    feedbackLaunchUrl = (uri) async {
      launched.add(uri);
      return launchOk;
    };
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/package_info'),
          (call) async => <String, dynamic>{
            'appName': 'Readendar',
            'packageName': 'com.readendar.app',
            'version': '0.1.0',
            'buildNumber': '1',
          },
        );
  });

  tearDown(() {
    feedbackLaunchUrl = (uri) =>
        throw StateError('feedbackLaunchUrl must be stubbed in tests');
  });

  Widget wrap(Widget child) => ProviderScope(
    child: MaterialApp(
      locale: const Locale('es'),
      theme: buildLightTheme(),
      localizationsDelegates: AppL10n.localizationsDelegates,
      supportedLocales: AppL10n.supportedLocales,
      home: child,
    ),
  );

  testWidgets('does not submit when the message is empty', (tester) async {
    await tester.pumpWidget(wrap(const FeedbackScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(RdButton, 'Enviar'));
    await tester.pumpAndSettle();

    expect(launched, isEmpty);
    expect(find.text('Escribe un mensaje primero.'), findsOneWidget);
  });

  testWidgets(
    'does not submit when the message has fewer than ten characters',
    (tester) async {
      await tester.pumpWidget(wrap(const FeedbackScreen()));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '123456789');
      await tester.tap(find.widgetWithText(RdButton, 'Enviar'));
      await tester.pumpAndSettle();

      expect(launched, isEmpty);
      expect(
        find.text('El mensaje debe tener al menos 10 caracteres.'),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), '1234567890');
      await tester.pump();

      expect(
        find.text('El mensaje debe tener al menos 10 caracteres.'),
        findsNothing,
      );
      expect(launched, isEmpty);
    },
  );

  testWidgets('form content stays inside bottom and landscape safe areas', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(500, 620);
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(
      left: 30,
      right: 20,
      bottom: 48,
    );
    tester.view.viewPadding = const FakeViewPadding(
      left: 30,
      right: 20,
      bottom: 48,
    );
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(const FeedbackScreen()));
    await tester.pumpAndSettle();

    final message = find.byType(TextField);
    expect(tester.getRect(message).left, greaterThanOrEqualTo(30));
    expect(tester.getRect(message).right, lessThanOrEqualTo(500 - 20));

    final submit = find.widgetWithText(RdButton, 'Enviar');
    await tester.scrollUntilVisible(
      submit,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(submit);
    await tester.pumpAndSettle();

    expect(tester.getRect(submit).bottom, lessThanOrEqualTo(620 - 48));
  });

  testWidgets('opens mailto and shows the thank-you screen', (tester) async {
    await tester.pumpWidget(wrap(const FeedbackScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Idea'));
    await tester.enterText(
      find.byType(TextField),
      'me gustaría un modo oscuro',
    );
    await tester.tap(find.widgetWithText(RdButton, 'Enviar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));

    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'mailto');
    expect(launched.single.path, feedbackSupportEmail);
    expect(launched.single.query, contains(Uri.encodeComponent('idea')));
    expect(find.text('¡Gracias!'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('shows an error when the mail app cannot open', (tester) async {
    launchOk = false;
    await tester.pumpWidget(wrap(const FeedbackScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextField),
      'me gustaría un modo oscuro',
    );
    await tester.tap(find.widgetWithText(RdButton, 'Enviar'));
    await tester.pumpAndSettle();

    expect(launched, hasLength(1));
    expect(find.text('¡Gracias!'), findsNothing);
    expect(
      find.text('No se pudo abrir el correo. Escríbenos a hello@readendar.com.'),
      findsOneWidget,
    );
  });
}
