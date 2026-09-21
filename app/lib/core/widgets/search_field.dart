import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// Canonical in-app search field.
///
/// Material [SearchBar] on Android; branded glass pill on iOS/macOS.
/// Same API and behavior on both — style only.
///
/// Use this for library filters, catalog search, member lists, people search,
/// and any other free-text lookup. Do not invent per-screen [TextField] /
/// [InputDecoration] search UIs.
///
/// Do **not** set [autofocus] on root tabs or list/search surfaces. Autofocus
/// belongs on forms and confirm dialogs only — retained Offstage tabs would
/// otherwise reopen the keyboard when switching destinations.
class RdSearchField extends StatefulWidget {
  const RdSearchField({
    required this.hintText,
    super.key,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.trailing = const <Widget>[],
    this.autofocus = false,
    this.enabled = true,
    this.showClearButton = true,
    this.showSubmitButton = false,
    this.submitTooltip,
    this.compact = false,
  });

  /// Test key for the iOS glass search shell.
  static const iosFieldKey = Key('rd_search_field_ios');

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;

  /// Extra trailing actions after the optional clear / submit controls.
  final List<Widget> trailing;

  final bool autofocus;
  final bool enabled;
  final bool showClearButton;

  /// When true, the trailing Material search button submits. When false it
  /// still shows and focuses the field. Cupertino's in-pill search glyph
  /// submits in the same cases ([showSubmitButton] or [onSubmitted]); keyboard
  /// search still calls [onSubmitted].
  final bool showSubmitButton;
  final String? submitTooltip;

  /// Dense chrome for tight rows (filter under a title, beside a compact icon).
  /// Full-width library / catalog search stays the default size.
  final bool compact;

  @override
  State<RdSearchField> createState() => _RdSearchFieldState();
}

class _RdSearchFieldState extends State<RdSearchField> {
  TextEditingController? _owned;
  FocusNode? _ownedFocus;
  late TextEditingController _controller;
  late FocusNode _focus;

  TextEditingController get _effectiveController =>
      widget.controller ?? _owned!;

  FocusNode get _effectiveFocus => widget.focusNode ?? _ownedFocus!;

