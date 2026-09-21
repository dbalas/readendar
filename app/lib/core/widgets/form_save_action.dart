import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/widgets/rd_button.dart';

/// The canonical AppBar save action for full-screen forms (book, event,
/// profile, notes). Always renders an explicit icon + localized text action;
/// [label] can override the visible text when it intentionally differs from
/// [tooltip]. Shows a spinner while [saving] and exposes [tooltip] for
/// accessibility.
class FormSaveAction extends StatelessWidget {
  const FormSaveAction({
    required this.onPressed,
    required this.tooltip,
    this.saving = false,
    this.label,
    super.key,
  });

  /// Null disables the action (e.g. edit forms with no unsaved changes).
  final VoidCallback? onPressed;
  final String tooltip;
  final bool saving;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final visibleLabel = label ?? tooltip;
    return Tooltip(
      message: tooltip,
      child: RdButton.plain(
        label: visibleLabel,
        icon: LucideIcons.save,
        loading: saving,
        onPressed: onPressed,
      ),
    );
  }
}
