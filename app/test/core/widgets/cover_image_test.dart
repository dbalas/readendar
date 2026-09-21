import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/light_theme.dart';
import 'package:readendar/core/widgets/cover_image.dart';

void main() {
  test('usable cover URLs require a non-empty http(s) host', () {
    expect(isUsableCoverUrl(null), isFalse);
    expect(isUsableCoverUrl(''), isFalse);
    expect(isUsableCoverUrl('   '), isFalse);
    expect(isUsableCoverUrl('not-a-url'), isFalse);
    expect(isUsableCoverUrl('javascript:alert(1)'), isFalse);
    expect(isUsableCoverUrl('https://covers.example/dune.jpg'), isTrue);
    expect(isUsableCoverUrl(' http://covers.example/dune.jpg '), isTrue);
    expect(
      isUsableCoverUrl(
        'https://imagessl.casadellibro.com/a/l/t0/72/9788437604572.jpg',
      ),
      isTrue,
    );
    expect(
      isUsableCoverUrl(
        'https://imagessl4.casadellibro.com/a/l/t1/defecto4.jpg',
      ),
      isFalse,
    );
    expect(
      isUsableCoverUrl('https://covers.example/no-cover.gif'),
      isFalse,
    );
  });

  test('tiers snap nearby display widths onto shared buckets', () {
    expect(coverTierForWidth(36), CoverDisplayTier.thumb);
    expect(coverTierForWidth(52), CoverDisplayTier.thumb);
    expect(coverTierForWidth(78), CoverDisplayTier.card);
    expect(coverTierForWidth(88), CoverDisplayTier.card);
    expect(coverTierForWidth(104), CoverDisplayTier.card);
    expect(coverTierForWidth(132), CoverDisplayTier.hero);
    expect(coverTierForWidth(180), CoverDisplayTier.hero);
    expect(coverTierForWidth(220), CoverDisplayTier.full);
  });

  test('Open Library large covers fetch medium for list/chapter chips', () {
    const large =
        'https://covers.openlibrary.org/b/isbn/9780765311788-L.jpg?default=false';
    expect(
      coverFetchUrl(large, CoverDisplayTier.thumb),
      'https://covers.openlibrary.org/b/isbn/9780765311788-M.jpg?default=false',
    );
    expect(
      coverFetchUrl(large, CoverDisplayTier.card),
      'https://covers.openlibrary.org/b/isbn/9780765311788-M.jpg?default=false',
    );
    expect(coverFetchUrl(large, CoverDisplayTier.hero), large);
    expect(coverFetchUrl(large, CoverDisplayTier.full), large);
  });

  test('Open Library medium covers scale up for hero/detail', () {
    const medium = 'https://covers.openlibrary.org/b/id/14407898-M.jpg';
    expect(
      coverFetchUrl(medium, CoverDisplayTier.hero),
      'https://covers.openlibrary.org/b/id/14407898-L.jpg',
    );
    expect(coverFetchUrl(medium, CoverDisplayTier.card), medium);
  });

  test('owned CDN URLs are left untouched', () {
    const cdn = 'https://cdn.readendar.com/books/abc/cover.jpg';
    expect(coverFetchUrl(cdn, CoverDisplayTier.thumb), cdn);
  });

  test('mem-cache widths are stable per tier', () {
    expect(coverMemCacheWidth(CoverDisplayTier.thumb, 3), 168);
    expect(coverMemCacheWidth(CoverDisplayTier.card, 3), 264);
    expect(coverMemCacheWidth(CoverDisplayTier.hero, 3), 396);
    expect(coverMemCacheWidth(CoverDisplayTier.full, 3), isNull);
  });

  testWidgets('RemoteCoverImage shows a placeholder for unusable URLs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 56,
            height: 84,
            child: RemoteCoverImage(url: 'not-a-url'),
          ),
        ),
      ),
    );
    expect(find.byType(CoverMissingPlaceholder), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookMarked), findsOneWidget);
  });

  testWidgets('RemoteCoverImage uses the caller error widget', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildLightTheme(),
        home: const Scaffold(
          body: SizedBox(
            width: 56,
            height: 84,
            child: RemoteCoverImage(
              url: '',
              error: Text('caller-fallback'),
            ),
          ),
        ),
      ),
    );
    expect(find.text('caller-fallback'), findsOneWidget);
    expect(find.byType(CoverMissingPlaceholder), findsNothing);
  });
}
