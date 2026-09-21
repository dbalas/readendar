import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/utils/rd_haptics.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';

/// Visual emphasis for a confirmation action.
///
/// - [primary]   → filled periwinkle button (default affirmative action).
/// - [destructive] → filled wine button (delete / leave / rotate / unsubscribe).
/// - [neutral]   → plain text button (secondary, non-affirmative choice).
enum ConfirmActionStyle { primary, destructive, neutral }

/// A single button in a confirmation dialog. Returning [value] from the dialog
/// lets call sites distinguish between more than two outcomes.
class ConfirmAction<T> {
  const ConfirmAction({
    required this.label,
    required this.value,
    this.icon,
    this.style = ConfirmActionStyle.primary,
  });

  final String label;
  final T value;
  final IconData? icon;
  final ConfirmActionStyle style;
}

/// The single, canonical confirmation modal for the whole app.
///
/// Do NOT hand-roll `AlertDialog`s for confirmations — present this instead via
/// [showConfirmDialog] (binary yes/no) or [showConfirmChoiceDialog] (3+ outcomes)
/// so every prompt shares one look, spacing, and button treatment.
///
/// Call sites must pass a header [icon] (and usually a [ConfirmAction.icon] /
/// `confirmIcon`) — bare title-only confirms are a UI contract violation.
///
/// On iOS/macOS this renders as [CupertinoAlertDialog]; elsewhere Material
/// [AlertDialog]. Call sites stay identical.
class ConfirmDialog<T> extends StatelessWidget {
  const ConfirmDialog({
    required this.cancel,
    required this.actions,
    super.key,
    this.icon,
    this.title,
    this.message,
    this.content,
    this.contentPadding,
  });

  /// Optional icon centered above the title and message.
  final IconData? icon;

  /// Optional bold heading. Omit for short, self-explanatory prompts.
  final String? title;

  /// Body text. Ignored when [content] is provided.
  final String? message;

  /// Rich body, used instead of [message] when a prompt needs more than a line.
  final Widget? content;

  /// Material [AlertDialog] content insets. Ignored on Cupertino. Null keeps
  /// the framework default.
  final EdgeInsetsGeometry? contentPadding;

  /// The dismissive choice (returns `null`). Rendered as a leading text button.
  /// Pass `null` to omit it (the dialog is still barrier-dismissible) — only do
  /// this when one of [actions] is itself the safe/non-destructive path.
  final ConfirmAction<T?>? cancel;

  /// Affirmative / alternative choices, rendered left-to-right after [cancel].
  final List<ConfirmAction<T>> actions;

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return _cupertino(context);
    }
    return _material(context);
  }

  Widget _material(BuildContext context) {
    final buttons = <Widget>[
      if (cancel != null) _materialButton(context, cancel!),
      for (final action in actions) _materialButton(context, action),
    ];
    final destructive = actions.any(
      (action) => action.style == ConfirmActionStyle.destructive,
    );
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: icon == null ? null : Icon(icon, size: 36),
      iconColor: destructive ? cs.error : cs.primary,
      // Match the compact `titleMedium` size used by the chapter-progress
      // dialog rather than the larger `titleLarge` AlertDialog default, so
      // every modal heading across the app reads at the same scale.
      title: title == null
          ? null
          : Text(title!, style: Theme.of(context).textTheme.titleMedium),
      content: content ?? (message == null ? null : Text(message!)),
      contentPadding: contentPadding,
      scrollable: true,
      // OverflowBar keeps actions horizontal whenever they fit, then centers
      // them if a genuinely narrow viewport forces wrapping.
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actionsOverflowButtonSpacing: 8,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
      actions: buttons,
    );
  }

  Widget _cupertino(BuildContext context) {
    final body =
        content ??
        (message == null ? null : Text(message!, textAlign: TextAlign.center));
    final titleChild = title == null && icon == null
        ? null
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 28),
                if (title != null) const SizedBox(height: 8),
              ],
              if (title != null) Text(title!, textAlign: TextAlign.center),
            ],
          );
    return CupertinoAlertDialog(
      title: titleChild,
      content: body == null
          ? null
          : Padding(padding: const EdgeInsets.only(top: 8), child: body),
      actions: [
        if (cancel != null) _cupertinoAction(context, cancel!),
        for (final action in actions) _cupertinoAction(context, action),
      ],
    );
  }

  Widget _materialButton(BuildContext context, ConfirmAction<dynamic> action) {
    void onPressed() {
      _hapticFor(action.style);
      Navigator.pop(context, action.value);
    }

    switch (action.style) {
      case ConfirmActionStyle.neutral:
        return action.icon == null
            ? TextButton(onPressed: onPressed, child: Text(action.label))
            : TextButton.icon(
                onPressed: onPressed,
                icon: Icon(action.icon),
                label: Text(action.label),
              );
      case ConfirmActionStyle.primary:
      case ConfirmActionStyle.destructive:
        final cs = Theme.of(context).colorScheme;
        final style = action.style == ConfirmActionStyle.destructive
            ? FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
              )
            : null;
        return action.icon == null
            ? FilledButton(
                onPressed: onPressed,
                style: style,
                child: Text(action.label),
              )
            : FilledButton.icon(
                onPressed: onPressed,
                style: style,
                icon: Icon(action.icon),
                label: Text(action.label),
              );
    }
  }

  Widget _cupertinoAction(
    BuildContext context,
    ConfirmAction<dynamic> action,
  ) {
    return CupertinoDialogAction(
      isDefaultAction: action.style == ConfirmActionStyle.primary,
      isDestructiveAction: action.style == ConfirmActionStyle.destructive,
      onPressed: () {
        _hapticFor(action.style);
        Navigator.pop(context, action.value);
      },
      child: Text(action.label),
    );
  }

  void _hapticFor(ConfirmActionStyle style) {
    unawaited(switch (style) {
      ConfirmActionStyle.destructive => RdHaptics.heavy(),
      ConfirmActionStyle.primary => RdHaptics.light(),
      ConfirmActionStyle.neutral => RdHaptics.selection(),
    });
  }
}

