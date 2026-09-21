import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/dark_theme.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/upload_network_image.dart';

void main() {
  testWidgets(
    'missing upload URLs show a placeholder instead of a broken image',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildLightTheme(),
          darkTheme: buildDarkTheme(),
          home: const Scaffold(
            body: SizedBox(
              width: 80,
              height: 80,
              child: UploadNetworkImage(url: ''),
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.imageOff), findsOneWidget);
      expect(find.byType(Image), findsNothing);
    },
  );
}
