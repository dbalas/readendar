import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:readendar/core/theme/app_colors.dart';

/// Shared decode/fetch buckets so list, hub, chapter, and detail reuse the
/// same [ImageCache] entries instead of downloading Open Library `-L` originals
/// for a 32px chip and decoding them N times at unique widths.
enum CoverDisplayTier { thumb, card, hero, full }

CoverDisplayTier coverTierForWidth(double logicalWidth) {
  if (logicalWidth <= 64) return CoverDisplayTier.thumb;
  if (logicalWidth <= 120) return CoverDisplayTier.card;
  if (logicalWidth <= 200) return CoverDisplayTier.hero;
  return CoverDisplayTier.full;
}

/// Origin URL rewritten to a size that matches [tier]. Stored book URLs stay
/// canonical (`-L`); only the fetch is downsized.
String coverFetchUrl(String url, CoverDisplayTier tier) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.host.isEmpty) return url;
  final host = uri.host.toLowerCase();
  if (host == 'covers.openlibrary.org') {
    return _openLibraryFetchUrl(uri, tier);
  }
  return url;
}

int? coverMemCacheWidth(CoverDisplayTier tier, double devicePixelRatio) {
  final logical = switch (tier) {
    CoverDisplayTier.thumb => 56,
    CoverDisplayTier.card => 88,
    CoverDisplayTier.hero => 132,
    CoverDisplayTier.full => null,
  };
  if (logical == null) return null;
  final dpr = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 1.0;
  return (logical * dpr).round().clamp(1, 4096);
}

/// Remote cover URLs we are willing to fetch. Empty, whitespace, and non-http
/// values would otherwise produce a broken thumbnail instead of a placeholder.
bool isLocalCoverPath(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return false;
  return value.startsWith('/') || value.startsWith('file:');
}

bool isUsableCoverUrl(String? url) {
  final value = url?.trim() ?? '';
  if (value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.hasScheme ||
      (uri.scheme != 'http' && uri.scheme != 'https') ||
      uri.host.isEmpty) {
    return false;
  }
  final n = value.toLowerCase();
  if (n.contains('defecto') ||
      n.contains('cegal.') ||
      n.contains('/marcadas/') ||
      n.contains('no-image') ||
      n.contains('no_image') ||
      n.contains('nophoto') ||
      n.contains('no_cover') ||
      n.contains('no-cover') ||
      n.contains('nocover')) {
    return false;
  }
  final path = n.split('?').first;
  if (path.endsWith('.gif')) return false;
  return true;
}

/// Last-resort cover when a URL is missing or the decode fails and the caller
/// did not supply a title tile.
class CoverMissingPlaceholder extends StatelessWidget {
  const CoverMissingPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ColoredBox(
      color: c.surface2,
      child: Center(
        child: Icon(LucideIcons.bookMarked, color: c.fg3, size: 22),
      ),
    );
  }
}

ImageProvider coverImageProvider(
  String url, {
  required CoverDisplayTier tier,
  required double devicePixelRatio,
}) {
  if (isLocalCoverPath(url)) {
    final path = url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
    return FileImage(File(path));
  }
  final memWidth = coverMemCacheWidth(tier, devicePixelRatio);
  return CachedNetworkImageProvider(
    coverFetchUrl(url, tier),
    maxWidth: memWidth,
  );
}

void precacheCoverUrls(
  BuildContext context,
  Iterable<String> urls, {
  CoverDisplayTier tier = CoverDisplayTier.card,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  for (final url in urls) {
    if (!isUsableCoverUrl(url) && !isLocalCoverPath(url)) continue;
    unawaited(
      precacheImage(
        coverImageProvider(url, tier: tier, devicePixelRatio: dpr),
        context,
      ).catchError((Object _) {}),
    );
  }
}

/// Cached remote cover with a visible placeholder on missing or failed URLs.
/// Fetch URL and mem-cache width stay one-per-tier so list and detail share
/// [ImageCache] entries.
class RemoteCoverImage extends StatelessWidget {
  const RemoteCoverImage({
    required this.url,
    super.key,
    this.tier = CoverDisplayTier.card,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.error,
  });

  final String url;
  final CoverDisplayTier tier;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? error;

  @override
  Widget build(BuildContext context) {
    final fallback = error ?? placeholder ?? const CoverMissingPlaceholder();
    if (isLocalCoverPath(url)) {
      final path = url.startsWith('file:') ? Uri.parse(url).toFilePath() : url;
      return Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    if (!isUsableCoverUrl(url)) return fallback;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return CachedNetworkImage(
      imageUrl: coverFetchUrl(url, tier),
      memCacheWidth: coverMemCacheWidth(tier, dpr),
      fit: fit,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      filterQuality: tier == CoverDisplayTier.thumb
          ? FilterQuality.low
          : FilterQuality.medium,
      placeholder: (_, _) => placeholder ?? fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}

String _openLibraryFetchUrl(Uri uri, CoverDisplayTier tier) {
  final size = switch (tier) {
    CoverDisplayTier.thumb || CoverDisplayTier.card => 'M',
    CoverDisplayTier.hero || CoverDisplayTier.full => 'L',
  };
  final path = uri.path.replaceFirst(
    RegExp(r'-[sml](\.jpe?g)$', caseSensitive: false),
    '-$size.jpg',
  );
  if (path == uri.path) return uri.toString();
  return uri.replace(path: path).toString();
}