/// Presents a binary confirmation and resolves to `true` only if the user taps
/// the affirmative button. Cancelling or dismissing resolves to `false`.
///
/// This is the helper to reach for in the overwhelming majority of cases.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String confirmLabel,
  IconData? icon,
  String? title,
  String? message,
  Widget? content,
  EdgeInsetsGeometry? contentPadding,
  String? cancelLabel,
  IconData? confirmIcon,
  bool destructive = false,
  bool barrierDismissible = true,
}) async {
  final l = AppL10n.of(context);
  final dialog = ConfirmDialog<bool>(
    icon: icon,
    title: title,
    message: message,
    content: content,
    contentPadding: contentPadding,
    cancel: ConfirmAction<bool?>(
      label: cancelLabel ?? l.actionCancel,
      value: null,
      style: ConfirmActionStyle.neutral,
    ),
    actions: [
      ConfirmAction<bool>(
        label: confirmLabel,
        value: true,
        icon: confirmIcon,
        style: destructive
            ? ConfirmActionStyle.destructive
            : ConfirmActionStyle.primary,
      ),
    ],
  );
  final result = usesCupertinoChrome(context)
      ? await showCupertinoDialog<bool>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => dialog,
        )
      : await showDialog<bool>(
          context: context,
          barrierDismissible: barrierDismissible,
          builder: (_) => dialog,
        );
  return result ?? false;
}

/// Presents a destructive confirmation gated on the user re-typing [matchText]
/// exactly (trimmed). The confirm button stays disabled until the input matches,
/// so a slip can't cascade an irreversible action (wiping a library).
/// Resolves to `true` only when typed correctly and confirmed;
/// `false` on cancel/dismiss.
Future<bool> showTypeToConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  required String matchText,
  required String confirmLabel,
  IconData? icon,
  String? hintText,
}) async {
  final dialog = _TypeToConfirmDialog(
    title: title,
    message: message,
    matchText: matchText,
    confirmLabel: confirmLabel,
    icon: icon,
    hintText: hintText,
  );
  final result = usesCupertinoChrome(context)
      ? await showCupertinoDialog<bool>(
          context: context,
          builder: (_) => dialog,
        )
      : await showDialog<bool>(context: context, builder: (_) => dialog);
  return result ?? false;
}

class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog({
    required this.title,
    required this.message,
    required this.matchText,
    required this.confirmLabel,
    this.icon,
    this.hintText,
  });

  final String title;
  final String message;
  final String matchText;
  final String confirmLabel;
  final IconData? icon;
  final String? hintText;

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == widget.matchText.trim();

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return _cupertino(context);
    }
    return _material(context);
  }

  Widget _material(BuildContext context) {
    final l = AppL10n.of(context);
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      scrollable: true,
      icon: widget.icon == null ? null : Icon(widget.icon, size: 36),
      iconColor: cs.error,
      title: Text(
        widget.title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 12),
          RdTextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              hintText: widget.hintText ?? widget.matchText,
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actionsOverflowButtonSpacing: 8,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 4),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: _matches
              ? () {
                  unawaited(RdHaptics.heavy());
                  Navigator.pop(context, true);
                }
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }

  Widget _cupertino(BuildContext context) {
    final l = AppL10n.of(context);
    return CupertinoAlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Text(widget.message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          CupertinoTextField(
            controller: _controller,
            autofocus: true,
            autocorrect: false,
            enableSuggestions: false,
            placeholder: widget.hintText ?? widget.matchText,
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.actionCancel),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: _matches
              ? () {
                  unawaited(RdHaptics.heavy());
                  Navigator.pop(context, true);
                }
              : null,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

/// Presents a confirmation with three or more outcomes (e.g. keep / mark / delete).
/// Resolves to the chosen action's value, or `null` if cancelled/dismissed.
Future<T?> showConfirmChoiceDialog<T>({
  required BuildContext context,
  required List<ConfirmAction<T>> actions,
  IconData? icon,
  String? title,
  String? message,
  Widget? content,
  String? cancelLabel,
  bool includeCancel = true,
  bool barrierDismissible = true,
}) {
  final l = AppL10n.of(context);
  final dialog = ConfirmDialog<T>(
    icon: icon,
    title: title,
    message: message,
    content: content,
    cancel: includeCancel
        ? ConfirmAction<T?>(
            label: cancelLabel ?? l.actionCancel,
            value: null,
            style: ConfirmActionStyle.neutral,
          )
        : null,
    actions: actions,
  );
  if (usesCupertinoChrome(context)) {
    return showCupertinoDialog<T>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (_) => dialog,
    );
  }
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (_) => dialog,
  );
}
