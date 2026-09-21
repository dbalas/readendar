import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/rd_context_menu.dart';
import 'package:readendar/core/widgets/rd_list_item_actions.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

ThemeData _iosTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: buildLightTheme().colorScheme,
  platform: TargetPlatform.iOS,
  cupertinoOverrideTheme: buildLightTheme().cupertinoOverrideTheme,
);

ThemeData _androidTheme() => buildLightTheme().copyWith(
  platform: TargetPlatform.android,
);

Future<void> _withIosPlatform(Future<void> Function() body) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Widget _app({required ThemeData theme, required Widget home}) => MaterialApp(
  locale: const Locale('es'),
  theme: theme,
  localizationsDelegates: AppL10n.localizationsDelegates,
  supportedLocales: AppL10n.supportedLocales,
  home: Scaffold(body: home),
);

Future<void> _openSwipe(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await gesture.moveBy(const Offset(-160, 0));
  await gesture.up();
  await tester.pumpAndSettle();
}

Widget _swipeRow({
  required ValueChanged<String> onSelected,
  double extent = 88,
  BorderSide? border,
}) => RdListItemActions(
  extent: extent,
  border: border,
  items: const [
    RdMenuItem(
      value: 'delete',
      label: 'Delete',
      icon: LucideIcons.trash2,
      destructive: true,
    ),
  ],
  onSelected: onSelected,
  child: const SizedBox(
    key: Key('swipe-row'),
    height: 72,
    width: double.infinity,
    child: Text('Row'),
  ),
);

void main() {
  testWidgets('swipe delete works on Material', (tester) async {
    var selected = '';
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: _swipeRow(onSelected: (v) => selected = v),
      ),
    );

    expect(find.byType(RdContextMenu), findsNothing);
    await _openSwipe(tester, find.byKey(const Key('swipe-row')));
    await tester.tap(find.byKey(const ValueKey('rd-swipe-action-delete')));
    await tester.pumpAndSettle();
    expect(selected, 'delete');
  });

  testWidgets('swipe delete works on Apple', (tester) async {
    await _withIosPlatform(() async {
      var selected = '';
      await tester.pumpWidget(
        _app(
          theme: _iosTheme(),
          home: _swipeRow(onSelected: (v) => selected = v),
        ),
      );

      expect(find.byType(RdContextMenu), findsNothing);
      await _openSwipe(tester, find.byKey(const Key('swipe-row')));
      await tester.tap(find.byKey(const ValueKey('rd-swipe-action-delete')));
      await tester.pumpAndSettle();
      expect(selected, 'delete');
    });
  });

  testWidgets('first swipe settles to the full action extent', (tester) async {
    const extent = 88.0;
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: _swipeRow(onSelected: (_) {}, extent: extent),
      ),
    );

    // Short first drag: still commits open instead of a thin red edge.
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('swipe-row'))),
    );
    await gesture.moveBy(const Offset(-40, 0));
    await gesture.up();
    await tester.pumpAndSettle();

    final slider = tester.widget<Transform>(
      find.byKey(const ValueKey('rd-swipe-slider')),
    );
    expect(slider.transform.getTranslation().x, closeTo(-extent, 0.5));

    final actionSize = tester.getSize(
      find.byKey(const ValueKey('rd-swipe-action-delete')),
    );
    expect(actionSize.width, closeTo(extent, 0.5));
    expect(actionSize.height, greaterThan(40));
  });

  testWidgets('optional accent border wraps the delete strip chrome', (
    tester,
  ) async {
    const accent = BorderSide(color: Color(0xFFCC6600), width: 2);
    await tester.pumpWidget(
      _app(
        theme: _androidTheme(),
        home: _swipeRow(onSelected: (_) {}, border: accent),
      ),
    );

    RoundedRectangleBorder? chromeShape;
    for (final material in tester.widgetList<Material>(find.byType(Material))) {
      final shape = material.shape;
      if (shape is RoundedRectangleBorder &&
          shape.side.color == accent.color &&
          shape.side.width == accent.width) {
        chromeShape = shape;
        break;
      }
    }
    expect(chromeShape, isNotNull);

    await _openSwipe(tester, find.byKey(const Key('swipe-row')));
    final actionRect = tester.getRect(
      find.byKey(const ValueKey('rd-swipe-action-delete')),
    );
    final chromeRect = tester.getRect(find.byType(RdListItemActions));
    // Rect.contains is half-open on the right/bottom edges; flush comparison
    // keeps the delete strip inside the framed chrome.
    expect(actionRect.left, greaterThanOrEqualTo(chromeRect.left));
    expect(actionRect.top, greaterThanOrEqualTo(chromeRect.top));
    expect(actionRect.right, lessThanOrEqualTo(chromeRect.right));
    expect(actionRect.bottom, lessThanOrEqualTo(chromeRect.bottom));
  });
}
