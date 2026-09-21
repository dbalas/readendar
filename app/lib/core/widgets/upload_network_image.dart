import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:readendar/core/network/media_urls.dart';
import 'package:readendar/core/theme/app_colors.dart';

/// Cached remote upload with loopback rewrite and a placeholder instead of
/// Flutter's default broken-image red X.
class UploadNetworkImage extends StatelessWidget {
  const UploadNetworkImage({
    required this.url,
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.placeholder,
    this.error,
    this.apiBaseUrl,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final Widget? placeholder;
  final Widget? error;
  final String? apiBaseUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = resolveUploadAssetUrl(url, apiBaseUrl: apiBaseUrl);
    final fallback =
        error ??
        placeholder ??
        ColoredBox(
          color: context.colors.surface2,
          child: Center(
            child: Icon(LucideIcons.imageOff, color: context.colors.fg3),
          ),
        );
    if (!isUsableUploadUrl(resolved)) return fallback;
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      placeholder: (_, _) => placeholder ?? fallback,
      errorWidget: (_, _, _) => fallback,
    );
  }
}
