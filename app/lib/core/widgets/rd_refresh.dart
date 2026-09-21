import 'package:flutter/material.dart';

import 'package:readendar/core/utils/platform_chrome.dart';

/// Pull-to-refresh wrapper.
///
/// Uses [RefreshIndicator.adaptive] on Apple platforms (Cupertino spinner) and
/// the Material indicator elsewhere. Same [onRefresh] / [child] contract as
/// [RefreshIndicator] so call-site migrations stay mechanical.
class RdRefresh extends StatelessWidget {
  const RdRefresh({
    required this.onRefresh,
    required this.child,
    super.key,
    this.displacement = 40,
    this.edgeOffset = 0,
  });

  final Future<void> Function() onRefresh;
  final Widget child;
  final double displacement;
  final double edgeOffset;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        displacement: displacement,
        edgeOffset: edgeOffset,
        child: child,
      );
    }
    return RefreshIndicator(
      onRefresh: onRefresh,
      displacement: displacement,
      edgeOffset: edgeOffset,
      child: child,
    );
  }
}
