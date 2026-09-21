import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/card.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';

class OptionSelectorItem<T> {
  const OptionSelectorItem({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.description,
  });

  final T value;
  final String label;
  final String? description;
  final IconData? icon;
  final Color? color;
}

class OptionSelector<T> extends StatelessWidget {
  const OptionSelector({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
    super.key,
    this.errorText,
    this.hideLabel = false,
    this.required = false,
  });

  final String label;
  final T value;
  final List<OptionSelectorItem<T>> items;
  final ValueChanged<T> onChanged;
  final String? errorText;
  final bool required;

  /// Hides the inline label above the field. Use when the surrounding context
  /// already makes the field's meaning obvious.
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final selected = items.firstWhere(
      (item) => item.value == value,
      orElse: () => items.first,
    );
    final cs = Theme.of(context).colorScheme;
    final color = selected.color ?? cs.primary;

    Future<void> open() async {
      final next = await showOptionSelectorSheet<T>(
        context: context,
        label: label,
        value: value,
        items: items,
      );
      if (next != null) onChanged(next);
    }

    if (usesCupertinoChrome(context)) {
      return RdFormSelectField(
        label: hideLabel ? null : label,
        required: required,
        valueText: selected.label,
        subtitle: selected.description,
        errorText: errorText,
        leading: _OptionIcon(icon: selected.icon, color: color),
        onTap: open,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!hideLabel) ...[
          RdFormFieldLabel(
            text: label,
            required: required,
            hasError: errorText != null,
          ),
          const SizedBox(height: 8),
        ],
        RdCard(
          padding: EdgeInsets.zero,
          onTap: open,
          child: Container(
            decoration: BoxDecoration(
              border: errorText == null
                  ? null
                  : Border.all(color: cs.error, width: 1.2),
              borderRadius: BorderRadius.circular(
                context.componentStyle.cardRadius,
              ),
            ),
            child: ListTile(
              leading: _OptionIcon(icon: selected.icon, color: color),
              title: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: selected.description == null
                  ? null
                  : Text(
                      selected.description!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.colors.fg3,
                      ),
                    ),
              trailing: const Icon(LucideIcons.chevronRight, size: 18),
            ),
          ),
        ),
        if (errorText != null) ...[
          const SizedBox(height: 6),
          RdFormFieldCaption(text: errorText!, isError: true),
        ],
      ],
    );
  }
}

Future<T?> showOptionSelectorSheet<T>({
  required BuildContext context,
  required String label,
  required T value,
  required List<OptionSelectorItem<T>> items,
}) {
  // Pickers use the glass modal sheet on Apple (same chrome as locale /
  // timezone / [showRdMenu]).
  return showRdModalSheet<T>(
    context: context,
    builder: (_) => Semantics(
      label: label,
      container: true,
      child: _OptionSelectorSheet<T>(
        title: label,
        value: value,
        items: items,
      ),
    ),
  );
}

class _OptionSelectorSheet<T> extends StatelessWidget {
  const _OptionSelectorSheet({
    required this.title,
    required this.value,
    required this.items,
  });

  final String title;
  final T value;
  final List<OptionSelectorItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final ios = usesCupertinoChrome(context);
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final maxHeight =
        (MediaQuery.sizeOf(context).height -
            viewPadding.top -
            viewPadding.bottom) *
        0.72;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ios
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                )
              : ListTile(
                  title: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: ios
                  ? const EdgeInsets.only(bottom: ReadendarTokens.sp4)
                  : const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: items.length,
              separatorBuilder: (_, _) =>
                  ios ? const SizedBox.shrink() : const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                final selected = item.value == value;
                final color =
                    item.color ?? Theme.of(context).colorScheme.primary;
                void pick() {
                  unawaited(RdHaptics.selection());
                  Navigator.of(context).pop(item.value);
                }

                if (ios) {
                  return _IosOptionRow<T>(
                    item: item,
                    selected: selected,
                    onTap: pick,
                  );
                }
                return RdCard(
                  padding: EdgeInsets.zero,
                  backgroundColor: selected
                      ? color.withValues(alpha: 0.10)
                      : null,
                  onTap: pick,
                  child: ListTile(
                    leading: _OptionIcon(icon: item.icon, color: color),
                    title: Text(
                      item.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: selected ? color : null,
                      ),
                    ),
                    subtitle: item.description == null
                        ? null
                        : Text(
                            item.description!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.colors.fg3),
                          ),
                    trailing: selected
                        ? Icon(LucideIcons.check, color: color, size: 18)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Picker row for the iOS glass modal sheet. Same IA as Material [ListTile]
/// without Material list / card chrome.
class _IosOptionRow<T> extends StatelessWidget {
  const _IosOptionRow({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final OptionSelectorItem<T> item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final color = item.color ?? c.fg1;
    final iconColor = rdSheetItemIconColor(context, color: item.color);
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(item.icon, size: 20, color: iconColor),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: color,
                        ),
                      ),
                      if (item.description != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.description!,
                          style: TextStyle(fontSize: 13, color: c.fg3),
                        ),
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 12),
                  Icon(LucideIcons.check, size: 18, color: c.accent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionIcon extends StatelessWidget {
  const _OptionIcon({required this.icon, required this.color});

  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(
          context.componentStyle.controlRadius,
        ),
      ),
      child: Icon(icon ?? LucideIcons.circle, size: 18, color: color),
    );
  }
}
