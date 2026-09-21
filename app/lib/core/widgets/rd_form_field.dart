import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';

/// Shared Apple-platform chrome for form text + select fields: recessed soft
/// fill, rounded rect, accent ring while focused, error ring when invalid.
///
/// Glass is forbidden on form fields (see AGENTS). Material callers usually
/// skip this shell — [TextField] already owns its outline via theme.
class RdFormFieldShell extends StatelessWidget {
  const RdFormFieldShell({
    required this.child,
    super.key,
    this.focused = false,
    this.enabled = true,
    this.hasError = false,
    this.onTap,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final bool focused;
  final bool enabled;
  final bool hasError;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;

  static const Key iosShellKey = Key('rd.form.field.shell.ios');

  /// Shared content inset for Apple text + select fields (keeps heights aligned).
  static const EdgeInsets iosContentPadding = EdgeInsets.fromLTRB(
    14,
    14,
    14,
    14,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = !enabled
        ? Color.alphaBlend(c.fg1.withValues(alpha: 0.04), c.bg)
        : focused
        ? c.surface1
        : Color.alphaBlend(c.fg1.withValues(alpha: 0.06), c.bg);
    final borderColor = hasError
        ? c.danger
        : focused
        ? c.accent
        : c.fg1.withValues(alpha: 0);
    final borderWidth = hasError || focused ? 1.5 : 0.0;

    final body = AnimatedContainer(
      key: iosShellKey,
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      padding: padding,
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(context.componentStyle.cardRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: focused && !hasError
            ? [
                BoxShadow(
                  color: c.accent.withValues(alpha: 0.14),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ]
            : const [],
      ),
      child: child,
    );

    if (onTap == null) return body;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: body,
    );
  }
}

/// Label + optional helper/error caption used above/below Cupertino fields.
///
/// Use [decoration] for [InputDecoration] labels so Material and Cupertino
/// paths share the same required-field asterisk styling.
class RdFormFieldLabel extends StatelessWidget {
  const RdFormFieldLabel({
    required this.text,
    super.key,
    this.required = false,
    this.hasError = false,
  });

  final String text;
  final bool required;
  final bool hasError;

  /// Widget label for `InputDecoration.label` — preferred over `labelText`.
  static Widget inputLabel(
    BuildContext context,
    String text, {
    bool required = false,
    bool hasError = false,
  }) => RdFormFieldLabel(
    text: text,
    required: required,
    hasError: hasError,
  );

  /// Applies a shared Rd label to an [InputDecoration].
  static InputDecoration decoration(
    BuildContext context, {
    required String labelText,
    bool required = false,
    InputDecoration decoration = const InputDecoration(),
  }) {
    final hasError =
        decoration.errorText != null && decoration.errorText!.isNotEmpty;
    return decoration.copyWith(
      label: inputLabel(
        context,
        labelText,
        required: required,
        hasError: hasError,
      ),
    );
  }

  TextStyle _labelStyle(BuildContext context) => TextStyle(
    fontSize: 12,
    color: hasError ? Theme.of(context).colorScheme.error : context.colors.fg3,
    fontWeight: FontWeight.w600,
  );

  @override
  Widget build(BuildContext context) {
    final style = _labelStyle(context);
    if (!required) {
      return Text(text, style: style);
    }
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text, style: style),
          TextSpan(
            text: ' *',
            style: style.copyWith(color: context.colors.danger),
          ),
        ],
      ),
    );
  }
}

class RdFormFieldCaption extends StatelessWidget {
  const RdFormFieldCaption({
    required this.text,
    super.key,
    this.isError = false,
  });

  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 12,
        color: isError
            ? Theme.of(context).colorScheme.error
            : context.colors.fg3,
      ),
    );
  }
}

bool _inputDecorationHasError(InputDecoration decoration) =>
    decoration.errorText != null && decoration.errorText!.isNotEmpty;

/// Tall fields start text at the top. Pin the empty-state label/hint there too
/// so it is not vertically centered in the extra lines.
bool _rdTextFieldIsMultiline({
  required int? maxLines,
  required int? minLines,
  required bool expands,
}) {
  if (expands) return true;
  if (minLines != null && minLines > 1) return true;
  return maxLines != 1;
}

InputDecoration _materialTextDecoration(
  InputDecoration decoration, {
  required bool multiline,
}) {
  var next = decoration;
  if (multiline && next.alignLabelWithHint != true) {
    next = next.copyWith(alignLabelWithHint: true);
  }
  if (_inputDecorationHasError(next) || next.helperText != null) {
    return _materialDecorationWithoutInlineCaption(next);
  }
  return next;
}

