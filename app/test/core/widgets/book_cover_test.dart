import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/book_cover.dart';

void main() {
  testWidgets('renders fallback title for whitespace or non-http URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(
            title: 'Pedro Páramo',
            coverUrl: '  ',
          ),
        ),
      ),
    );
    expect(find.text('Pedro Páramo'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(
            title: 'Pedro Páramo',
            coverUrl: 'not-a-url',
          ),
        ),
      ),
    );
    expect(find.text('Pedro Páramo'), findsOneWidget);
  });

  testWidgets('renders fallback title when no URL', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(title: 'Pedro Páramo', author: 'Juan Rulfo'),
        ),
      ),
    );
    expect(find.text('Pedro Páramo'), findsOneWidget);
    expect(find.text('Juan Rulfo'), findsOneWidget);
  });

  testWidgets('sizes scale correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: Column(
            children: [
              BookCover(title: 'x', size: BookCoverSize.xs),
              BookCover(title: 'y', size: BookCoverSize.lg),
            ],
          ),
        ),
      ),
    );
    final sizes = tester.widgetList<SizedBox>(find.byType(SizedBox)).toList();
    expect(sizes.isNotEmpty, true);
  });

  testWidgets('overlays rating + notes badges when provided', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(title: 'x', rating: 4.5, hasNotes: true),
        ),
      ),
    );
    expect(find.byIcon(LucideIcons.stickyNote), findsOneWidget);
  });

  testWidgets('shows no badges for an unrated book with no notes', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(body: BookCover(title: 'x')),
      ),
    );
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(find.byIcon(LucideIcons.stickyNote), findsNothing);
  });

  testWidgets('showBookCoverPreview opens fullscreen viewer', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              onPressed: () => showBookCoverPreview(
                context,
                title: 'Pedro Páramo',
                author: 'Juan Rulfo',
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.text('Pedro Páramo'), findsWidgets);

    await tester.tap(find.byIcon(LucideIcons.x));
    await tester.pumpAndSettle();
    expect(find.byType(InteractiveViewer), findsNothing);
  });

  testWidgets('fallback title wraps into unused cover height then ellipsizes', (
    tester,
  ) async {
    const title =
        'One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookCover(title: title, size: BookCoverSize.md),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
    expect(paragraph.maxLines, greaterThan(3));
    expect(paragraph.overflow, TextOverflow.ellipsis);
  });

  testWidgets('small fallback covers still cap title lines', (tester) async {
    const title =
        'One Two Three Four Five Six Seven Eight Nine Ten Eleven Twelve';
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: BookCover(title: title, size: BookCoverSize.xs),
        ),
      ),
    );

    final paragraph = tester.renderObject<RenderParagraph>(find.text(title));
    expect(paragraph.maxLines, lessThanOrEqualTo(3));
    expect(paragraph.overflow, TextOverflow.ellipsis);
  });

  testWidgets('fallback title reserves inset when badges overlay', (
    tester,
  ) async {
    EdgeInsets readPadding() {
      final title = find.text('Long fallback title');
      final container = tester.widget<Container>(
        find
            .ancestor(
              of: title,
              matching: find.byWidgetPredicate((w) => w is Container),
            )
            .first,
      );
      return container.padding! as EdgeInsets;
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(title: 'Long fallback title'),
        ),
      ),
    );
    final plain = readPadding();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: BookCover(title: 'Long fallback title', rating: 4.5),
        ),
      ),
    );
    final inset = readPadding();

    expect(inset.top, greaterThan(plain.top));
    expect(inset.right, greaterThan(plain.right));
  });

  testWidgets('local image path prefers file over remote url', (tester) async {
    final file = File('${Directory.systemTemp.path}/readendar_cover_widget.jpg')
      ..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    addTearDown(() {
      if (file.existsSync()) file.deleteSync();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: Scaffold(
          body: BookCover(
            title: 'Local',
            coverUrl: 'https://covers.test/remote.jpg',
            localImagePath: file.path,
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    expect(find.text('Local'), findsNothing);
  });
}
