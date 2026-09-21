import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_progress.dart';

/// Standard "Sign in with Google" button following Google's branding
/// guidelines: the four-colour G mark on a neutral surface (white in light
/// mode, near-black in dark mode), centred medium-weight label.
///
/// The G mark colours are mandated by Google's brand guidelines and live in
/// `assets/icons/google-g.svg`; the surrounding surface uses semantic
/// Readendar colors so the chrome stays consistent with the rest of the
/// design system.
class GoogleSignInButton extends StatelessWidget {
  const GoogleSignInButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  /// Localized label, e.g. "Continue with Google".
  final String label;

  /// Null disables the button (greys it out).
  final VoidCallback? onPressed;

  /// Shows a spinner in place of the G mark and blocks taps.
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    // Match form-field / outlined control radius so OAuth sits with Rd inputs.
    final radius = BorderRadius.circular(ReadendarTokens.radiusCard);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: c.surface1,
        borderRadius: radius,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: radius,
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: c.lineStrong),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: loading
                      ? RdProgress(color: c.fg1)
                      : SvgPicture.asset(
                          'assets/icons/google-g.svg',
                          width: 20,
                          height: 20,
                          // Decorative: the adjacent label ("Continue with
                          // Google") already provides the accessible name.
                          excludeFromSemantics: true,
                        ),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.fg1,
                      fontFamily: ReadendarTokens.fontUi,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
