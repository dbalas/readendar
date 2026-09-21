import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/banner_presets.dart';

void main() {
  // Pins the curated preset set. Add or remove a preset here and in the
  // order list together, or this test fails.
  test('canonical preset ids stay pinned', () {
    final got = [...bannerPresetOrder]..sort();
    expect(got, const [
      'amber',
      'aurora',
      'dusk',
      'ember',
      'forest',
      'garnet',
      'lagoon',
      'meadow',
      'ocean',
      'periwinkle',
      'pine',
      'plum',
      'sage',
      'sunset',
      'teal',
      'wine',
    ]);
  });

  test('order and registry are internally consistent', () {
    expect(bannerPresetOrder.toSet(), bannerPresets.keys.toSet());
    // Every offered id resolves to itself (no silent fallback to default).
    for (final id in bannerPresetOrder) {
      expect(bannerPresetOrDefault(id).id, id);
    }
  });

  test('normalizes legacy Hetzner path-style banner URLs', () {
    expect(
      bannerImageUrl(
        'https://fsn1.your-objectstorage.com/readendar-uploads-prod/banners/u1/photo.jpg',
      ),
      'https://readendar-uploads-prod.fsn1.your-objectstorage.com/banners/u1/photo.jpg',
    );
  });

  test('leaves non-Hetzner banner URLs untouched', () {
    const url = 'https://cdn.readendar.com/banners/u1/photo.jpg';
    expect(bannerImageUrl(url), url);
  });

  test('uses the API host for local MinIO banner URLs', () {
    expect(
      bannerImageUrl(
        'http://localhost:9100/readendar-uploads/banners/u1/photo.jpg',
        apiBaseUrl: 'http://10.0.2.2:8080',
      ),
      'http://10.0.2.2:9100/readendar-uploads/banners/u1/photo.jpg',
    );
  });

  test('local file banner paths use FileImage', () {
    final dir = Directory.systemTemp.createTempSync('rd-banner');
    addTearDown(() => dir.deleteSync(recursive: true));
    final file = File('${dir.path}/b.jpg')..writeAsBytesSync(const [1, 2, 3]);
    final deco = bannerFillDecoration(BannerStyle.image(file.path), 8);
    expect(deco.image?.image, isA<FileImage>());
  });
}
