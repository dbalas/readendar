import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Flutter user-facing widgets do not use string literals directly', () {
    final root = Directory('lib');
    final offenders = <String>[];
    final checks = <_LiteralCheck>[
	_LiteralCheck(
        RegExp(r"\b(?:Text|SelectableText)\s*\(\s*'(?!\$)(?:(?!\$\{)[^'])+'"),
        'Text/SelectableText must use AppL10n or dynamic data',
      ),
      _LiteralCheck(
        RegExp(r'\b(?:Text|SelectableText)\s*\(\s*"(?!\$)(?:(?!\$\{)[^"])+"'),
        'Text/SelectableText must use AppL10n or dynamic data',
      ),
      _LiteralCheck(
        RegExp(
          r"\b(?:labelText|hintText|helperText|semanticsLabel|tooltip|title)\s*:\s*'[^']+'",
        ),
        'UI string properties must use AppL10n',
      ),
      _LiteralCheck(
        RegExp(
          r'\b(?:labelText|hintText|helperText|semanticsLabel|tooltip|title)\s*:\s*"[^"]+"',
        ),
        'UI string properties must use AppL10n',
      ),
      _LiteralCheck(
        RegExp(r"\bSnackBar\s*\([^)]*Text\s*\(\s*'[^']+'"),
        'SnackBar text must use AppL10n',
      ),
      _LiteralCheck(
        RegExp(r'\bSnackBar\s*\([^)]*Text\s*\(\s*"[^"]+"'),
        'SnackBar text must use AppL10n',
      ),
      // Canonical transient feedback is showRdToast — no feature-local SnackBars.
      _LiteralCheck(
        RegExp(r'\bSnackBar\s*\('),
        'Use showRdToast / showRdFailureToast instead of SnackBar',
      ),
      _LiteralCheck(
        RegExp(r'\bshowSnackBar\s*\('),
        'Use showRdToast / showRdFailureToast instead of showSnackBar',
      ),
      _LiteralCheck(
        RegExp(r"\bAndroidNotificationDetails\s*\([^,\n]+,\s*'[^']+'"),
        'Notification channel names must use AppL10n',
      ),
      _LiteralCheck(
        RegExp(r'\bAndroidNotificationDetails\s*\([^,\n]+,\s*"[^"]+"'),
        'Notification channel names must use AppL10n',
      ),
    ];

    for (final entity in root.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.contains('/core/l10n/gen/')) continue;
      if (entity.path.contains('/features/debug/')) continue;
      // Toast owns the SnackBar shell.
      if (entity.path.endsWith('/core/widgets/toast.dart')) continue;
      if (entity.path.endsWith('/core/theme/light_theme.dart')) continue;
      if (entity.path.endsWith('/core/theme/dark_theme.dart')) continue;
      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        for (final check in checks) {
          if (check.pattern.hasMatch(line)) {
            offenders.add(
              '${entity.path}:${i + 1}: ${check.reason}: ${line.trim()}',
            );
          }
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: [
        'Do not put user-visible copy directly in Flutter widgets.',
        'Add a key to every app_*.arb file and use AppL10n.of(context).key.',
        ...offenders,
      ].join('\n'),
    );
  });
}

class _LiteralCheck {
  const _LiteralCheck(this.pattern, this.reason);

  final RegExp pattern;
  final String reason;
}
