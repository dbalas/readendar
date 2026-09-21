import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/event_icon.dart';

// BadgedCover reads AppL10n for the badge semantic labels, so the harness
// needs the localization delegates wired like the real app.
Widget _wrap(Widget child) => MaterialApp(
  theme: buildLightTheme(),
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group('CoverBadge', () {
    testWidgets('renders an icon variant', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const CoverBadge(background: Colors.black, icon: Icons.check_rounded),
        ),
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    });

    testWidgets('renders a label variant', (tester) async {
      await tester.pumpWidget(
        _wrap(const CoverBadge(background: Colors.black, label: '+3')),
      );
      expect(find.text('+3'), findsOneWidget);
    });
  });

  group('BadgedCover', () {
    Widget cover() => const SizedBox(width: 32, height: 48);

    testWidgets('always shows the event type icon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          BadgedCover(
            cover: cover(),
            coverWidth: 32,
            eventType: EventType.deadline,
          ),
        ),
      );
      expect(find.byIcon(EventType.deadline.icon), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });

    testWidgets('shows +N counter only when there are extra events', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BadgedCover(
            cover: cover(),
            coverWidth: 32,
            eventType: EventType.start,
            extraCount: 2,
          ),
        ),
      );
      expect(find.text('+2'), findsOneWidget);
    });

    testWidgets('omits the counter when there are no extra events', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          BadgedCover(
            cover: cover(),
            coverWidth: 32,
            eventType: EventType.finish,
          ),
        ),
      );
      expect(find.textContaining('+'), findsNothing);
    });
  });
}
