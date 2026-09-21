import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/app_colors.dart';
import 'package:readendar/core/theme/banner_presets.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/form_save_action.dart';
import 'package:readendar/core/widgets/image_crop.dart';
import 'package:readendar/core/widgets/rd_button.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/home/home_hero.dart';

/// Editor for the Home welcome-banner background (preset colour/gradient or a
/// local photo). Pushed from the palette icon on the banner.
class BannerEditorScreen extends ConsumerStatefulWidget {
  const BannerEditorScreen({super.key});

  @override
  ConsumerState<BannerEditorScreen> createState() => _BannerEditorScreenState();
}

class _BannerEditorScreenState extends ConsumerState<BannerEditorScreen> {
  late BannerStyle _style;
  String? _localImagePath; // staged crop, not yet uploaded
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _style =
        ref.read(sessionProvider).user?.homeBanner ??
        const BannerStyle.defaultStyle();
  }

  bool get _hasImage =>
      _localImagePath != null || _style.kind == BannerKind.image;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final name = ref.watch(
      sessionProvider.select((s) => s.user?.displayName ?? ''),
    );
    final apiBaseUrl = ref.watch(apiBaseUrlProvider);
    // Real library counts so the preview is byte-for-byte the live Home banner.
    final books = ref.watch(booksProvider).value ?? const <Book>[];
    int countOf(String status) => books.where((b) => b.status == status).length;
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(
        title: Text(l.bannerEditTitle),
        actions: [
          FormSaveAction(
            saving: _saving,
            onPressed: _save,
            tooltip: l.actionSave,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 32),
          children: [
            // The exact same component as Home, in read-only mode (inert
            // metrics, no edit button), reflecting the in-progress style.
            HomeHero(
              greeting: homeGreeting(l, name.isEmpty ? '·' : name, now),
              date: formatHomeDate(
                now,
                Localizations.localeOf(context).toString(),
              ),
              readingCount: countOf(BookStatus.reading),
              pendingCount: countOf(BookStatus.pending),
              wantedCount: countOf(BookStatus.wanted),
              loading: false,
              banner: _style,
              previewLocalImagePath: _localImagePath,
              mediaBaseUrl: apiBaseUrl,
              readOnly: true,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SectionLabel(l.bannerSectionColors),
                  const SizedBox(height: 12),
                  _PresetGrid(
                    selectedId: (!_hasImage && _style.kind == BannerKind.preset)
                        ? _style.preset
                        : (!_hasImage && _style.isDefault
                              ? 'periwinkle'
                              : null),
                    onPick: _saving
                        ? null
                        : (id) => setState(() {
                            _style = BannerStyle.preset(id);
                            _localImagePath = null;
                          }),
                  ),
                  const SizedBox(height: 24),
                  _SectionLabel(l.bannerSectionImage),
                  const SizedBox(height: 12),
                  _ImageSection(
                    hasImage: _hasImage,
                    onChoose: _saving ? null : _pickAndCrop,
                    onRemove: _saving
                        ? null
                        : () => setState(() {
                            _localImagePath = null;
                            if (_style.kind == BannerKind.image) {
                              _style = const BannerStyle.defaultStyle();
                            }
                          }),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: context.colors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  RdButton.plain(
                    onPressed:
                        (_saving ||
                            (_style.isDefault && _localImagePath == null))
                        ? null
                        : () => setState(() {
                            _style = const BannerStyle.defaultStyle();
                            _localImagePath = null;
                          }),
                    icon: LucideIcons.rotateCcw,
                    label: l.bannerReset,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndCrop() async {
    final path = await pickAndCropImage(context, aspectRatio: cropBanner);
    if (path == null || !mounted) return;
    setState(() => _localImagePath = path);
  }

  Future<void> _save() async {
    final l = AppL10n.of(context);
    final user = ref.read(sessionProvider).user;
    if (user == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final style = _localImagePath != null
          ? BannerStyle.image(_localImagePath!)
          : _style;
      await ref
          .read(sessionProvider.notifier)
          .persistLocalUser(
            user.copyWith(homeBanner: style),
          );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.errorGeneric;
      });
    }
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: context.colors.fg2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

/// Live preview of the banner with the in-progress style — mirrors _HomeHero's
/// look (white icon box + greeting), scrimmed when an image is set.
class _PresetGrid extends StatelessWidget {
  const _PresetGrid({required this.selectedId, required this.onPick});

  final String? selectedId;
  final void Function(String id)? onPick;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (var i = 0; i < bannerPresetOrder.length; i++)
          _Swatch(
            preset: bannerPresetOrDefault(bannerPresetOrder[i]),
            selected: bannerPresetOrder[i] == selectedId,
            label: l.bannerPresetA11y(i + 1),
            onTap: onPick == null ? null : () => onPick!(bannerPresetOrder[i]),
          ),
      ],
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.preset,
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final BannerPreset preset;
  final bool selected;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const size = 56.0;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: preset.color,
            gradient: preset.gradient,
            borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
            border: selected
                ? Border.all(color: context.colors.fg1, width: 3)
                : Border.all(color: context.colors.line),
          ),
          child: selected
              ? const Icon(
                  LucideIcons.check,
                  color: ReadendarTokens.paper50,
                  size: 22,
                )
              : null,
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  const _ImageSection({
    required this.hasImage,
    required this.onChoose,
    required this.onRemove,
  });

  final bool hasImage;
  final VoidCallback? onChoose;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Row(
      children: [
        Expanded(
          child: RdButton.secondary(
            onPressed: onChoose,
            icon: LucideIcons.image,
            label: l.bannerChoosePhoto,
          ),
        ),
        if (hasImage) ...[
          const SizedBox(width: 12),
          RdButton.plain(
            onPressed: onRemove,
            icon: LucideIcons.x,
            label: l.bannerRemovePhoto,
          ),
        ],
      ],
    );
  }
}
