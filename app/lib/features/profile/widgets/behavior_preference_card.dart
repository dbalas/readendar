import 'dart:async';

import 'package:flutter/material.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/emphasized_text.dart';

/// Behavior preference surface with an icon, fully wrapping title, switch, and
/// explanatory bullets.
class BehaviorPreferenceCard extends StatelessWidget {
  const BehaviorPreferenceCard({
    required this.switchKey,
    required this.icon,
    required this.title,
    required this.bullets,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final Key switchKey;
  final String title;
  final List<String> bullets;
  final bool value;
  final ValueChanged<bool>? onChanged;

  void _set(bool next) {
    unawaited(RdHaptics.selection());
    onChanged?.call(next);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = context.colors;
    final descriptionStyle = theme.textTheme.bodySmall?.copyWith(
      color: colors.fg2,
      height: 1.4,
    );
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusCard),
        onTap: onChanged == null ? null : () => _set(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: colors.fg2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(title, style: theme.textTheme.titleSmall),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    key: switchKey,
                    value: value,
                    onChanged: onChanged == null ? null : _set,
                  ),
                ],
              ),
              if (bullets.isNotEmpty) ...[
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = 0; i < bullets.length; i++) ...[
                      if (i > 0) const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: colors.fg2,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: EmphasizedText(
                              bullets[i],
                              style: descriptionStyle,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
