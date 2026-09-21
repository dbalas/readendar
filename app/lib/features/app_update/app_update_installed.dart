import 'package:package_info_plus/package_info_plus.dart';

typedef InstalledVersionReader = Future<String> Function();

Future<String> readInstalledVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version.trim();
  } catch (_) {
    return '';
  }
}
