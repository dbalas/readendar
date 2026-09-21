import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/icon_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(debugResetIconFontsLoaded);

  test('Cupertino back/close glyphs ship from cupertino_icons', () {
    expect(CupertinoIcons.back.fontFamily, 'CupertinoIcons');
    expect(CupertinoIcons.back.fontPackage, 'cupertino_icons');
    expect(CupertinoIcons.xmark.fontFamily, 'CupertinoIcons');
    expect(CupertinoIcons.xmark.fontPackage, 'cupertino_icons');
  });

  test('rdBackIconData is Cupertino on Apple and Material elsewhere', () {
    expect(rdBackIconData(TargetPlatform.iOS), CupertinoIcons.back);
    expect(rdBackIconData(TargetPlatform.macOS), CupertinoIcons.back);
    expect(rdBackIconData(TargetPlatform.android), Icons.arrow_back);
    expect(rdBackIconData(TargetPlatform.linux), Icons.arrow_back);
  });

  test('rdCloseIconData is Cupertino on Apple and Material elsewhere', () {
    expect(rdCloseIconData(TargetPlatform.iOS), CupertinoIcons.xmark);
    expect(rdCloseIconData(TargetPlatform.macOS), CupertinoIcons.xmark);
    expect(rdCloseIconData(TargetPlatform.android), Icons.close);
    expect(rdCloseIconData(TargetPlatform.windows), Icons.close);
  });

  test('Lucide IconData still points at the package family Flutter looks up', () {
    expect(LucideIcons.chevronLeft.fontFamily, 'LucideIcons');
    expect(LucideIcons.chevronLeft.fontPackage, 'lucide_flutter');
    expect(kLucideFontFamilies, contains('packages/lucide_flutter/LucideIcons'));
    expect(kLucideFontFamilies, contains('lucide'));
  });

  testWidgets('ensureIconFontsLoaded registers the Lucide TTF', (tester) async {
    expect(debugIconFontsLoaded(), isFalse);
    final data = await rootBundle.load(kLucideFontAsset);
    expect(data.lengthInBytes, greaterThan(0));

    await ensureIconFontsLoaded();
    expect(debugIconFontsLoaded(), isTrue);

    await ensureIconFontsLoaded();
    expect(debugIconFontsLoaded(), isTrue);
  });

  testWidgets('iOS action icon theme builds Cupertino back and close', (
    tester,
  ) async {
    final theme = rdCupertinoActionIconTheme();
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          platform: TargetPlatform.iOS,
          actionIconTheme: theme,
        ),
        home: Builder(
          builder: (context) {
            captured = context;
            return const SizedBox();
          },
        ),
      ),
    );

    final back = theme.backButtonIconBuilder!(captured);
    final close = theme.closeButtonIconBuilder!(captured);
    expect(back, isA<Icon>());
    expect(close, isA<Icon>());
    expect((back as Icon).icon, CupertinoIcons.back);
    expect((close as Icon).icon, CupertinoIcons.xmark);
  });
}
