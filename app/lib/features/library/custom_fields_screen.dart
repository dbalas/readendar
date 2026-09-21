import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_localizer.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/utils/platform_chrome.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/custom_field_icon.dart';
import 'package:readendar/core/widgets/empty_state.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/core/widgets/rd_create_action.dart';
import 'package:readendar/core/widgets/rd_dropdown_field.dart';
import 'package:readendar/core/widgets/rd_form_field.dart';
import 'package:readendar/core/widgets/rd_glass.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/rd_progress.dart';
import 'package:readendar/core/widgets/rd_switch_list_tile.dart';
import 'package:readendar/core/widgets/section_header.dart';
import 'package:readendar/core/widgets/settings_group.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/library/custom_fields_empty_art.dart';
import 'package:readendar/features/library/custom_fields_manage_cache.dart';
import 'package:uuid/uuid.dart';

/// Vertical gap between layout rows. Kept outside the drag proxy so feedback
/// matches the [SettingsGroup] card, not the card plus spacing.
const double _kFieldLayoutRowGap = 10;

class CustomFieldsScreen extends ConsumerStatefulWidget {
  const CustomFieldsScreen({super.key});
  @override
  ConsumerState<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends ConsumerState<CustomFieldsScreen> {
  List<BookDetailFieldLayoutItem>? _layout;
  Map<String, CustomFieldDefinition> _definitions = const {};
  bool _loading = true;
  Failure? _failure;
  bool _savingLayout = false;
  int _loadSeq = 0;
  final _listController = ScrollController();

  @override
  void initState() {
    super.initState();
    final cached = ref.read(customFieldsManageCacheProvider).read();
    if (cached != null) {
      _layout = cached.layout;
      _definitions = cached.definitions;
      _loading = false;
    }
    _load(silent: cached != null);
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    final seq = ++_loadSeq;
    if (!silent) {
      setState(() {
        _loading = true;
        _failure = null;
      });
    }
    final repo = ref.read(customFieldRepoProvider);
    final layoutResult = await repo.listLayout();
    if (!mounted || seq != _loadSeq) return;
    if (layoutResult.isErr) {
      if (_layout == null) {
        setState(() {
          _loading = false;
          _failure = layoutResult.failure;
        });
      }
      if (!silent || _layout == null) {
        showRdFailureToast(context, layoutResult.failure!);
      }
      return;
    }
    final defsResult = await repo.listDefinitions();
    if (!mounted || seq != _loadSeq) return;
    if (defsResult.isErr) {
      if (_layout == null) {
        setState(() {
          _loading = false;
          _failure = defsResult.failure;
        });
      }
      if (!silent || _layout == null) {
        showRdFailureToast(context, defsResult.failure!);
      }
      return;
    }
    final next = CustomFieldsManageSnapshot(
      layout: layoutResult.value!,
      definitions: {for (final def in defsResult.value!) def.id: def},
    );
    final cache = ref.read(customFieldsManageCacheProvider);
    final previous = cache.read();
    cache.write(next);
    if (!mounted || seq != _loadSeq) return;
    if (previous == next && _layout != null) {
      if (_loading || _failure != null) {
        setState(() {
          _loading = false;
          _failure = null;
        });
      }
      return;
    }
    setState(() {
      _layout = next.layout;
      _definitions = next.definitions;
      _loading = false;
      _failure = null;
    });
  }

  Future<void> _persistLayout(
    List<BookDetailFieldLayoutItem> next, {
    required List<BookDetailFieldLayoutItem> before,
  }) async {
    setState(() {
      _layout = next;
      _savingLayout = true;
    });
    ref
        .read(customFieldsManageCacheProvider)
        .write(
          CustomFieldsManageSnapshot(layout: next, definitions: _definitions),
        );
    final result = await ref.read(customFieldRepoProvider).saveLayout(next);
    if (!mounted) return;
    if (result.isErr) {
      setState(() {
        _layout = before;
        _savingLayout = false;
      });
      ref
          .read(customFieldsManageCacheProvider)
          .write(
            CustomFieldsManageSnapshot(
              layout: before,
              definitions: _definitions,
            ),
          );
      showRdFailureToast(context, result.failure!);
      return;
    }
    setState(() {
      _layout = result.value;
      _savingLayout = false;
    });
    ref
        .read(customFieldsManageCacheProvider)
        .write(
          CustomFieldsManageSnapshot(
            layout: result.value!,
            definitions: _definitions,
          ),
        );
  }

  Future<void> _edit([CustomFieldDefinition? item]) async {
    final messenger = ScaffoldMessenger.of(context);
    final creating = item == null;
    final saved = await showRdModalSheet<bool>(
      context: context,
      builder: (_) => _FieldEditor(definition: item),
    );
    if (saved != true || !mounted) return;
    // Drop warm cache so a stale silent refresh cannot paint pre-save rows
    // over the post-mutation reload.
    ref.read(customFieldsManageCacheProvider).clear();
    await _load();
    if (!mounted) return;
    if (creating) {
      _scrollListToTop();
    }
    showRdToast(
      context,
      tone: RdToastTone.success,
      message: AppL10n.of(context).customFieldsSaved,
      messenger: messenger,
    );
  }

  void _scrollListToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_listController.hasClients) return;
      _listController.animateTo(
        0,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _delete(CustomFieldDefinition item) async {
    final l = AppL10n.of(context);
    final confirmed = await showConfirmDialog(
      context: context,
      icon: LucideIcons.trash2,
      title: l.customFieldsDeleteTitle,
      message: l.customFieldsDeleteMessage,
      confirmLabel: l.actionDelete,
      confirmIcon: LucideIcons.trash2,
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    var result = await ref.read(customFieldRepoProvider).delete(item.id);
    if (result.failure?.code == 'custom_field_in_use' && mounted) {
      final cascade = await showConfirmDialog(
        context: context,
        icon: LucideIcons.trash2,
        title: l.customFieldsDeleteValuesTitle,
        message: l.customFieldsDeleteValuesMessage,
        confirmLabel: l.actionDelete,
        confirmIcon: LucideIcons.trash2,
        destructive: true,
      );
      if (cascade) {
        result = await ref
            .read(customFieldRepoProvider)
            .delete(item.id, cascade: true);
      } else {
        return;
      }
    }
    if (!mounted) return;
    if (result.isErr) {
      showRdFailureToast(context, result.failure!);
    } else {
      await _load();
      if (mounted) {
        showRdToast(
          context,
          tone: RdToastTone.success,
          message: l.customFieldsDeleted,
        );
      }
    }
  }

  Future<void> _reorder(int oldIndex, int newIndex) async {
    if (_savingLayout || _layout == null) return;
    final before = List<BookDetailFieldLayoutItem>.of(_layout!);
    final reordered = reorderCustomFieldItems(before, oldIndex, newIndex);
    await _persistLayout(reordered, before: before);
  }

  Future<void> _toggleHidden(BookDetailFieldLayoutItem item) async {
    if (_savingLayout ||
        _layout == null ||
        item.kind != BookDetailFieldKind.system) {
      return;
    }
    final before = List<BookDetailFieldLayoutItem>.of(_layout!);
    final next = [
      for (final row in before)
        row.key == item.key ? row.copyWith(hidden: !row.hidden) : row,
    ];
    await _persistLayout(next, before: before);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.customFieldsTitle),
        actions: RdCreateAction.appBarActions(
          context: context,
          onPressed: _savingLayout ? () {} : _edit,
          tooltip: l.customFieldsAdd,
        ),
      ),
      floatingActionButton: RdCreateAction.fab(
        context: context,
        onPressed: _savingLayout ? () {} : _edit,
        tooltip: l.customFieldsAdd,
      ),
      body: _loading
          ? RdProgress.centered()
          : _failure != null
          ? EmptyState(
              icon: LucideIcons.triangleAlert,
              message: localizedFailureMessage(l, _failure!),
              action: RdButton.secondary(
                onPressed: _load,
                icon: LucideIcons.refreshCw,
                label: l.actionRetry,
              ),
            )
          : (_layout?.isEmpty ?? true)
          ? EmptyState(
              illustration: const CustomFieldsEmptyArt(),
              message: l.customFieldsEmpty,
              action: RdButton.primary(
                onPressed: _edit,
                icon: LucideIcons.plus,
                label: l.customFieldsAdd,
              ),
            )
          : ReorderableListView.builder(
              scrollController: _listController,
              buildDefaultDragHandles: false,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
              itemCount: _layout!.length,
              onReorderItem: _reorder,
              // Items keep bottom gap for list spacing; the default Material
              // proxy would fill that full height. Rebuild the card alone so
              // floating feedback matches the row (gap stays empty/transparent
              // under OverflowBox top alignment).
              proxyDecorator: (child, index, animation) {
                return fieldLayoutDragProxy(
                  context: context,
                  animation: animation,
                  child: _layoutRow(_layout![index], index),
                );
              },
              itemBuilder: (_, index) {
                final item = _layout![index];
                return Padding(
                  key: ValueKey(item.key),
                  padding: EdgeInsets.only(
                    bottom: index == _layout!.length - 1
                        ? 0
                        : _kFieldLayoutRowGap,
                  ),
                  child: _layoutRow(item, index),
                );
              },
            ),
    );
  }

  Widget _layoutRow(BookDetailFieldLayoutItem item, int index) {
    return item.kind == BookDetailFieldKind.system
        ? _SystemFieldLayoutRow(
            item: item,
            dragIndex: index,
            saving: _savingLayout,
            onToggleHidden: () => _toggleHidden(item),
          )
        : _CustomFieldDefinitionRow(
            item: _definitions[item.key],
            fallbackKey: item.key,
            dragIndex: index,
            reordering: _savingLayout,
            onEdit: () {
              final def = _definitions[item.key];
              if (def != null) _edit(def);
            },
            onDelete: () {
              final def = _definitions[item.key];
              if (def != null) _delete(def);
            },
          );
  }
}

