import 'dart:io';

/// Pixel goldens are recorded on Linux CI. Other hosts rasterize fonts
/// differently, so those comparisons run only there.
bool get runLinuxGoldens => Platform.isLinux;
