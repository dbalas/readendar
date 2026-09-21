// Half-star rating picker shared by the rating+review sheet (and widget tests).

import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/cover_badge.dart';

/// Maps a horizontal offset within a 5-star row to a half-star value in
/// 0–5.0: each star is [starSize] wide, the left half yields `i - 0.5` and the
/// right half `i`. Left of the first half snaps to 0. Shared by tap and drag.
double ratingFromOffset(double dx, double starSize) {
  final halves = (dx / (starSize / 2)).ceil();
  return halves.clamp(0, 10) * 0.5;
}

/// Interactive 5-star row supporting half steps by **tap or horizontal drag**:
/// tap a half to set it, or slide across the row to scrub the rating up/down.
class HalfStarPicker extends StatelessWidget {
  const HalfStarPicker({
    required this.value,
    required this.onChanged,
    super.key,
    this.size = 44,
  });
  final double value;
  final ValueChanged<double> onChanged;
  final double size;

  void _emit(double dx) => onChanged(ratingFromOffset(dx, size));

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) => _emit(d.localPosition.dx),
      onHorizontalDragStart: (d) => _emit(d.localPosition.dx),
      onHorizontalDragUpdate: (d) => _emit(d.localPosition.dx),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              starIconForRating(value, i),
              size: size,
              color: context.colors.warning,
            ),
        ],
      ),
    );
  }
}