/// Material [InputDecorator] ellipsizes inline [errorText] on one line unless
/// [errorMaxLines] is set. iOS already renders captions below the shell — mirror
/// that on Android so localized validation copy stays fully readable.
InputDecoration _materialDecorationWithoutInlineCaption(InputDecoration d) {
  final hasError = _inputDecorationHasError(d);
  return d.copyWith(
    errorText: hasError ? '' : null,
    errorStyle: hasError
        ? const TextStyle(fontSize: 0, height: 0, color: Colors.transparent)
        : null,
    helperText: null,
  );
}

Widget _materialFieldCaptionRow({
  required BuildContext context,
  required InputDecoration decoration,
  bool showCounter = false,
  int charCount = 0,
  int? maxLength,
}) {
  final hasError = _inputDecorationHasError(decoration);
  final helper = decoration.helperText;
  if (!hasError && helper == null && !showCounter) {
    return const SizedBox.shrink();
  }
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 6),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: hasError
                ? RdFormFieldCaption(text: decoration.errorText!, isError: true)
                : helper != null
                ? RdFormFieldCaption(text: helper)
                : const SizedBox.shrink(),
          ),
          if (showCounter)
            Text(
              '$charCount/$maxLength',
              style: TextStyle(
                fontSize: 12,
                color: hasError
                    ? Theme.of(context).colorScheme.error
                    : context.colors.fg3,
              ),
            ),
        ],
      ),
    ],
  );
}

/// Platform-adaptive text field. Material [TextField] on Android; soft-fill
/// [CupertinoTextField] shell on iOS/macOS. Prefer this over raw Material /
/// Cupertino fields at feature call sites.
class RdTextField extends StatefulWidget {
  const RdTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.decoration = const InputDecoration(),
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.textAlign = TextAlign.start,
    this.autofocus = false,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableInteractiveSelection,
    this.canRequestFocus = true,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.expands = false,
    this.inputFormatters,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.onEditingComplete,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration decoration;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool autofocus;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool? enableInteractiveSelection;
  final bool canRequestFocus;
  final int? maxLines;
  final int? minLines;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final bool expands;
  final List<TextInputFormatter>? inputFormatters;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final VoidCallback? onEditingComplete;

  static const Key iosFieldKey = Key('rd.text.field.ios');

  @override
  State<RdTextField> createState() => _RdTextFieldState();
}

