import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';

void main() {
  group('BannerStyle.fromJson', () {
    test('null -> default', () {
      expect(BannerStyle.fromJson(null).isDefault, isTrue);
    });

    test('preset round-trip', () {
      final s = BannerStyle.fromJson(const {
        'type': 'preset',
        'preset': 'teal',
      });
      expect(s.kind, BannerKind.preset);
      expect(s.preset, 'teal');
      expect(s.toJson(), {'type': 'preset', 'preset': 'teal'});
    });

    test('image round-trip', () {
      final s = BannerStyle.fromJson(const {
        'type': 'image',
        'imageUrl': 'https://cdn.test/b.jpg',
      });
      expect(s.kind, BannerKind.image);
      expect(s.imageUrl, 'https://cdn.test/b.jpg');
      expect(s.toJson(), {
        'type': 'image',
        'imageUrl': 'https://cdn.test/b.jpg',
      });
    });

    test('default serializes to {type:default}', () {
      expect(const BannerStyle.defaultStyle().toJson(), {'type': 'default'});
    });

    test('unknown type degrades to default (forward-compat)', () {
      expect(BannerStyle.fromJson(const {'type': 'video'}).isDefault, isTrue);
      expect(BannerStyle.fromJson(const <String, dynamic>{}).isDefault, isTrue);
    });

    test('empty preset/url degrades to default', () {
      expect(
        BannerStyle.fromJson(const {'type': 'preset', 'preset': ''}).isDefault,
        isTrue,
      );
      expect(
        BannerStyle.fromJson(const {
          'type': 'image',
          'imageUrl': '  ',
        }).isDefault,
        isTrue,
      );
    });

    test('value equality', () {
      expect(
        const BannerStyle.preset('teal'),
        const BannerStyle.preset('teal'),
      );
      expect(
        const BannerStyle.preset('teal') == const BannerStyle.preset('wine'),
        isFalse,
      );
      expect(
        const BannerStyle.defaultStyle() == const BannerStyle.image('x'),
        isFalse,
      );
    });
  });

  test('AppUser parses and defaults homeBanner', () {
    final withBanner = AppUser.fromJson({
      'id': 'u1',
      'email': 'a@b.io',
      'displayName': 'Marina',
      'homeBanner': {'type': 'preset', 'preset': 'wine'},
    });
    expect(withBanner.homeBanner, const BannerStyle.preset('wine'));

    final without = AppUser.fromJson({
      'id': 'u1',
      'email': 'a@b.io',
      'displayName': 'Marina',
    });
    expect(without.homeBanner.isDefault, isTrue);
    expect(without.autoCreateStatusEvents, isFalse);
    expect(without.alwaysShowSpoilerQuotes, isFalse);

    final withFlag = AppUser.fromJson({
      'id': 'u1',
      'email': 'a@b.io',
      'displayName': 'Marina',
      'autoCreateStatusEvents': true,
      'alwaysShowSpoilerQuotes': true,
    });
    expect(withFlag.autoCreateStatusEvents, isTrue);
    expect(withFlag.alwaysShowSpoilerQuotes, isTrue);
    expect(
      withFlag.copyWith(displayName: 'Updated').alwaysShowSpoilerQuotes,
      isTrue,
    );
  });

}

Map<String, dynamic> _userJson() => {
  'id': 'u1',
  'email': 'a@b.io',
  'displayName': 'Marina',
};
