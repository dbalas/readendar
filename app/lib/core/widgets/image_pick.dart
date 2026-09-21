// Small helper to pick an image for book covers.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/widgets/confirm_dialog.dart';
import 'package:readendar/core/widgets/rd_menu.dart';

typedef RequestCameraPermission = Future<PermissionStatus> Function();
typedef OpenDeviceSettings = Future<bool> Function();
typedef PickImageFn =
    Future<XFile?> Function({
      required ImageSource source,
      double? maxWidth,
      int? imageQuality,
    });

bool _cameraAllowed(PermissionStatus status) =>
    status.isGranted || status.isLimited;

/// Camera is off in Settings (or restricted). The OS will not show a prompt
/// again, so skip another runtime request, which can hang or throw.
bool _cameraBlockedInSettings(PermissionStatus status) =>
    status.isPermanentlyDenied || status.isRestricted;

bool _isCameraAccessDenied(Object error) {
  if (error is! PlatformException) return false;
  return error.code == 'camera_access_denied' ||
      error.code == 'camera_access_restricted' ||
      error.code == 'no_available_camera';
}

/// Explains that camera access is required and offers a path to Settings.
/// Used after the OS permission has already been denied or restricted.
Future<void> showCameraPermissionDeniedDialog(
  BuildContext context, {
  OpenDeviceSettings? openSettings,
}) async {
  final l = AppL10n.of(context);
  final open = await showConfirmDialog(
    context: context,
    icon: LucideIcons.cameraOff,
    title: l.scanPermissionTitle,
    message: l.cameraPermissionBody,
    confirmLabel: l.scanPermissionOpenSettings,
    confirmIcon: LucideIcons.settings,
  );
  if (open) {
    await (openSettings ?? openAppSettings)();
  }
}

Future<void> showPhotosPermissionDeniedDialog(
  BuildContext context, {
  OpenDeviceSettings? openSettings,
}) async {
  final l = AppL10n.of(context);
  final open = await showConfirmDialog(
    context: context,
    icon: LucideIcons.imageOff,
    title: l.photosPermissionTitle,
    message: l.photosPermissionBody,
    confirmLabel: l.scanPermissionOpenSettings,
    confirmIcon: LucideIcons.settings,
  );
  if (open) {
    await (openSettings ?? openAppSettings)();
  }
}

Future<PermissionStatus> _queryCameraPermission() async {
  final current = await Permission.camera.status;
  if (_cameraAllowed(current) || _cameraBlockedInSettings(current)) {
    return current;
  }
  return Permission.camera.request();
}

Future<bool> _ensureCameraAccess(
  BuildContext context, {
  RequestCameraPermission? requestCameraPermission,
  OpenDeviceSettings? openSettings,
}) async {
  try {
    final status = await (requestCameraPermission ?? _queryCameraPermission)();
    if (_cameraAllowed(status)) return true;
  } catch (_) {
    // Plugin missing, Activity gone after the source sheet, or an already
    // running request. Still explain how to enable camera in Settings.
  }
  if (!context.mounted) return false;
  await showCameraPermissionDeniedDialog(
    context,
    openSettings: openSettings,
  );
  return false;
}

/// Picks a camera or gallery file. Pass [imageQuality] null to skip native
/// recompress (photo search reuses the picker file and encodes later).
Future<String?> pickImagePath(
  BuildContext context, {
  double? maxWidth = 2048,
  int? imageQuality = 85,
  ImageSource? source,
  @visibleForTesting RequestCameraPermission? requestCameraPermission,
  @visibleForTesting OpenDeviceSettings? openSettings,
  @visibleForTesting PickImageFn? pickImage,
}) async {
  final l = AppL10n.of(context);
  final pickedSource =
      source ??
      await showRdMenu<ImageSource>(
        context: context,
        items: [
          RdMenuItem(
            value: ImageSource.camera,
            label: l.sourceCamera,
            icon: LucideIcons.camera,
          ),
          RdMenuItem(
            value: ImageSource.gallery,
            label: l.sourceGallery,
            icon: LucideIcons.image,
          ),
        ],
      );
  if (pickedSource == null) return null;
  if (pickedSource == ImageSource.camera) {
    // Presenting the OS prompt or our settings dialog in the same frame as
    // the source sheet pop often fails silently (Activity null / overlay).
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return null;
    final allowed = await _ensureCameraAccess(
      context,
      requestCameraPermission: requestCameraPermission,
      openSettings: openSettings,
    );
    if (!allowed) return null;
  }
  if (pickedSource == ImageSource.gallery) {
    // Android Photo Picker and iOS PHPicker are the grant UI. Do not call
    // Permission.photos first: that permission is stripped from Android and
    // not compiled on iOS, so the request fails and our settings modal
    // replaces the native picker. Settings modal only after the picker
    // reports access denied.
    await WidgetsBinding.instance.endOfFrame;
    if (!context.mounted) return null;
  }
  if (!context.mounted) return null;
  final pick =
      pickImage ??
      ({
        required ImageSource source,
        double? maxWidth,
        int? imageQuality,
      }) => ImagePicker().pickImage(
        source: source,
        maxWidth: maxWidth,
        imageQuality: imageQuality,
      );
  try {
    final picked = await pick(
      source: pickedSource,
      maxWidth: maxWidth,
      imageQuality: imageQuality,
    );
    return picked?.path;
  } on PlatformException catch (error) {
    if (pickedSource == ImageSource.camera && _isCameraAccessDenied(error)) {
      if (context.mounted) {
        await showCameraPermissionDeniedDialog(
          context,
          openSettings: openSettings,
        );
      }
      return null;
    }
    if (pickedSource == ImageSource.gallery &&
        (error.code == 'photo_access_denied' ||
            error.code == 'photo_access_restricted')) {
      if (context.mounted) {
        await showPhotosPermissionDeniedDialog(
          context,
          openSettings: openSettings,
        );
      }
      return null;
    }
    rethrow;
  }
}
