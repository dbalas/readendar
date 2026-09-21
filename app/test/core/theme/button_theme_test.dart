import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/theme/tokens.dart';

void main() {
  test('light outlined buttons use the strong semantic border', () {
    final side = buildLightTheme().outlinedButtonTheme.style!.side!.resolve({});

    expect(side!.color, ReadendarTokens.paper400);
  });
}
