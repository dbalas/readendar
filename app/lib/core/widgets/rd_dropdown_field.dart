import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

/// One option for [RdDropdownField].
class RdDropdownItem<T> {
  const RdDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.enabled = true,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool enabled;
}

/// Form single-select: glass modal sheet on Apple, Material bottom sheet
/// elsewhere. Field chrome stays adaptive via [RdFormSelectField].
///
/// Prefer this over raw [DropdownButtonFormField] — the Material overlay menu
/// is slow and inconsistent with OptionSelector / [showRdMenu].
class RdDropdownField<T> extends StatelessWidget {
  const RdDropdownField({
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
    this.label,
    this.hint,
    this.decoration,
  });

  final T? value;
  final List<RdDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? label;
  final String? hint;

  /// Optional Material decoration bridge. Prefer [label] / [hint] and item
  /// icons; [InputDecoration.prefixIcon] still maps to the field leading.
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context) {
    final selected = items.cast<RdDropdownItem<T>?>().firstWhere(
      (i) => i!.value == value,
      orElse: () => null,
    );
    final effectiveLabel = label ?? decoration?.labelText;
    final effectiveHint = hint ?? decoration?.hintText;
    final leading = selected?.icon != null
        ? Icon(selected!.icon, size: 18, color: selected.color)
        : decoration?.prefixIcon;

    return RdFormSelectField(
      label: effectiveLabel,
      hint: effectiveHint,
      valueText: selected?.label ?? '',
      enabled: onChanged != null,
      leading: leading,
      trailing: Icon(
        LucideIcons.chevronDown,
        size: 16,
        color: context.colors.fg3,
      ),
      onTap: onChanged == null
          ? null
          : () async {
              final next = await showRdMenu<T>(
                context: context,
                title: effectiveLabel,
                selectedValue: value,
                items: [
                  for (final item in items)
                    RdMenuItem(
                      value: item.value,
                      label: item.label,
                      icon: item.icon,
                      color: item.color,
                      enabled: item.enabled,
                    ),
                ],
              );
              // Selection haptic lives in [showRdMenu] — do not double-fire.
              if (next != null) onChanged!(next);
            },
    );
  }
}
