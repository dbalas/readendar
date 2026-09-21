import 'package:flutter/material.dart';
import 'package:readendar/core/widgets/nav_box.dart' show NavBox;

/// A perfectly round numeric badge — shared shape/typography for every
/// "how many" indicator in the app (event count on the calendar icon, quote
/// count on the quotes [NavBox], etc.) so they all read as the same design
/// language instead of each screen inventing its own pill/pin shape. Long
/// counts shrink to fit via [FittedBox] rather than stretching the circle
/// into an oval, and cap at [max] (shown as "+max").
class CountBadge extends StatelessWidget {
  const CountBadge({
    required this.count,
    required this.color,
    required this.textColor,
    this.size = 20,
    this.max = 99,
    super.key,
  });

  final int count;
  final Color color;
  final Color textColor;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    final label = count > max ? '+$max' : '$count';
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
