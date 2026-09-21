import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/utils/legal_urls.dart';

void main() {
  group('legal URLs always use the Spanish root', () {
    test('Spanish uses the site root', () {
      expect(
        privacyPolicyUrl('es').toString(),
        'https://readendar.com/legal/privacy',
      );
      expect(
        termsOfUseUrl('es-419').toString(),
        'https://readendar.com/legal/terms',
      );
    });

    test('non-Spanish tags still resolve to the Spanish legal pages', () {
      expect(
        privacyPolicyUrl('en').toString(),
        'https://readendar.com/legal/privacy',
      );
      expect(
        privacyPolicyUrl('de').toString(),
        'https://readendar.com/legal/privacy',
      );
      expect(
        privacyPolicyUrl('pt-BR').toString(),
        'https://readendar.com/legal/privacy',
      );
      expect(
        termsOfUseUrl('fr-CA').toString(),
        'https://readendar.com/legal/terms',
      );
    });
  });
}
