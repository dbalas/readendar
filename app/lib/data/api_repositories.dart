// Sunset cloud client. Until 15 October 2026 this talks to the hosted API
// only for leftover JWT auth and GET /v1/me/export. Product data is local.

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'package:readendar/core/error/exception_mapper.dart';
import 'package:readendar/core/error/failure.dart';
import 'package:readendar/core/models/models.dart';
import 'package:readendar/core/network/api_client.dart';
import 'package:readendar/core/network/result.dart';
import 'package:readendar/core/storage/secure_storage.dart';
import 'package:readendar/core/utils/isbn.dart';
import 'package:readendar/data/catalog/catalog_client.dart';
import 'package:readendar/data/catalog/catalog_language.dart';
import 'package:readendar/data/repository_ports.dart';

export 'package:readendar/data/repository_ports.dart';

Future<Result<T>> _safe<T>(Future<T> Function() body) async {
  try {
    return Ok(await body());
  } on DioException catch (e) {
    return Err(mapDioException(e));
  } catch (e) {
    return Err(UnknownFailure(e.toString()));
  }
}

class ApiAuthRepository implements AuthRepository {
  ApiAuthRepository(this._api, this._storage);
  final ApiClient _api;
  final SecureTokenStorage _storage;

  @override
  Future<Result<MagicLinkRequestResult>> requestMagicLink({
    required String email,
    required String locale,
  }) async {
    return _safe(() async {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/v1/auth/magic-link/request',
        data: {'email': email, 'locale': locale},
      );
      return MagicLinkRequestResult.fromJson(r.data ?? const {});
    });
  }

  @override
  Future<Result<AuthSession>> verifyMagicLink({
    required String token,
    required String locale,
  }) async {
    return _safe(() async {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/v1/auth/magic-link/verify',
        data: {'token': token, 'locale': locale},
      );
      final session = AuthSession.fromJson(r.data!);
      await _storage.saveTokens(
        access: session.accessToken,
        refresh: session.refreshToken,
      );
      return session;
    });
  }

  @override
  Future<Result<AuthSession>> signInGoogle({
    required String idToken,
    required String locale,
  }) async {
    return _safe(() async {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/v1/auth/oauth/google',
        data: {'idToken': idToken, 'locale': locale},
      );
      final session = AuthSession.fromJson(r.data!);
      await _storage.saveTokens(
        access: session.accessToken,
        refresh: session.refreshToken,
      );
      return session;
    });
  }

  @override
  Future<Result<AuthSession>> signInApple({
    required String idToken,
    required String locale,
    String? name,
  }) async {
    return _safe(() async {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/v1/auth/oauth/apple',
        data: {
          'idToken': idToken,
          'locale': locale,
          if (name != null && name.isNotEmpty) 'name': name,
        },
      );
      final session = AuthSession.fromJson(r.data!);
      await _storage.saveTokens(
        access: session.accessToken,
        refresh: session.refreshToken,
      );
      return session;
    });
  }

  @override
  Future<Result<void>> logout() async {
    return _safe(() async {
      final refresh = await _storage.getRefresh();
      await _storage.clear();
      if (refresh == null) return;
      unawaited(_revokeServerSession(refresh));
    });
  }

  Future<void> _revokeServerSession(String refresh) async {
    try {
      await _api.dio.post<dynamic>(
        '/v1/auth/logout',
        data: {'refreshToken': refresh},
      );
    } on Object {
      // Best-effort: the refresh family may already be invalid.
    }
  }
}

/// Cloud identity probe + GDPR export. Profile edits and stats are local.
class ApiUserRepository implements UserRepository {
  ApiUserRepository(this._api);
  final ApiClient _api;

  @override
  Future<Result<AppUser>> getMe() => _safe(() async {
    final r = await _api.dio.get<Map<String, dynamic>>('/v1/me');
    return AppUser.fromJson(r.data!);
  });

