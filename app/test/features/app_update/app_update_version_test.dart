import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/features/app_update/app_update_version.dart';

void main() {
  test('compares dotted marketing versions numerically', () {
    expect(compareDottedVersions('1.1.6', '1.1.6'), 0);
    expect(isNewerVersion('1.1.7', '1.1.6'), isTrue);
    expect(isNewerVersion('1.1.6', '1.1.7'), isFalse);
    expect(isNewerVersion('1.1.10', '1.1.9'), isTrue);
    expect(isNewerVersion('2.0.0', '1.9.9'), isTrue);
    expect(isNewerVersion('1.1.6', '1.1.6'), isFalse);
  });

  test('treats empty and junk segments as zero', () {
    expect(isNewerVersion('1.0.1', ''), isTrue);
    expect(compareDottedVersions('1', '1.0.0'), 0);
  });
}
