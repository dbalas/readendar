// Shared, brand-styled crop step for every image upload (book cover, home
// banner). Centralizes the UCrop / iOS
// TOCropViewController theming so every crop screen looks like the app.

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';

import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/theme/tokens.dart';
import 'package:readendar/core/widgets/image_pick.dart' show pickImagePath;

/// Standard crop ratios per upload kind.
const cropBookCover = CropAspectRatio(ratioX: 2, ratioY: 3); // book cover
const cropBanner = CropAspectRatio(ratioX: 5, ratioY: 2); // home banner

/// Pick a photo (camera/gallery sheet) then crop it to [aspectRatio]. Returns
/// the cropped file path, or null if the user cancels at either step.
Future<String?> pickAndCropImage(
  BuildContext context, {
  required CropAspectRatio aspectRatio,
}) async {
  final l = AppL10n.of(context);
  final path = await pickImagePath(context);
  if (path == null) return null;
  return cropImagePath(path, aspectRatio: aspectRatio, l: l);
}

/// Crop an already-picked [sourcePath] to [aspectRatio] with the app's brand
/// crop UI. Exposed separately for callers that pick the file themselves.
Future<String?> cropImagePath(
  String sourcePath, {
  required CropAspectRatio aspectRatio,
  required AppL10n l,
}) async {
  final cropped = await ImageCropper().cropImage(
    sourcePath: sourcePath,
    aspectRatio: aspectRatio,
    uiSettings: [
      AndroidUiSettings(
        toolbarTitle: l.imageCropTitle,
        // Cohesive brand palette (mirrors Theme.Ucrop in styles.xml): periwinkle
        // toolbar/status bar with light icons, dark canvas, white crop frame.
        toolbarColor: ReadendarTokens.periwinkle600,
        statusBarLight: false,
        toolbarWidgetColor: ReadendarTokens.paper50,
        backgroundColor: ReadendarTokens.ink900,
        activeControlsWidgetColor: ReadendarTokens.periwinkle500,
        cropFrameColor: ReadendarTokens.paper50,
        cropGridColor: ReadendarTokens.paper50.withValues(alpha: 0.35),
        dimmedLayerColor: Colors.black.withValues(alpha: 0.6),
        lockAspectRatio: true,
        hideBottomControls: true,
      ),
      // TOCropViewController has no colour theming (its canvas is already dark);
      // consistency = localized buttons + a minimal, locked-ratio UI.
      IOSUiSettings(
        title: l.imageCropTitle,
        doneButtonTitle: l.actionSave,
        cancelButtonTitle: l.actionCancel,
        aspectRatioLockEnabled: true,
        aspectRatioPickerButtonHidden: true,
        resetAspectRatioEnabled: false,
        rotateButtonsHidden: true,
      ),
    ],
  );
  return cropped?.path;
}
