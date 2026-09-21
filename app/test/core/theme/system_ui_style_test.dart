import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/system_ui_style.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  testWidgets(
    'dark theme publishes a dark navigation bar declaratively',
    (tester) async {
      await tester.pumpWidget(
        const ReadendarSystemUiStyle(
          brightness: Brightness.dark,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: ColoredBox(
              color: ReadendarTokens.darkBg,
              child: SizedBox.expand(),
            ),
          ),
        ),
      );
      await tester.pump();

      final region = tester.widget<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      );
      expect(
        region.value.systemNavigationBarColor,
        ReadendarTokens.darkBg,
      );
      expect(
        region.value.systemNavigationBarIconBrightness,
        Brightness.light,
      );
      expect(region.value.systemNavigationBarContrastEnforced, isFalse);
      expect(
        SystemChrome.latestStyle?.systemNavigationBarColor,
        ReadendarTokens.darkBg,
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarIconBrightness,
        Brightness.light,
      );
      expect(
        SystemChrome.latestStyle?.systemNavigationBarContrastEnforced,
        isFalse,
      );
    },
  );

  test('light theme keeps dark navigation buttons on the papyrus canvas', () {
    final style = readendarSystemUiOverlayStyle(Brightness.light);

    expect(style.systemNavigationBarColor, ReadendarTokens.paperCanvas);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.systemNavigationBarContrastEnforced, isFalse);
  });
}
