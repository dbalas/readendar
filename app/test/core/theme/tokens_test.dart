import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  group('ReadendarTokens', () {
    test('primary periwinkle500 matches design value', () {
      expect(ReadendarTokens.periwinkle500.toARGB32(), 0xFF7479D6);
    });

    test('ink900 (primary text in light mode)', () {
      expect(ReadendarTokens.ink900.toARGB32(), 0xFF0F1014);
    });

    test('dark surface base is deep ink-blue', () {
      expect(ReadendarTokens.darkBg.toARGB32(), 0xFF0E1018);
    });

    test('light canvas is warm papyrus', () {
      expect(ReadendarTokens.paperCanvas.toARGB32(), 0xFFFAF5EF);
    });

    test('overlay elevation matches floating menus', () {
      expect(ReadendarTokens.overlayElevation, 8);
      expect(ReadendarTokens.overlayShadowLight.toARGB32(), 0x2E0F1014);
      expect(ReadendarTokens.overlayShadowDark.toARGB32(), 0xBF000000);
    });

    test('spacing grid is 4-pt aligned (with half-step sp1)', () {
      const stops = [
        ReadendarTokens.sp0,
        ReadendarTokens.sp2,
        ReadendarTokens.sp3,
        ReadendarTokens.sp4,
        ReadendarTokens.sp5,
        ReadendarTokens.sp6,
        ReadendarTokens.sp7,
        ReadendarTokens.sp8,
      ];
      for (final s in stops) {
        if (s == 0 || s == 2) continue;
        expect(s % 4, 0, reason: '$s should be 4-pt aligned');
      }
    });
  });
}
