import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:readendar/core/analytics/analytics_service.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/error/failure_exception.dart';
import 'package:readendar/core/l10n/app_locales.dart';
import 'package:readendar/core/models/enums.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/models/reading_chapter.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/offline/offline_config.dart';
import 'package:readendar/core/storage/prefs_storage.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/theme/theme_catalog.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/core/utils/legal_urls.dart';
import 'package:readendar/data/api_repositories.dart';
import 'package:readendar/data/catalog/catalog_client.dart';
import 'package:readendar/data/local/import_service.dart';
import 'package:readendar/data/local/local_book_repository.dart';
import 'package:readendar/data/local/local_library_repos.dart';
import 'package:readendar/data/local/local_reading_chapter_repository.dart';
import 'package:readendar/data/local/local_stats.dart';
import 'package:readendar/data/local/local_store.dart';
import 'package:readendar/data/local/local_widget_summary.dart';
import 'package:readendar/data/repository_ports.dart';
import 'package:readendar/features/import/catalog_import.dart';
import 'package:readendar/features/notifications/local_notifications_service.dart';
import 'package:readendar/features/spotlight/spotlight_index.dart';
import 'package:readendar/features/widget/widget_bridge.dart';
import 'package:readendar/core/models/widget_models.dart';
import 'package:readendar/features/widget/widget_sync.dart';
import 'package:readendar/main.dart' show MainShell;
import 'package:shared_preferences/shared_preferences.dart';

// Riverpod composition. Split across parts so infra, repos, session, data,
// and quotes stay navigable; private helpers stay library-private.

part 'providers_infra.dart';
part 'providers_repos.dart';
part 'providers_session.dart';
part 'providers_data.dart';
part 'providers_quotes.dart';
