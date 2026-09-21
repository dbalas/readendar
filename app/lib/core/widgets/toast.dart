import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';

/// Semantic tone for [showRdToast] — drives the leading glyph soft fill.
enum RdToastTone { neutral, success, error }

/// Enter / exit timing for the ScaffoldMessenger shell. Kept slightly longer
/// than Material's 250ms default so the fade reads as fluid rather than a pop.
/// The shell is the sole owner of position/motion: a child translation would
/// restart when a new route registers its Scaffold and make the toast jump.
const AnimationStyle _rdToastAnimationStyle = AnimationStyle(
  duration: Duration(milliseconds: 350),
  reverseDuration: Duration(milliseconds: 280),
);

/// Canonical in-app toast (Deep-lift icon chip).
///
/// Do NOT hand-roll [SnackBar]s — route every transient success / error /
/// progress message through [showRdToast] (or [showRdFailureToast]) so light /
/// dark and iOS / Android share one look: surface chip, hairline, deep shadow,
/// status glyph.
///
/// Motion: enter/exit is owned only by the stable ScaffoldMessenger shell via
/// [_rdToastAnimationStyle]. Tap the chip (outside any action) to dismiss so it
/// does not block the UI.
void showRdToast(
  BuildContext context, {
  required String message,
  RdToastTone tone = RdToastTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 4000),
  bool clearExisting = true,
  ScaffoldMessengerState? messenger,
  bool allowMissingScaffold = false,
}) {
  assert(
    (actionLabel == null) == (onAction == null),
    'actionLabel and onAction must be provided together',
  );
  final resolved =
      messenger ??
      (allowMissingScaffold
          ? ScaffoldMessenger.maybeOf(context)
          : ScaffoldMessenger.of(context));
  if (resolved == null) return;
  if (clearExisting) {
    // Animates the current bar out and drops any queued ones — never
    // [removeCurrentSnackBar], which snaps without motion.
    resolved.clearSnackBars();
  }
  resolved.showSnackBar(
    buildRdSnackBar(
      context: context,
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
      duration: duration,
    ),
    snackBarAnimationStyle: _rdToastAnimationStyle,
  );
}

/// Error-tone toast with [localizedFailureMessage].
void showRdFailureToast(
  BuildContext context,
  Failure failure, {
  AppL10n? l10n,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 4000),
  bool clearExisting = true,
  ScaffoldMessengerState? messenger,
  bool allowMissingScaffold = false,
}) {
  final l = l10n ?? AppL10n.of(context);
  showRdToast(
    context,
    message: localizedFailureMessage(l, failure),
    tone: RdToastTone.error,
    actionLabel: actionLabel,
    onAction: onAction,
    duration: duration,
    clearExisting: clearExisting,
    messenger: messenger,
    allowMissingScaffold: allowMissingScaffold,
  );
}

/// Builds the floating [SnackBar] shell used by [showRdToast].
///
/// Prefer [showRdToast] at call sites. Use this only when a test or rare path
/// needs the [SnackBar] instance without showing it yet.
SnackBar buildRdSnackBar({
  required BuildContext context,
  required String message,
  RdToastTone tone = RdToastTone.neutral,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(milliseconds: 4000),
}) {
  return SnackBar(
    content: RdToastContent(
      message: message,
      tone: tone,
      actionLabel: actionLabel,
      onAction: onAction,
    ),
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    // Preserve deep-lift shadow outside the snackbar bounds.
    clipBehavior: Clip.none,
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(
      ReadendarTokens.sp4,
      0,
      ReadendarTokens.sp4,
      ReadendarTokens.sp4,
    ),
    duration: duration,
    dismissDirection: DismissDirection.down,
  );
}

/// Deep-lift icon-chip body (surface + border + deep shadow + status glyph).
class RdToastContent extends StatelessWidget {
  const RdToastContent({
    required this.message,
    this.tone = RdToastTone.neutral,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final String message;
  final RdToastTone tone;
  final String? actionLabel;
  final VoidCallback? onAction;

  void _dismiss(BuildContext context) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final theme = Theme.of(context);
    final iosLike =
        theme.platform == TargetPlatform.iOS ||
        theme.platform == TargetPlatform.macOS;
    final radius = BorderRadius.circular(
      iosLike ? ReadendarTokens.radiusPill : ReadendarTokens.radiusLg,
    );

    final IconData icon;
    final Color glyphBg;
    final Color glyphFg;
    switch (tone) {
      case RdToastTone.success:
        icon = LucideIcons.check;
        glyphBg = colors.successSoftBg;
        glyphFg = colors.successSoftFg;
      case RdToastTone.error:
        icon = LucideIcons.circleAlert;
        glyphBg = colors.dangerSoftBg;
        glyphFg = colors.dangerSoftFg;
      case RdToastTone.neutral:
        icon = LucideIcons.info;
        glyphBg = colors.accentSoftBg;
        glyphFg = colors.accentSoftFg;
    }

    return GestureDetector(
      onTap: () => _dismiss(context),
      behavior: HitTestBehavior.opaque,
      child: Material(
        color: Colors.transparent,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface1,
            borderRadius: radius,
            border: Border.all(color: colors.line),
            boxShadow: ReadendarTokens.toastDeepLiftShadows(theme.brightness),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              ReadendarTokens.sp3,
              ReadendarTokens.sp3,
              ReadendarTokens.sp5,
              ReadendarTokens.sp3,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: glyphBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 16, color: glyphFg),
                ),
                const SizedBox(width: ReadendarTokens.sp3),
                Expanded(
                  child: Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.fg1,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
                if (actionLabel != null && onAction != null) ...[
                  const SizedBox(width: ReadendarTokens.sp2),
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar(
                        reason: SnackBarClosedReason.action,
                      );
                      onAction!();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: colors.accent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: ReadendarTokens.sp2,
                        vertical: ReadendarTokens.sp1,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      textStyle: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(actionLabel!),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
