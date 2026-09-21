import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/utils/platform_chrome.dart';

/// Platform-adaptive indeterminate progress indicator.
///
/// Cupertino activity indicator on iOS/macOS; Material circular elsewhere.
/// Same semantic role on both platforms — style only.
class RdProgress extends StatelessWidget {
  const RdProgress({
    super.key,
    this.strokeWidth = 2,
    this.color,
    this.size = 18,
  });

  /// Material stroke width (ignored on Cupertino).
  final double strokeWidth;

  /// Tint. Falls back to theme primary / Cupertino default.
  final Color? color;

  /// Box size for inline/button spinners.
  final double size;

  /// Full-page centered loading body.
  static Widget centered({Key? key, Color? color}) => Center(
    child: RdProgress(key: key, size: 36, strokeWidth: 3, color: color),
  );

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return SizedBox(
        width: size,
        height: size,
        child: CupertinoActivityIndicator(color: color, radius: size / 2),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
      ),
    );
  }
}
