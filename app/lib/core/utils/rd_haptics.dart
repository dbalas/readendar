import 'package:flutter/services.dart';

/// Canonical haptic feedback for user-initiated interactions.
///
/// Available on both platforms (no-op / soft on devices without a motor).
/// Prefer these helpers over ad-hoc [HapticFeedback] calls so selection /
/// success / error stay consistent.
abstract final class RdHaptics {
  /// Tab changes, toggle flips, picker ticks.
  static Future<void> selection() => HapticFeedback.selectionClick();

  /// Soft confirmation (save, non-destructive commit).
  static Future<void> light() => HapticFeedback.lightImpact();

  /// Stronger confirmation (complete event, finish book, subscribe).
  static Future<void> medium() => HapticFeedback.mediumImpact();

  /// Destructive confirm or hard failure.
  static Future<void> heavy() => HapticFeedback.heavyImpact();
}
