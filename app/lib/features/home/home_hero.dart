import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/banner_surface.dart';
import 'package:readendar/core/widgets/rd_icon_button.dart';
import 'package:readendar/core/widgets/section_header.dart';

/// Time-of-day greeting used by the Home banner (and its editor preview).
String homeGreeting(AppL10n l, String name, DateTime now) => now.hour < 12
    ? l.greetingMorning(name)
    : now.hour < 19
    ? l.greetingAfternoon(name)
    : l.greetingEvening(name);

/// Locale-aware "June 15" / "15 de junio" header date (MMMMd orders day/month
/// per locale instead of forcing a day-first pattern).
String formatHomeDate(DateTime d, String locale) =>
    DateFormat.MMMMd(locale).format(d);

/// The Home welcome banner: icon box + greeting + date + the three status
/// metrics, painted with the user's chosen [banner] style.
///
/// The SAME widget renders the live banner on Home and the live preview in the
/// banner editor. Pass [readOnly] for the preview: the metric chips become inert
/// and the palette edit button is hidden, but every visual element is identical
/// to the real thing. [previewLocalImagePath] shows a not-yet-uploaded crop.
class HomeHero extends StatelessWidget {
  const HomeHero({
    required this.greeting,
    required this.date,
    required this.readingCount,
    required this.pendingCount,
    required this.wantedCount,
    required this.loading,
    required this.banner,
    super.key,
    this.onStatusTap,
    this.onEdit,
    this.previewLocalImagePath,
    this.mediaBaseUrl,
    this.readOnly = false,
  });

  final String greeting;
  final String date;
  final int readingCount;
  final int pendingCount;
  final int wantedCount;
  final bool loading;
  final BannerStyle banner;

  /// Tap handler for a status metric. Ignored when [readOnly].
  final void Function(String status)? onStatusTap;

  /// Opens the banner editor. Hidden when [readOnly] or null.
  final VoidCallback? onEdit;

  /// A staged (not-yet-uploaded) image to preview instead of [banner]'s URL.
  final String? previewLocalImagePath;

  /// API origin used to reach local MinIO from an emulator or device.
  final String? mediaBaseUrl;

  /// Preview mode: metrics inert, no edit button. Visually identical otherwise.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: BannerSurface(
        style: banner,
        localImagePath: previewLocalImagePath,
        apiBaseUrl: mediaBaseUrl,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BannerIconBox(
                  glyphColor: bannerSurfaceGlyph(
                    banner,
                    localImagePath: previewLocalImagePath,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      EditorialTitle(
                        greeting,
                        key: const Key('homeEditorialTitle'),
                        color: ReadendarTokens.paper50,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        date,
                        style: TextStyle(
                          color: ReadendarTokens.paper50.withValues(
                            alpha: 0.78,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!readOnly && onEdit != null)
                  _BannerEditButton(tooltip: l.bannerCustomize, onTap: onEdit!),
              ],
            ),
            const SizedBox(height: 18),
            if (loading)
              const LinearProgressIndicator(color: ReadendarTokens.paper50),
            if (!loading)
              Row(
                children: [
                  Expanded(
                    child: _HeroMetric(
                      value: readingCount,
                      label: l.statusReading,
                      onTap: readOnly
                          ? null
                          : () => onStatusTap?.call(BookStatus.reading),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroMetric(
                      value: pendingCount,
                      label: l.homeMetricPending,
                      onTap: readOnly
                          ? null
                          : () => onStatusTap?.call(BookStatus.pending),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _HeroMetric(
                      value: wantedCount,
                      label: l.homeMetricWanted,
                      onTap: readOnly
                          ? null
                          : () => onStatusTap?.call(BookStatus.wanted),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Always-visible palette button in the banner's top-right corner that opens
/// the banner customization editor.
class _BannerEditButton extends StatelessWidget {
  const _BannerEditButton({required this.tooltip, required this.onTap});

  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: tooltip,
      child: RdIconButton.compact(
        onPressed: onTap,
        tooltip: tooltip,
        size: 20,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        icon: LucideIcons.palette,
        color: ReadendarTokens.paper50.withValues(alpha: 0.85),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.value,
    required this.label,
    required this.onTap,
  });
  final int value;
  final String label;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: ReadendarTokens.paper50.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(ReadendarTokens.radiusSm),
          border: Border.all(
            color: ReadendarTokens.paper50.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: const TextStyle(
                color: ReadendarTokens.paper50,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                // Fill-independent (matches the date): the banner can now be any
                // saturated colour/gradient/image, so a periwinkle-tinted label
                // would read as off-brand on non-periwinkle banners.
                color: ReadendarTokens.paper50.withValues(alpha: 0.82),
                fontSize: 11,
                height: 1.05,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
