import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/cover_badge.dart';
import 'package:readendar/core/widgets/cover_image.dart';

/// Full-screen pinch-to-zoom preview for a book cover (detail header, etc.).
Future<void> showBookCoverPreview(
  BuildContext context, {
  required String title,
  String? author,
  String? coverUrl,
  String? localImagePath,
  Color? color,
}) {
  final localPath = localImagePath;
  final remoteUrl = coverUrl;
  final hasImage =
      (localPath != null && localPath.isNotEmpty) ||
      (remoteUrl != null && remoteUrl.isNotEmpty);

  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Dialog.fullscreen(
      backgroundColor: Colors.transparent,
      child: Stack(
        children: [
          Positioned.fill(
            child: InteractiveViewer(
              maxScale: 5,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(ReadendarTokens.sp6),
                  child: hasImage
                      ? _CoverPreviewImage(
                          title: title,
                          author: author,
                          coverUrl: remoteUrl,
                          localImagePath: localPath,
                          color: color,
                        )
                      : BookCover(
                          title: title,
                          author: author,
                          color: color,
                          size: BookCoverSize.lg,
                          width: 220,
                        ),
                ),
              ),
            ),
          ),
          Positioned(
            top: ReadendarTokens.sp4,
            right: ReadendarTokens.sp4,
            child: SafeArea(
              child: IconButton.filled(
                onPressed: () => Navigator.pop(dialogContext),
                icon: const Icon(LucideIcons.x),
                tooltip: MaterialLocalizations.of(
                  dialogContext,
                ).closeButtonTooltip,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _CoverPreviewImage extends StatelessWidget {
  const _CoverPreviewImage({
    required this.title,
    this.author,
    this.coverUrl,
    this.localImagePath,
    this.color,
  });

  final String title;
  final String? author;
  final String? coverUrl;
  final String? localImagePath;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fallback = BookCover(
      title: title,
      author: author,
      color: color,
      size: BookCoverSize.lg,
      width: 220,
    );
    final localPath = localImagePath;
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    final url = coverUrl;
    if (isLocalCoverPath(url) || isUsableCoverUrl(url)) {
      return RemoteCoverImage(
        url: url!.trim(),
        tier: CoverDisplayTier.full,
        fit: BoxFit.contain,
        placeholder: fallback,
        error: fallback,
      );
    }
    return fallback;
  }
}

enum BookCoverSize { xs, sm, md, lg }

class BookCover extends StatelessWidget {
  const BookCover({
    required this.title,
    super.key,
    this.author,
    this.coverUrl,
    this.localImagePath,
    this.color,
    this.size = BookCoverSize.md,
    this.width,
    this.rating,
    this.hasNotes = false,
  });

  final String title;
  final String? author;
  final String? coverUrl;

  /// Staged local crop (not yet uploaded). Wins over [coverUrl] for preview so
  /// create/edit forms can show a custom cover without touching object storage
  /// until Save — avoids orphan blobs if the user cancels.
  final String? localImagePath;
  final Color? color;
  final BookCoverSize size;

  /// Optional override of the [size]-derived width (height follows the 2:3
  /// ratio). Radius, badge scale and decode width all track this value, so the
  /// cover stays crisp and proportionate when nudged off a preset size.
  final double? width;

  /// When non-null, overlays a private-rating badge ("★ N") on the top-right
  /// corner. Only pass for the user's own copies.
  final double? rating;

  /// When true, overlays a private-notes indicator just below the rating badge,
  /// also right-aligned. Only pass for the user's own copies.
  final bool hasNotes;

  double get _width =>
      width ??
      switch (size) {
        BookCoverSize.xs => 32,
        BookCoverSize.sm => 56,
        BookCoverSize.md => 88,
        BookCoverSize.lg => 132,
      };

  @override
  Widget build(BuildContext context) {
    final w = _width;
    final h = w * 1.5;
    final tier = coverTierForWidth(size == BookCoverSize.xs ? 56 : w);
    final radius = BorderRadius.circular(switch (size) {
      BookCoverSize.xs => 3.0,
      BookCoverSize.sm => 4.0,
      BookCoverSize.md => 6.0,
      BookCoverSize.lg => 8.0,
    });

    final badgeInset = (rating != null || hasNotes)
        ? (w * 0.32).clamp(13.0, 22.0) * 0.55
        : 0.0;

    final fallback = _Fallback(
      title: title,
      author: author,
      color: color,
      size: size,
      badgeInset: badgeInset,
    );

    final localPath = localImagePath;
    final Widget coverChild;
    if (localPath != null && localPath.isNotEmpty) {
      coverChild = Image.file(
        File(localPath),
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    } else if (isLocalCoverPath(coverUrl) || isUsableCoverUrl(coverUrl)) {
      coverChild = RemoteCoverImage(
        url: coverUrl!.trim(),
        tier: tier,
        placeholder: fallback,
        error: fallback,
      );
    } else {
      coverChild = fallback;
    }

    final image = ClipRRect(
      borderRadius: radius,
      child: SizedBox(width: w, height: h, child: coverChild),
    );

    if (rating == null && !hasNotes) return image;

    // Badge size scales with the cover so the same overlay works from the
    // small library row to a full-size cover. Badges slightly overhang the
    // border (Clip.none) like the rest of the cover-badge family. Rating sits
    // on top, the private-notes indicator stacks directly beneath it — both
    // right-aligned so they read as one corner group.
    final d = (w * 0.32).clamp(13.0, 22.0);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        image,
        Positioned(
          top: -d * 0.18,
          right: -d * 0.2,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (rating != null) RatingBadge(rating: rating!, height: d),
              if (hasNotes) ...[
                if (rating != null) SizedBox(height: d * 0.22),
                CoverBadge(
                  background: ReadendarTokens.periwinkle500,
                  icon: LucideIcons.stickyNote,
                  size: d,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({
    required this.title,
    required this.size,
    this.author,
    this.color,
    this.badgeInset = 0,
  });
  final String title;
  final String? author;
  final Color? color;
  final BookCoverSize size;
  final double badgeInset;

  @override
  Widget build(BuildContext context) {
    final c = color ?? ReadendarTokens.teal500;
    final isSmall = size == BookCoverSize.xs || size == BookCoverSize.sm;
    final basePad = isSmall ? 4.0 : 8.0;
    return Container(
      color: c,
      padding: EdgeInsets.fromLTRB(
        basePad,
        basePad + badgeInset,
        basePad + badgeInset,
        basePad,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final fontSize = isSmall ? 8.0 : 12.0;
                final lineHeight = fontSize * 1.15;
                final lines = (constraints.maxHeight / lineHeight)
                    .floor()
                    .clamp(1, isSmall ? 3 : 8);
                return Text(
                  title,
                  maxLines: lines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                  style: TextStyle(
                    fontFamily: ReadendarTokens.fontDisplay,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    fontSize: fontSize,
                    height: 1.15,
                  ),
                );
              },
            ),
          ),
          if (author != null && !isSmall) ...[
            const SizedBox(height: 4),
            Text(
              author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 9),
            ),
          ],
        ],
      ),
    );
  }
}
