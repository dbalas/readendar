import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/features/feedback/feedback_mail.dart';
import 'package:readendar/features/product_feedback/product_feedback_modal.dart';

void main() {
  late List<Uri> launched;
  late bool launchOk;

  setUp(() {
    launched = <Uri>[];
    launchOk = true;
    feedbackLaunchUrl = (uri) async {
      launched.add(uri);
      return launchOk;
    };
  });

  tearDown(() {
    feedbackLaunchUrl = (uri) =>
        throw StateError('feedbackLaunchUrl must be stubbed in tests');
  });

  Widget wrap(Widget child) => MaterialApp(
    locale: const Locale('es'),
    theme: buildLightTheme(),
    localizationsDelegates: AppL10n.localizationsDelegates,
    supportedLocales: AppL10n.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('shows general copy and returns share on CTA', (tester) async {
    ProductFeedbackModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showProductFeedbackModal(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('¿Cómo va Readendar?'), findsOneWidget);
    expect(
      find.text(
        'Si algo falla, no encaja o echas de menos una pieza en cualquier parte de la app, cuéntanoslo. Lo leemos todo.',
      ),
      findsOneWidget,
    );
    expect(find.text('Enviar feedback'), findsOneWidget);
    expect(find.text('BETA'), findsNothing);

    await tester.tap(find.text('Enviar feedback'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, ProductFeedbackModalResult.share);
  });

  testWidgets('returns dismissed on Not now', (tester) async {
    ProductFeedbackModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showProductFeedbackModal(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(result, ProductFeedbackModalResult.dismissed);
    expect(launched, isEmpty);
  });

  testWidgets('CTA opens mailto to hello@readendar.com', (tester) async {
    ProductFeedbackModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showProductFeedbackModalAndMail(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Enviar feedback'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, ProductFeedbackModalResult.share);
    expect(launched, hasLength(1));
    expect(launched.single.scheme, 'mailto');
    expect(launched.single.path, feedbackSupportEmail);
    expect(find.text('Enviar comentarios'), findsNothing);
  });

  testWidgets('CTA shows an error toast when mail cannot open', (tester) async {
    launchOk = false;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              await showProductFeedbackModalAndMail(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Enviar feedback'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(launched, hasLength(1));
    expect(launched.single.path, feedbackSupportEmail);
    expect(
      find.text('No se pudo abrir el correo. Escríbenos a hello@readendar.com.'),
      findsOneWidget,
    );
  });

  testWidgets('Not now does not open mail', (tester) async {
    ProductFeedbackModalResult? result;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showProductFeedbackModalAndMail(context);
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Ahora no'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(result, ProductFeedbackModalResult.dismissed);
    expect(launched, isEmpty);
  });
}