/// Elevates only the field card while dragging (no inter-row gap fill).
@visibleForTesting
Widget fieldLayoutDragProxy({
  required BuildContext context,
  required Animation<double> animation,
  required Widget child,
}) {
  final radius = usesCupertinoChrome(context)
      ? ReadendarTokens.radiusCard
      : ReadendarTokens.radiusSm;
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeInOut.transform(animation.value);
      return Material(
        elevation: lerpDouble(0, 6, t)!,
        color: Colors.transparent,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(radius),
        child: child,
      );
    },
    child: child,
  );
}

class _SystemFieldLayoutRow extends StatelessWidget {
  const _SystemFieldLayoutRow({
    required this.item,
    required this.dragIndex,
    required this.saving,
    required this.onToggleHidden,
  });

  final BookDetailFieldLayoutItem item;
  final int dragIndex;
  final bool saving;
  final VoidCallback onToggleHidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final chrome = bookDetailSystemFieldChrome(l, item.key);
    return Opacity(
      opacity: item.hidden ? 0.45 : 1,
      child: ReorderableDelayedDragStartListener(
        index: dragIndex,
        enabled: !saving,
        child: SettingsGroup(
          dividerIndent: 0,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 18,
                      color: c.fg3,
                    ),
                  ),
                  Icon(chrome.icon, size: 22, color: c.accentSoftFg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          chrome.label,
                          style: Theme.of(
                            context,
                          ).textTheme.titleSmall?.copyWith(color: c.fg1),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l.customFieldsStandard,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: c.fg2),
                        ),
                      ],
                    ),
                  ),
                  RdIconButton(
                    icon: item.hidden ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: item.hidden ? c.fg3 : c.accentSoftFg,
                    tooltip: item.hidden
                        ? l.customFieldsShowField
                        : l.customFieldsHideField,
                    onPressed: saving ? null : onToggleHidden,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Settings-style definition row: drag whole row, danger delete right.
class _CustomFieldDefinitionRow extends StatelessWidget {
  const _CustomFieldDefinitionRow({
    required this.item,
    required this.fallbackKey,
    required this.dragIndex,
    required this.reordering,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomFieldDefinition? item;
  final String fallbackKey;
  final int dragIndex;
  final bool reordering;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final l = AppL10n.of(context);
    final name = item?.name ?? fallbackKey;
    final typeLabel = item == null
        ? l.customFieldsTitle
        : _typeLabel(item!.type, l);
    return ReorderableDelayedDragStartListener(
      index: dragIndex,
      enabled: !reordering,
      child: SettingsGroup(
        dividerIndent: 0,
        children: [
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: reordering || item == null ? null : onEdit,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        LucideIcons.gripVertical,
                        size: 18,
                        color: c.fg3,
                      ),
                    ),
                    Icon(
                      customFieldIcon(item?.iconKey ?? 'tag'),
                      size: 22,
                      color: c.accentSoftFg,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(
                              context,
                            ).textTheme.titleSmall?.copyWith(color: c.fg1),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            typeLabel,
                            style: Theme.of(
                              context,
                            ).textTheme.bodySmall?.copyWith(color: c.fg2),
                          ),
                        ],
                      ),
                    ),
                    RdIconButton(
                      icon: LucideIcons.trash2,
                      color: c.danger,
                      tooltip: l.actionDelete,
                      onPressed: reordering || item == null ? null : onDelete,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldEditor extends ConsumerStatefulWidget {
  const _FieldEditor({this.definition});
  final CustomFieldDefinition? definition;
  @override
  ConsumerState<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends ConsumerState<_FieldEditor> {
  late final TextEditingController _name = TextEditingController(
    text: widget.definition?.name ?? '',
  );
  late CustomFieldType _type = widget.definition?.type ?? CustomFieldType.text;
  late String _icon = widget.definition?.iconKey ?? 'tag';
  late String _textMode =
      widget.definition?.type == CustomFieldType.text &&
          widget.definition?.textMode.isNotEmpty == true
      ? widget.definition!.textMode
      : 'single_line';
  late bool _showTime =
      widget.definition?.type != CustomFieldType.datetime ||
      customFieldShowsTime(widget.definition?.textMode ?? '');
  bool _saving = false;
  late final List<({String? id, TextEditingController controller})> _options = [
    for (final option
        in widget.definition?.options ?? const <CustomFieldOption>[])
      (id: option.id, controller: TextEditingController(text: option.label)),
  ];
  final Set<String> _confirmedCascadeOptionIds = {};

  late String? _creationKey;

  @override
  void initState() {
    super.initState();
    _creationKey = widget.definition == null ? const Uuid().v4() : null;
    _name.addListener(_onNameChanged);
  }

  void _onNameChanged() => setState(() {});

  @override
  void dispose() {
    _name.removeListener(_onNameChanged);
    _name.dispose();
    for (final option in _options) {
      option.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _saving) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    final repo = ref.read(customFieldRepoProvider);
    final type = _type == CustomFieldType.singleSelect
        ? 'single_select'
        : _type.name;
    final options = _type == CustomFieldType.singleSelect
        ? _options
              .where((option) => option.controller.text.trim().isNotEmpty)
              .map(
                (option) => <String, dynamic>{
                  if (option.id != null) 'id': option.id,
                  'label': option.controller.text.trim(),
                },
              )
              .toList()
        : null;
    final textMode = switch (_type) {
      CustomFieldType.text => _textMode,
      CustomFieldType.datetime => _showTime ? 'date_time' : 'date',
      _ => '',
    };
    final result = widget.definition == null
        ? await repo.create(
            idempotencyKey: _creationKey!,
            name: _name.text,
            iconKey: _icon,
            type: type,
            textMode: textMode,
            options: options,
          )
        : await repo.update(
            widget.definition!.id,
            name: _name.text,
            iconKey: _icon,
            type: type,
            textMode: textMode,
            options: options,
            cascadeOptionDeleteIds: _confirmedCascadeOptionIds.toList(),
          );
    if (!mounted) return;
    if (result.isErr) {
      // Cached 4xx idempotency payloads must not trap retries on the same key.
      if (widget.definition == null) {
        _creationKey = const Uuid().v4();
      }
      setState(() => _saving = false);
      showRdFailureToast(
        context,
        result.failure!,
        messenger: messenger,
      );
      return;
    }
    Navigator.pop(context, true);
  }

  Future<void> _removeOption(int index, AppL10n l) async {
    final removed = _options[index];
    CustomFieldOption? persisted;
    for (final option
        in widget.definition?.options ?? const <CustomFieldOption>[]) {
      if (option.id == removed.id) {
        persisted = option;
        break;
      }
    }
    final requiresCascade = (persisted?.usageCount ?? 0) > 0;
    if (requiresCascade) {
      final confirmed = await showConfirmDialog(
        context: context,
        icon: LucideIcons.trash2,
        title: l.customFieldsDeleteOptionTitle,
        message: l.customFieldsDeleteOptionMessage,
        confirmLabel: l.actionDelete,
        confirmIcon: LucideIcons.trash2,
        destructive: true,
      );
      if (!confirmed || !mounted) return;
    }
    setState(() {
      final value = _options.removeAt(index);
      if (value.id != null) {
        if (requiresCascade) _confirmedCascadeOptionIds.add(value.id!);
      }
      value.controller.dispose();
    });
  }

  void _addOption() {
    setState(
      () => _options.add((id: null, controller: TextEditingController())),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.85;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.definition == null
                    ? l.customFieldsAdd
                    : l.customFieldsEdit,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 20),
              RdTextField(
                controller: _name,
                decoration: InputDecoration(labelText: l.customFieldsName),
              ),
              const SizedBox(height: 12),
              RdDropdownField<CustomFieldType>(
                value: _type,
                label: l.customFieldsType,
                items: CustomFieldType.values
                    .map(
                      (value) => RdDropdownItem(
                        value: value,
                        label: _typeLabel(value, l),
                      ),
                    )
                    .toList(),
                onChanged: widget.definition == null
                    ? (v) => setState(() {
                        _type = v!;
                        if (_type == CustomFieldType.text) {
                          _textMode = 'single_line';
                        }
                        if (_type == CustomFieldType.datetime) {
                          _showTime = true;
                        }
                      })
                    : null,
              ),
              const SizedBox(height: 12),
              _IconPickerField(
                value: _icon,
                onChanged: (value) => setState(() => _icon = value),
              ),
              if (_type == CustomFieldType.text) ...[
                const SizedBox(height: 12),
                RdDropdownField<String>(
                  value: _textMode,
                  label: l.customFieldsTextMode,
                  items: [
                    RdDropdownItem(
                      value: 'single_line',
                      label: l.customFieldsSingleLine,
                    ),
                    RdDropdownItem(
                      value: 'multiline',
                      label: l.customFieldsMultiline,
                    ),
                  ],
                  onChanged: (value) => setState(() => _textMode = value!),
                ),
              ],
              if (_type == CustomFieldType.datetime) ...[
                const SizedBox(height: 12),
                SettingsGroup(
                  children: [
                    RdSwitchListTile(
                      value: _showTime,
                      onChanged: (value) => setState(() => _showTime = value),
                      title: Text(l.customFieldsShowTime),
                      subtitle: Text(l.customFieldsShowTimeHint),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                      ),
                    ),
                  ],
                ),
              ],
              if (_type == CustomFieldType.singleSelect) ...[
                const SizedBox(height: ReadendarTokens.sp6),
                SectionHeader(
                  l.customFieldsOptions,
                  padding: EdgeInsets.zero,
                ),
                const SizedBox(height: ReadendarTokens.sp4),
                for (var i = 0; i < _options.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: ReadendarTokens.sp4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RdTextField(
                            controller: _options[i].controller,
                            decoration: InputDecoration(
                              labelText: l.customFieldsOption,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: RdIconButton(
                            onPressed: () => _removeOption(i, l),
                            icon: LucideIcons.x,
                            color: context.colors.danger,
                            tooltip: l.actionDelete,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: ReadendarTokens.sp2),
                RdButton.secondary(
                  onPressed: _options.length >= 50 ? null : _addOption,
                  icon: LucideIcons.plus,
                  label: l.customFieldsAddOption,
                  expand: true,
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  RdButton.plain(
                    onPressed: _saving ? null : () => Navigator.pop(context),
                    label: l.actionCancel,
                  ),
                  const SizedBox(width: 12),
                  RdButton.primary(
                    onPressed: _saving || _name.text.trim().isEmpty
                        ? null
                        : _save,
                    icon: LucideIcons.save,
                    label: l.actionSave,
                    loading: _saving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconPickerField extends StatelessWidget {
  const _IconPickerField({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  Future<void> _open(BuildContext context) async {
    final selected = await showRdModalSheet<String>(
      context: context,
      builder: (sheetContext) {
        final l = AppL10n.of(sheetContext);
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.7;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.customFieldsIcon,
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: SingleChildScrollView(
                    child: _IconGallery(
                      value: value,
                      onChanged: (key) => Navigator.pop(sheetContext, key),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected != null) onChanged(selected);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return RdFormSelectField(
      key: const Key('customFieldIconSelector'),
      label: l.customFieldsIcon,
      valueText: value,
      leading: Icon(
        customFieldIcon(value),
        size: 18,
        color: context.colors.accentSoftFg,
      ),
      trailing: Icon(
        LucideIcons.chevronDown,
        size: 16,
        color: context.colors.fg3,
      ),
      onTap: () => _open(context),
    );
  }
}

class _IconGallery extends StatelessWidget {
  const _IconGallery({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final key in customFieldIconKeys)
          Material(
            color: value == key ? c.accentSoftBg : c.surface1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              side: BorderSide(
                color: value == key ? c.accent.withValues(alpha: 0.55) : c.line,
              ),
            ),
            child: InkWell(
              key: Key('customFieldIcon-$key'),
              onTap: () => onChanged(key),
              borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
              child: SizedBox.square(
                dimension: 44,
                child: Icon(
                  customFieldIcon(key),
                  size: 20,
                  color: value == key ? c.accentSoftFg : c.fg2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _typeLabel(CustomFieldType type, AppL10n l) => switch (type) {
  CustomFieldType.text => l.customFieldsTypeText,
  CustomFieldType.number => l.customFieldsTypeNumber,
  CustomFieldType.datetime => l.customFieldsTypeDateTime,
  CustomFieldType.boolean => l.customFieldsTypeBoolean,
  CustomFieldType.singleSelect => l.customFieldsTypeSingleSelect,
};

({IconData icon, String label}) bookDetailSystemFieldChrome(
  AppL10n l,
  String key,
) => switch (key) {
  'synopsis' => (icon: LucideIcons.alignLeft, label: l.metaSynopsis),
  'publisher' => (icon: LucideIcons.building2, label: l.metaPublisher),
  'publication_date' => (
    icon: LucideIcons.calendarDays,
    label: l.metaPublicationDate,
  ),
  'edition' => (icon: LucideIcons.bookCopy, label: l.metaEdition),
  'binding' => (icon: LucideIcons.bookOpen, label: l.metaBinding),
  'format' => (icon: LucideIcons.bookType, label: l.metaFormat),
  'language' => (icon: LucideIcons.globe2, label: l.metaLanguage),
  'isbn' => (icon: LucideIcons.barcode, label: 'ISBN'),
  'dimensions' => (icon: LucideIcons.ruler, label: l.metaDimensions),
  'msrp' => (icon: LucideIcons.badgeDollarSign, label: l.metaMsrp),
  'categories' => (icon: LucideIcons.tags, label: l.metaCategories),
  _ => (icon: LucideIcons.info, label: key),
};

/// Reorders for [ReorderableListView.onReorderItem] (index already adjusted).
@visibleForTesting
List<T> reorderCustomFieldItems<T>(List<T> items, int oldIndex, int newIndex) {
  final reordered = List<T>.of(items);
  reordered.insert(newIndex, reordered.removeAt(oldIndex));
  return reordered;
}
