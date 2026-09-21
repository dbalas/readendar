import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/rd_button.dart';

/// Standard error state for `AsyncValue.error` branches: a localized message
/// plus a Retry button. Pass [onRetry] (typically `() => ref.invalidate(...)`)
/// so the user can recover without leaving the screen.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({required this.error, required this.onRetry, super.key});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.circleAlert,
              size: 36,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              localizedErrorMessage(l, error),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            RdButton.secondary(
              label: l.actionRetry,
              icon: LucideIcons.refreshCw,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
