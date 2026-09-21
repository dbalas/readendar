import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// "Sign in with Apple" control using the package's HIG-compliant button
/// (official Apple mark + black/white styles). Height matches the Google
/// button so the login stack stays aligned.
class AppleSignInButton extends StatelessWidget {
  const AppleSignInButton({
    required this.label,
    required this.onPressed,
    this.loading = false,
    super.key,
  });

  /// Localized label, e.g. "Continue with Apple".
  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;

  /// Shows a spinner overlay and blocks taps.
  final bool loading;

  static const _height = 52.0;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    final style = dark
        ? SignInWithAppleButtonStyle.white
        : SignInWithAppleButtonStyle.black;
    // Match Google + form-field radius (card), not the primary CTA pill.
    final radius = BorderRadius.circular(ReadendarTokens.radiusCard);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        height: _height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            SignInWithAppleButton(
              onPressed: enabled ? onPressed : null,
              text: label,
              height: _height,
              style: style,
              borderRadius: radius,
            ),
            if (loading)
              ColoredBox(
                color: c.fg1.withValues(alpha: 0.12),
                child: Center(
                  child: SizedBox.square(
                    dimension: 20,
                    // Spinner sits on Apple's black/white brand fill.
                    child: RdProgress(
                      color: dark ? c.bg : c.surface1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
