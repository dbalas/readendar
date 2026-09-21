import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/library_pane.dart';

void main() {
  testWidgets('openLibrosTab always selects owned books', (tester) async {
    late WidgetRef captured;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, ref, _) {
            captured = ref;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    openLibrosTab(captured);

    expect(captured.read(libraryPaneProvider), LibraryPane.books);
    expect(captured.read(tabIndexProvider), 1);
  });
}
