import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  group('overlay themes separate floating surfaces from the scaffold', () {
    for (final entry in [
      ('light', buildLightTheme(), ReadendarTokens.paper300),
      ('dark', buildDarkTheme(), const Color(0x33F2F2F5)),
    ]) {
      final name = entry.$1;
      final theme = entry.$2;
      final line = entry.$3;

      test('$name popup menus use border + elevation', () {
        final popup = theme.popupMenuTheme;
        expect(popup.elevation, ReadendarTokens.overlayElevation);
        expect(popup.surfaceTintColor, Colors.transparent);
        final shape = popup.shape! as RoundedRectangleBorder;
        expect(shape.side.color, line);
      });

      test('$name dialogs use border + elevation', () {
        final dialog = theme.dialogTheme;
        expect(dialog.elevation, ReadendarTokens.overlayElevation);
        expect(dialog.surfaceTintColor, Colors.transparent);
        final shape = dialog.shape! as RoundedRectangleBorder;
        expect(shape.side.color, line);
      });

      test('$name bottom sheets use border + elevation', () {
        final sheet = theme.bottomSheetTheme;
        expect(sheet.elevation, ReadendarTokens.overlayElevation);
        expect(sheet.surfaceTintColor, Colors.transparent);
        final shape = sheet.shape! as RoundedRectangleBorder;
        expect(shape.side.color, line);
      });

      test('$name menu style uses border + elevation', () {
        final style = theme.menuTheme.style!;
        expect(
          style.elevation!.resolve(const {}),
          ReadendarTokens.overlayElevation,
        );
        expect(style.surfaceTintColor!.resolve(const {}), Colors.transparent);
        final shape =
            style.shape!.resolve(const {})! as RoundedRectangleBorder;
        expect(shape.side.color, line);
      });
    }
  });
}
