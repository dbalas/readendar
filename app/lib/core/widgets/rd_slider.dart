import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/utils/platform_chrome.dart';

/// Continuous value slider: [CupertinoSlider] on Apple platforms, Material
/// [Slider] elsewhere.
class RdSlider extends StatelessWidget {
  const RdSlider({
    required this.value,
    required this.onChanged,
    super.key,
    this.min = 0,
    this.max = 1,
    this.divisions,
    this.label,
    this.onChangeEnd,
  });

  final double value;
  final ValueChanged<double>? onChanged;
  final ValueChanged<double>? onChangeEnd;
  final double min;
  final double max;
  final int? divisions;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return CupertinoSlider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        divisions: divisions,
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      );
    }
    return Slider(
      value: value.clamp(min, max),
      min: min,
      max: max,
      divisions: divisions,
      label: label,
      onChanged: onChanged,
      onChangeEnd: onChangeEnd,
    );
  }
}