class _RdTextFieldState extends State<RdTextField> {
  FocusNode? _ownedFocus;
  FocusNode get _focus => widget.focusNode ?? _ownedFocus!;
  int _charCount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.focusNode == null) {
      _ownedFocus = FocusNode(canRequestFocus: widget.canRequestFocus);
    }
    _focus.addListener(_onFocus);
    _charCount = widget.controller?.text.length ?? 0;
    widget.controller?.addListener(_onControllerText);
  }

  @override
  void didUpdateWidget(RdTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownedFocus)?.removeListener(_onFocus);
      if (widget.focusNode == null) {
        _ownedFocus ??= FocusNode(canRequestFocus: widget.canRequestFocus);
      } else if (oldWidget.focusNode == null) {
        _ownedFocus?.dispose();
        _ownedFocus = null;
      }
      _focus.addListener(_onFocus);
    }
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerText);
      widget.controller?.addListener(_onControllerText);
      _charCount = widget.controller?.text.length ?? _charCount;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerText);
    _focus.removeListener(_onFocus);
    _ownedFocus?.dispose();
    super.dispose();
  }

  void _syncMaterialFocusCapabilities() {
    // Only Material TextField needs the FocusNode flag kept in sync; Cupertino
    // overwrites it from [enabled] and locked fields use SelectableText.
    if (_focus.canRequestFocus != widget.canRequestFocus) {
      _focus.canRequestFocus = widget.canRequestFocus;
    }
  }

  void _onFocus() {
    if (mounted) setState(() {});
  }

  void _onControllerText() {
    final next = widget.controller?.text.length ?? 0;
    if (next != _charCount && mounted) {
      setState(() => _charCount = next);
    }
  }

  void _handleChanged(String value) {
    if (widget.maxLength != null && value.length != _charCount && mounted) {
      setState(() => _charCount = value.length);
    }
    widget.onChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    if (usesCupertinoChrome(context)) {
      return _cupertino(context);
    }
    _syncMaterialFocusCapabilities();
    final d = widget.decoration;
    final multiline = _rdTextFieldIsMultiline(
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      expands: widget.expands,
    );
    final needsExternalCaption =
        _inputDecorationHasError(d) || d.helperText != null;
    final field = TextField(
      controller: widget.controller,
      focusNode: _focus,
      decoration: _materialTextDecoration(d, multiline: multiline),
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      textCapitalization: widget.textCapitalization,
      style: widget.style,
      textAlign: widget.textAlign,
      textAlignVertical: multiline ? TextAlignVertical.top : null,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      autocorrect: widget.autocorrect,
      enableSuggestions: widget.enableSuggestions,
      enableInteractiveSelection: widget.enableInteractiveSelection,
      canRequestFocus: widget.canRequestFocus,
      maxLines: widget.maxLines,
      minLines: widget.minLines,
      maxLength: widget.maxLength,
      enabled: widget.enabled,
      readOnly: widget.readOnly,
      expands: widget.expands,
      inputFormatters: widget.inputFormatters,
      autofillHints: widget.autofillHints,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      onTap: widget.onTap,
      onEditingComplete: widget.onEditingComplete,
    );
    if (!needsExternalCaption) {
      return field;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        _materialFieldCaptionRow(context: context, decoration: d),
      ],
    );
  }

  Widget _cupertino(BuildContext context) {
    final c = context.colors;
    final d = widget.decoration;
    final focused = _focus.hasFocus;
    final hasError = d.errorText != null && d.errorText!.isNotEmpty;
    final labelWidget = d.label;
    final label = d.labelText;
    final hint = d.hintText;
    final helper = d.helperText;
    final prefix = d.prefixIcon;
    final prefixText = d.prefixText;
    final suffix = d.suffixIcon;
    final suffixText = d.suffixText;
    final enabled = widget.enabled && d.enabled;
    final multiline = widget.maxLines != null && (widget.maxLines ?? 1) > 1;
    final showCounter = widget.maxLength != null;

    final field = RdFormFieldShell(
      focused: focused,
      enabled: enabled,
      hasError: hasError,
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          if (prefix != null)
            Padding(
              padding: EdgeInsets.only(
                left: 12,
                top: multiline ? 12 : 0,
              ),
              child: IconTheme(
                data: IconThemeData(
                  size: 20,
                  color: focused ? c.accent : c.fg3,
                ),
                child: prefix,
              ),
            ),
          if (prefixText != null)
            Padding(
              padding: EdgeInsets.only(
                left: prefix == null ? 14 : 0,
                top: multiline ? 14 : 0,
              ),
              child: Text(
                prefixText,
                style: TextStyle(
                  color: enabled ? c.fg2 : c.fgDisabled,
                  fontSize: 16,
                ),
              ),
            ),
          Expanded(
            child: !widget.canRequestFocus
                // CupertinoTextFieldState sets focusNode.canRequestFocus =
                // enabled, so a locked-but-enabled field cannot opt out of
                // focus. SelectableText keeps copy/paste without a keyboard.
                ? Padding(
                    padding: prefixText != null
                        ? const EdgeInsets.fromLTRB(4, 14, 14, 14)
                        : RdFormFieldShell.iosContentPadding,
                    child: SelectableText(
                      widget.controller?.text ?? '',
                      style:
                          widget.style ??
                          TextStyle(
                            color: enabled ? c.fg1 : c.fgDisabled,
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                      textAlign: widget.textAlign,
                      maxLines: widget.maxLines,
                    ),
                  )
                : CupertinoTextField(
                    key: RdTextField.iosFieldKey,
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: enabled,
                    readOnly: widget.readOnly,
                    autofocus: widget.autofocus,
                    obscureText: widget.obscureText,
                    autocorrect: widget.autocorrect,
                    enableSuggestions: widget.enableSuggestions,
                    enableInteractiveSelection:
                        widget.enableInteractiveSelection ?? !widget.readOnly,
                    keyboardType: widget.keyboardType,
                    textInputAction: widget.textInputAction,
                    textCapitalization: widget.textCapitalization,
                    textAlign: widget.textAlign,
                    style:
                        widget.style ??
                        TextStyle(
                          color: enabled ? c.fg1 : c.fgDisabled,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                    placeholder: hint,
                    placeholderStyle:
                        d.hintStyle ??
                        TextStyle(
                          color: c.fgFaint,
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                    padding: prefixText != null
                        ? const EdgeInsets.fromLTRB(4, 14, 14, 14)
                        : RdFormFieldShell.iosContentPadding,
                    decoration: const BoxDecoration(),
                    cursorColor: c.accent,
                    maxLines: widget.maxLines,
                    minLines: widget.minLines,
                    maxLength: widget.maxLength,
                    expands: widget.expands,
                    inputFormatters: widget.inputFormatters,
                    autofillHints: widget.autofillHints,
                    onChanged: _handleChanged,
                    onSubmitted: widget.onSubmitted,
                    onTap: widget.onTap,
                    onEditingComplete: widget.onEditingComplete,
                  ),
          ),
          if (suffixText != null)
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Text(
                suffixText,
                style: TextStyle(color: c.fg3, fontSize: 14),
              ),
            ),
          if (suffix != null)
            Padding(
              padding: EdgeInsets.only(
                right: 8,
                top: multiline ? 8 : 0,
              ),
              child: IconTheme(
                data: IconThemeData(size: 18, color: c.fg3),
                child: suffix,
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelWidget != null) ...[
          labelWidget,
          const SizedBox(height: ReadendarTokens.sp2),
        ] else if (label != null) ...[
          RdFormFieldLabel(text: label, hasError: hasError),
          const SizedBox(height: ReadendarTokens.sp2),
        ],
        field,
        if (hasError || helper != null || showCounter) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: hasError
                    ? RdFormFieldCaption(text: d.errorText!, isError: true)
                    : helper != null
                    ? RdFormFieldCaption(text: helper)
                    : const SizedBox.shrink(),
              ),
              if (showCounter)
                Text(
                  '$_charCount/${widget.maxLength}',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasError
                        ? Theme.of(context).colorScheme.error
                        : c.fg3,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// Platform-adaptive [TextFormField] counterpart of [RdTextField].
class RdTextFormField extends FormField<String> {
  RdTextFormField({
    super.key,
    this.controller,
    String? initialValue,
    FocusNode? focusNode,
    InputDecoration? decoration,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    TextStyle? style,
    TextAlign textAlign = TextAlign.start,
    bool autofocus = false,
    bool obscureText = false,
    bool autocorrect = true,
    bool enableSuggestions = true,
    int? maxLines = 1,
    int? minLines,
    int? maxLength,
    super.enabled,
    bool readOnly = false,
    List<TextInputFormatter>? inputFormatters,
    Iterable<String>? autofillHints,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    VoidCallback? onTap,
    super.onSaved,
    super.validator,
    AutovalidateMode? autovalidateMode,
  }) : assert(
         initialValue == null || controller == null,
         'initialValue and controller cannot both be provided',
       ),
       super(
         initialValue: controller?.text ?? initialValue ?? '',
         autovalidateMode: autovalidateMode ?? AutovalidateMode.disabled,
         builder: (field) {
           final state = field as _RdTextFormFieldState;
           void onChangedHandler(String value) {
             field.didChange(value);
             onChanged?.call(value);
           }

           return UnmanagedRestorationScope(
             bucket: field.bucket,
             child: RdTextField(
               controller: state._effectiveController,
               focusNode: focusNode,
               decoration: (decoration ?? const InputDecoration()).copyWith(
                 errorText: field.errorText,
               ),
               keyboardType: keyboardType,
               textInputAction: textInputAction,
               textCapitalization: textCapitalization,
               style: style,
               textAlign: textAlign,
               autofocus: autofocus,
               obscureText: obscureText,
               autocorrect: autocorrect,
               enableSuggestions: enableSuggestions,
               maxLines: maxLines,
               minLines: minLines,
               maxLength: maxLength,
               enabled: enabled,
               readOnly: readOnly,
               inputFormatters: inputFormatters,
               autofillHints: autofillHints,
               onChanged: onChangedHandler,
               onSubmitted: onFieldSubmitted,
               onTap: onTap,
             ),
           );
         },
       );

  final TextEditingController? controller;

  @override
  FormFieldState<String> createState() => _RdTextFormFieldState();
}

class _RdTextFormFieldState extends FormFieldState<String> {
  TextEditingController? _controller;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!;

  @override
  RdTextFormField get widget => super.widget as RdTextFormField;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _controller = TextEditingController(text: value);
    } else {
      widget.controller!.addListener(_handleControllerChanged);
    }
  }

  @override
  void didUpdateWidget(RdTextFormField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      widget.controller?.addListener(_handleControllerChanged);
      if (oldWidget.controller != null && widget.controller == null) {
        _controller = TextEditingController.fromValue(
          oldWidget.controller!.value,
        );
      }
      if (widget.controller != null) {
        setValue(widget.controller!.text);
        if (oldWidget.controller == null) {
          _controller?.dispose();
          _controller = null;
        }
      }
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChange(String? value) {
    super.didChange(value);
    if (_effectiveController.text != value) {
      _effectiveController.text = value ?? '';
    }
  }

  @override
  void reset() {
    _effectiveController.text = widget.initialValue ?? '';
    super.reset();
  }

  void _handleControllerChanged() {
    if (_effectiveController.text != value) {
      didChange(_effectiveController.text);
    }
  }
}

/// Tappable form select / date / picker row with chrome matching [RdTextField].
///
/// Use for date tiles, book pickers, and any read-only field that opens a
/// sheet/picker. Material keeps an outlined card; Apple uses soft fill.
class RdFormSelectField extends StatelessWidget {
  const RdFormSelectField({
    required this.valueText,
    super.key,
    this.label,
    this.hint,
    this.subtitle,
    this.errorText,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.required = false,
  });

  final String? label;
  final bool required;
  final String valueText;
  final String? hint;
  final String? subtitle;
  final String? errorText;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  static const Key iosFieldKey = Key('rd.form.select.ios');

  @override
  Widget build(BuildContext context) {
    final hasValue = valueText.isNotEmpty;
    final display = hasValue ? valueText : (hint ?? '');
    final hasError = errorText != null && errorText!.isNotEmpty;
    final c = context.colors;

    if (usesCupertinoChrome(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            RdFormFieldLabel(
              text: label!,
              required: required,
              hasError: hasError,
            ),
            const SizedBox(height: ReadendarTokens.sp2),
          ],
          RdFormFieldShell(
            key: iosFieldKey,
            enabled: enabled,
            hasError: hasError,
            onTap: onTap,
            // Same inset as [RdTextField] Cupertino padding — height parity.
            child: Padding(
              padding: RdFormFieldShell.iosContentPadding,
              child: Row(
                children: [
                  if (leading != null) ...[
                    IconTheme(
                      data: IconThemeData(size: 20, color: c.fg3),
                      child: leading!,
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          display,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          strutStyle: const StrutStyle(
                            fontSize: 16,
                            height: 1,
                            forceStrutHeight: true,
                          ),
                          style: TextStyle(
                            fontSize: 16,
                            height: 1,
                            fontWeight: FontWeight.w400,
                            color: !hasValue
                                ? c.fgFaint
                                : enabled
                                ? c.fg1
                                : c.fgDisabled,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: c.fg3,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  trailing ??
                      Icon(
                        LucideIcons.chevronRight,
                        size: 16,
                        color: c.fg3,
                      ),
                ],
              ),
            ),
          ),
          if (hasError) ...[
            const SizedBox(height: 6),
            RdFormFieldCaption(text: errorText!, isError: true),
          ],
        ],
      );
    }

    // Material: outlined [InputDecorator] with [labelText] so theme
    // labelStyle / floatingLabelStyle (color + size) match [RdTextField].
    // Do not pass a Widget [label] — RdFormFieldLabel's explicit TextStyle
    // would override the floated theme styles.
    final theme = Theme.of(context);
    final idt = theme.inputDecorationTheme;
    final decoration = InputDecoration(
      labelText: label == null
          ? null
          : required
          ? '$label *'
          : label,
      hintText: hasValue ? null : hint,
      errorText: hasError ? errorText : null,
      enabled: enabled,
      floatingLabelBehavior: label == null
          ? FloatingLabelBehavior.auto
          : FloatingLabelBehavior.always,
      labelStyle: idt.labelStyle,
      floatingLabelStyle: hasError
          ? TextStyle(color: theme.colorScheme.error)
          : idt.floatingLabelStyle,
      hintStyle: idt.hintStyle,
      prefixIcon: leading == null
          ? null
          : IconTheme(
              data: IconThemeData(size: 20, color: c.fg3),
              child: leading!,
            ),
      suffixIcon:
          trailing ??
          Icon(
            LucideIcons.chevronRight,
            size: 18,
            color: c.fg3,
          ),
    ).applyDefaults(idt);

    final fieldDecoration = hasError
        ? _materialDecorationWithoutInlineCaption(decoration)
        : decoration;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(
            context.componentStyle.controlRadius,
          ),
          child: InputDecorator(
            decoration: fieldDecoration,
            isEmpty: !hasValue,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasValue ? valueText : '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: enabled ? c.fg1 : c.fgDisabled,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: c.fg3),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (hasError)
          _materialFieldCaptionRow(
            context: context,
            decoration: InputDecoration(errorText: errorText),
          ),
      ],
    );
  }
}
