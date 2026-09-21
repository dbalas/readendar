import 'package:flutter_test/flutter_test.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations_es.dart';

void main() {
  group('localizedFailureMessage', () {
    test('localizes rate limits without exposing the server code', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const RateLimitedFailure(null, 'rate_limited'),
        ),
        'Demasiadas peticiones. Espera un momento.',
      );
    });

    test('includes the wait time in seconds when Retry-After is known', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const RateLimitedFailure(30, 'rate_limited'),
        ),
        'Demasiados intentos de acceso. Inténtalo de nuevo en 30 segundos.',
      );
    });

    test('rounds the wait time up to whole minutes past 60s', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const RateLimitedFailure(90, 'rate_limited'),
        ),
        'Demasiados intentos de acceso. Inténtalo de nuevo en 2 minutos.',
      );
    });

    test('localizes server-side feedback minimum validation', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const ValidationFailure('feedback_message_too_short'),
        ),
        'El mensaje debe tener al menos 10 caracteres.',
      );
    });

    test('localizes invalid_email distinctly from generic validation', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const ValidationFailure('invalid_email'),
        ),
        'Introduce un correo válido.',
      );
      expect(
        localizedFailureMessage(
          l,
          const ValidationFailure('other_validation'),
        ),
        'Revisa los datos introducidos.',
      );
    });

    test('localizes annotation body too long', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const ValidationFailure('annotation_body_too_long'),
        ),
        'Esta anotación debe tener como máximo 250000 caracteres.',
      );
    });

    test('expired session keeps the session-expired copy', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(l, const UnauthorizedFailure()),
        'Tu sesión ha expirado.',
      );
    });

    test('non-session 401 codes use generic copy', () {
      final l = AppL10nEs();

      expect(
        localizedFailureMessage(
          l,
          const UnauthorizedFailure('token_rejected'),
        ),
        'Algo ha ido mal. Inténtalo de nuevo.',
      );
    });
  });

  group('localizedErrorMessage', () {
    test('unwraps FailureException from async providers', () {
      final l = AppL10nEs();

      expect(
        localizedErrorMessage(
          l,
          const FailureException(RateLimitedFailure(null, 'rate_limited')),
        ),
        'Demasiadas peticiones. Espera un momento.',
      );
    });
  });
}