  @override
  Future<Result<AppUser>> updateMe({
    String? displayName,
    String? preferredLocale,
    String? timezone,
    bool completeOnboarding = false,
    String? acceptedTermsVersion,
    bool? analyticsEnabled,
    String? analyticsNoticeVersion,
    bool? autoCreateStatusEvents,
    bool? alwaysShowSpoilerQuotes,
    BannerStyle? homeBanner,
  }) async {
    return const Err(UnknownFailure('local_profile'));
  }

  @override
  Future<Result<UserStats>> myStats({
    PageActivityQuery query = const PageActivityQuery(),
  }) async {
    return const Err(UnknownFailure('local_stats'));
  }

  @override
  Future<Result<String>> exportData() => _safe(() async {
    final r = await _api.dio.get<Map<String, dynamic>>(
      '/v1/me/export',
      options: Options(
        receiveTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 2),
      ),
    );
    final data = r.data;
    if (data == null) {
      throw const FormatException('empty export payload');
    }
    return jsonEncode(data);
  });
}

/// Public catalog search. No Readendar API.
class CatalogSearchRepository implements SearchRepository {
  CatalogSearchRepository({CatalogClient? catalog})
    : _catalog = catalog ?? CatalogClient();
  final CatalogClient _catalog;

  @override
  Future<Result<SearchPage>> search(
    String query, {
    String? column,
    int page = 1,
    int limit = 20,
    bool allLanguages = false,
  }) => _safe(() async {
    return localCatalogSearchPage(
      fetch: (offset) => _catalog.search(query, offset: offset),
      page: page,
      limit: limit,
      allLanguages: allLanguages,
      isbnQuery: looksLikeIsbnQuery(query),
    );
  });

  @override
  Future<Result<SearchHit?>> lookupByIsbn(String isbn) => _safe(() async {
    return _catalog.lookupIsbn(isbn);
  });

  @override
  Future<Result<SearchHit?>> enrich({
    String isbn = '',
    String title = '',
    List<String> authors = const [],
    String coverUrl = '',
    List<String> categories = const [],
    List<String> categoryCodes = const [],
  }) => _safe(
    () => _catalog.enrich(
      isbn: isbn,
      title: title,
      authors: authors,
      coverUrl: coverUrl,
      categories: categories,
      categoryCodes: categoryCodes,
    ),
  );
}

/// Temporary alias while tests migrate.
typedef ApiSearchRepository = CatalogSearchRepository;

/// Debug-only leftover JWT mint for cloud-import QA until 15 October 2026.
class DebugRepository {
  DebugRepository(
    this._api, {
    this.cloudImportEmail = defaultCloudImportEmail,
  });

  static const defaultCloudImportEmail = String.fromEnvironment(
    'DEBUG_CLOUD_IMPORT_EMAIL',
    defaultValue: 'qa@example.com',
  );

  final ApiClient _api;
  final String cloudImportEmail;

  Future<Result<AuthSession>> issueCloudImportSession() => _safe(() async {
    try {
      final r = await _api.dio.post<Map<String, dynamic>>(
        '/v1/debug/import-session',
      );
      return AuthSession.fromJson(r.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode != 404) rethrow;
    }
    return _sessionViaDevMagicLink();
  });

  Future<AuthSession> _sessionViaDevMagicLink() async {
    final requested = await _api.dio.post<Map<String, dynamic>>(
      '/v1/auth/magic-link/request',
      data: {'email': cloudImportEmail, 'locale': 'es'},
    );
    final code = requested.data?['devCode'] as String?;
    if (code == null || code.isEmpty) {
      throw DioException(
        requestOptions: requested.requestOptions,
        response: requested,
        type: DioExceptionType.badResponse,
        message: 'devCode missing',
      );
    }
    final verified = await _api.dio.post<Map<String, dynamic>>(
      '/v1/auth/magic-link/verify',
      data: {
        'token': code,
        'locale': 'es',
        'expectedEmail': cloudImportEmail,
      },
    );
    return AuthSession.fromJson(verified.data!);
  }
}
