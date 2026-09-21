// Wraps a widget preview with the "add to home screen" affordance: the whole
// preview is tappable AND an icon-only "+" button floats over its top-right
// corner. Used for the EVENTS widget, which adds directly (there's nothing to
// configure). The QUOTES widget instead routes through its config screen — see
// [QuotesWidgetConfigScreen] and [widgets_screen.dart].
//
// The add orchestration (session provision, Android one-tap pin, iOS how-to
// sheet, success detection) lives in the shared [WidgetInstaller] mixin.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/features/widget/widget_install.dart';
import 'package:readendar/features/widget/widget_preview_card.dart';

class WidgetAddButton extends ConsumerStatefulWidget {
  const WidgetAddButton({required this.kind, required this.child, super.key});

  final WidgetKind kind;

  /// The preview to wrap — the whole thing becomes the tap target.
  final Widget child;

  @override
  ConsumerState<WidgetAddButton> createState() => _WidgetAddButtonState();
}

class _WidgetAddButtonState extends ConsumerState<WidgetAddButton>
    with WidgetsBindingObserver, WidgetInstaller<WidgetAddButton> {
  @override
  void initState() {
    super.initState();
    initWidgetInstaller();
  }

  @override
  void dispose() {
    disposeWidgetInstaller();
    super.dispose();
  }

  void _onTap() => installWidget(ref, widget.kind);

  @override
  Widget build(BuildContext context) {
    return WidgetPreviewCard(
      onTap: _onTap,
      tooltip: AppL10n.of(context).widgetAddToHome,
      child: widget.child,
    );
  }
}
