import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/l10n/gen/app_localizations.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/widgets/rd_page_route.dart';
import 'package:readendar/core/widgets/toast.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/di/providers.dart';
import 'package:readendar/features/auth/login_screen.dart';

enum CloudImportTokenStatus { valid, missing, unauthorized, unreachable }

/// TEMP: leftover cloud JWT for GET /v1/me/export. Missing or rejected
/// sessions open the restored login screen instead of failing the download.
Future<CloudImportTokenStatus> probeCloudImportToken({
  required SecureTokenStorage storage,
  required UserRepository users,
}) async {
  final access = await storage.getAccess();
  final refresh = await storage.getRefresh();
  final hasAccess = access != null && access.isNotEmpty;
  final hasRefresh = refresh != null && refresh.isNotEmpty;
  if (!hasAccess && !hasRefresh) {
    return CloudImportTokenStatus.missing;
  }
  final me = await users.getMe();
  if (me.isOk) return CloudImportTokenStatus.valid;
  if (me.failure is UnauthorizedFailure) {
    return CloudImportTokenStatus.unauthorized;
  }
  return CloudImportTokenStatus.unreachable;
}

/// Claims the shared cloud-import lock. Callers must [endCloudImport].
bool tryBeginCloudImport(WidgetRef ref) {
  if (ref.read(cloudImportInFlightProvider)) return false;
  ref.read(cloudImportInFlightProvider.notifier).state = true;
  return true;
}

void endCloudImport(WidgetRef ref) {
  ref.read(cloudImportInFlightProvider.notifier).state = false;
}

/// Returns true when a usable import JWT is in storage (or after login).
Future<bool> ensureCloudImportAuth({
  required BuildContext context,
  required WidgetRef ref,
}) async {
  final status = await probeCloudImportToken(
    storage: ref.read(secureStorageProvider),
    users: ref.read(userRepoProvider),
  );
  switch (status) {
    case CloudImportTokenStatus.valid:
      return true;
    case CloudImportTokenStatus.unreachable:
      if (context.mounted) {
        showRdToast(
          context,
          message: AppL10n.of(context).errorNetwork,
          tone: RdToastTone.error,
        );
      }
      return false;
    case CloudImportTokenStatus.missing:
      break;
    case CloudImportTokenStatus.unauthorized:
      await ref.read(secureStorageProvider).clear();
  }
  if (!context.mounted) return false;
  final loggedIn = await Navigator.of(context, rootNavigator: true).push<bool>(
    rdPageRoute<bool>(
      context,
      builder: (_) => const LoginScreen(),
      fullscreenDialog: true,
    ),
  );
  return loggedIn == true;
}
