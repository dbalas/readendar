import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/network/media_urls.dart';

void main() {
  test('normalizes legacy Hetzner path-style upload URLs', () {
    expect(
      resolveUploadAssetUrl(
        'https://fsn1.your-objectstorage.com/readendar-uploads-prod/covers/b1/photo.jpg',
      ),
      'https://readendar-uploads-prod.fsn1.your-objectstorage.com/covers/b1/photo.jpg',
    );
  });

  test('leaves non-Hetzner upload URLs untouched', () {
    const url = 'https://cdn.readendar.com/covers/b1/photo.jpg';
    expect(resolveUploadAssetUrl(url), url);
  });

  test('uses the API host for local MinIO upload URLs', () {
    expect(
      resolveUploadAssetUrl(
        'http://localhost:9100/readendar-uploads/covers/b1/photo.jpg',
        apiBaseUrl: 'http://10.0.2.2:8080',
      ),
      'http://10.0.2.2:9100/readendar-uploads/covers/b1/photo.jpg',
    );
  });

  test('rewrites 127.0.0.1 MinIO URLs for emulators', () {
    expect(
      resolveUploadAssetUrl(
        'http://127.0.0.1:9100/readendar-uploads/covers/b1/photo.jpg',
        apiBaseUrl: 'http://10.0.2.2:8080',
      ),
      'http://10.0.2.2:9100/readendar-uploads/covers/b1/photo.jpg',
    );
  });

  test('rejects empty and non-http upload URLs', () {
    expect(isUsableUploadUrl(''), isFalse);
    expect(isUsableUploadUrl('not-a-url'), isFalse);
    expect(
      isUsableUploadUrl('http://localhost:9100/readendar-uploads/x.png'),
      isTrue,
    );
  });
}