  @override
  void initState() {
    super.initState();
    _owned = widget.controller == null ? TextEditingController() : null;
    _ownedFocus = widget.focusNode == null ? FocusNode() : null;
    _controller = _effectiveController;
    _focus = _effectiveFocus;
    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant RdSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_onTextChanged);
      if (oldWidget.controller == null) {
        _owned?.dispose();
        _owned = null;
      }
      _owned = widget.controller == null ? TextEditingController() : null;
      _controller = _effectiveController;
      _controller.addListener(_onTextChanged);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focus.removeListener(_onFocusChanged);
      if (oldWidget.focusNode == null) {
        _ownedFocus?.dispose();
        _ownedFocus = null;
      }
      _ownedFocus = widget.focusNode == null ? FocusNode() : null;
      _focus = _effectiveFocus;
      _focus.addListener(_onFocusChanged);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _owned?.dispose();
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
    widget.onClear?.call();
  }

  void _submit() {
    widget.onSubmitted?.call(_controller.text);
  }

  void _onSearchIconPressed() {
    if (!widget.enabled) return;
    if (widget.showSubmitButton || widget.onSubmitted != null) {
      _submit();
      return;
    }
    _focus.requestFocus();
  }

  Widget _cupertinoSearchGlyph(ReadendarColors c, bool focused) {
    final icon = Icon(
      LucideIcons.search,
      size: widget.compact ? 14 : 17,
      color: focused ? c.accent : c.fg3,
    );
    if (!widget.enabled ||
        (!widget.showSubmitButton && widget.onSubmitted == null)) {
      return icon;
    }
    return Semantics(
      button: true,
      label: widget.submitTooltip ?? widget.hintText,
      child: CupertinoButton(
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        onPressed: _submit,
        child: icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return _cupertino(context);
    }
    return _material(context);
  }

  Widget _cupertino(BuildContext context) {
    final c = context.colors;
    final focused = _focus.hasFocus;
    final hasText = _controller.text.isNotEmpty;
    // Recessed soft fill (iOS search chrome) — no hard white “card” border
    // when idle; accent ring only while focused.
    final fill = focused
        ? c.surface1
        : Color.alphaBlend(c.fg1.withValues(alpha: 0.06), c.bg);

    final field = AnimatedContainer(
      key: RdSearchField.iosFieldKey,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(ReadendarTokens.radiusPill),
        border: Border.all(
          color: focused ? c.accent : c.fg1.withValues(alpha: 0),
          width: focused ? 1.5 : 0,
        ),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: Row(
        children: [
          Padding(
            padding: EdgeInsets.only(left: widget.compact ? 10 : 14),
            child: _cupertinoSearchGlyph(c, focused),
          ),
          Expanded(
            child: CupertinoTextField(
              controller: _controller,
              focusNode: _focus,
              enabled: widget.enabled,
              autofocus: widget.autofocus,
              placeholder: widget.hintText,
              placeholderStyle: TextStyle(
                color: c.fgFaint,
                fontSize: widget.compact ? 13 : 16,
                fontWeight: FontWeight.w400,
              ),
              style: TextStyle(
                color: c.fg1,
                fontSize: widget.compact ? 13 : 16,
                fontWeight: FontWeight.w400,
              ),
              padding: widget.compact
                  ? const EdgeInsets.fromLTRB(6, 6, 4, 6)
                  : const EdgeInsets.fromLTRB(8, 12, 4, 12),
              decoration: const BoxDecoration(),
              cursorColor: c.accent,
              textInputAction: TextInputAction.search,
              onChanged: widget.onChanged,
              onSubmitted:
                  widget.onSubmitted == null && !widget.showSubmitButton
                  ? null
                  : (_) => _submit(),
            ),
          ),
          if (widget.showClearButton && hasText)
            CupertinoButton(
              padding: EdgeInsets.symmetric(
                horizontal: widget.compact ? 6 : 10,
              ),
              minimumSize: Size.zero,
              onPressed: widget.enabled ? _clear : null,
              child: Icon(
                LucideIcons.x,
                size: widget.compact ? 14 : 16,
                color: c.fg3,
              ),
            )
          else
            SizedBox(width: widget.compact ? 8 : 12),
        ],
      ),
    );

    if (widget.trailing.isEmpty) {
      return field;
    }

    return Row(
      children: [
        Expanded(child: field),
        ...widget.trailing,
      ],
    );
  }

  Widget _material(BuildContext context) {
    final hasText = _controller.text.isNotEmpty;
    final compact = widget.compact;
    Widget trailIcon({
      required String tooltip,
      required VoidCallback? onPressed,
      required IconData icon,
    }) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        visualDensity: compact ? VisualDensity.compact : null,
        iconSize: compact ? 18 : 24,
        padding: compact ? EdgeInsets.zero : null,
        constraints: compact
            ? const BoxConstraints.tightFor(width: 32, height: 32)
            : null,
        icon: Icon(icon),
      );
    }

    final trailing = <Widget>[
      if (widget.showClearButton && hasText)
        trailIcon(
          tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
          onPressed: widget.enabled ? _clear : null,
          icon: LucideIcons.x,
        ),
      trailIcon(
        tooltip: widget.submitTooltip ?? widget.hintText,
        onPressed: widget.enabled ? _onSearchIconPressed : null,
        icon: LucideIcons.search,
      ),
      ...widget.trailing,
    ];

    final c = context.colors;
    // Flat stadium chrome — parchment/canvas already lifts white surfaces;
    // Material's default SearchBar elevation reads as a heavy floating blob.
    return SearchBar(
      controller: _controller,
      focusNode: _focus,
      enabled: widget.enabled,
      autoFocus: widget.autofocus,
      hintText: widget.hintText,
      hintStyle: WidgetStatePropertyAll(
        TextStyle(
          color: c.fgFaint,
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      textStyle: WidgetStatePropertyAll(
        TextStyle(
          color: c.fg1,
          fontSize: compact ? 13 : 16,
          fontWeight: FontWeight.w400,
        ),
      ),
      constraints: compact
          ? const BoxConstraints(minHeight: 32, maxHeight: 36)
          : null,
      padding: compact
          ? const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8))
          : null,
      textInputAction: TextInputAction.search,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted == null && !widget.showSubmitButton
          ? null
          : (_) => _submit(),
      trailing: trailing,
      elevation: const WidgetStatePropertyAll(0),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      backgroundColor: WidgetStatePropertyAll(c.surface1),
      overlayColor: WidgetStatePropertyAll(c.accent.withValues(alpha: 0.06)),
      side: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.focused)) {
          return BorderSide(color: c.accent, width: 1.5);
        }
        return BorderSide(color: c.line);
      }),
    );
  }
}
