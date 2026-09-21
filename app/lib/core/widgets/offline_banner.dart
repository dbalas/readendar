import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

/// Slim banner shown under the status bar while the device has no network.
/// Informational only: cached data stays usable underneath.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({required this.online, super.key});

  final bool online;

  @override
  Widget build(BuildContext context) {
    if (online) return const SizedBox.shrink();
    final l = AppL10n.of(context);
    // Inverted attention banner: a dark bar with light text in light mode, a
    // light bar with dark text in dark mode: high contrast either way.
    final fg = context.colors.bg;
    return Material(
      color: context.colors.surfaceInv,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: ReadendarTokens.sp4,
            vertical: ReadendarTokens.sp2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(LucideIcons.wifiOff, size: 14, color: fg),
              const SizedBox(width: ReadendarTokens.sp3),
              Flexible(
                child: Text(
                  l.offlineBanner,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
