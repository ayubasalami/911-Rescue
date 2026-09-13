import 'dart:async';

import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_failure.dart';
import '../../core/config/app_config.dart';
import '../../core/result.dart';
import 'cookie_jar_provider.dart';
import 'json_reader.dart';
import 'retry_interceptor.dart';

/// Parses a response body into a `T`. Takes the whole decoded body rather
/// than unwrapping a `data` field — unlike a typical REST envelope, this
/// API mostly returns the payload directly (a ping's `{incident,
/// responder}`, a GeoJSON `FeatureCollection`, etc.), and the shape varies
/// per endpoint, so each repository's own DTO parsing decides what to do
/// with it.
typedef DataParser<T> = T Function(Object? body);

/// The single entry point for talking to the 911 Rescue API.
///
/// Every method returns `Future<Result<T>>` — it never throws. This API
/// signals failure two different ways, and both are handled here so no
/// repository has to remember either: a non-2xx status, or an HTTP 200
/// body containing an `error` field ("errors do not always use error
/// status codes" — see API_DOCUMENTATION.md).
///
/// Sessions are cookies, not a bearer token (see [cookieJarProvider]), so
/// there's no auth header interceptor to add here the way a token-based
/// API would need.
class ApiClient {
  ApiClient(this._dio);

  final Dio _dio;

  final StreamController<void> _unauthorized =
      StreamController<void>.broadcast();

  /// Emits once per 401 response — the auth layer can listen and force a
  /// logout of whichever identity (public user / responder / admin) hit
  /// it, independent of who made the call.
  Stream<void> get onUnauthorized => _unauthorized.stream;

  void dispose() => _unauthorized.close();

  Future<Result<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    required DataParser<T> parse,
  }) => _send(() => _dio.get<dynamic>(path, queryParameters: query), parse);

  Future<Result<T>> post<T>(
    String path, {
    Object? body,
    required DataParser<T> parse,
  }) => _send(() => _dio.post<dynamic>(path, data: body), parse);

  /// `multipart/form-data` — used only by the voice-note upload
  /// (`POST /api/ping/{id}/voice`, field `audio`).
  Future<Result<T>> postMultipart<T>(
    String path, {
    required FormData formData,
    required DataParser<T> parse,
  }) => _send(() => _dio.post<dynamic>(path, data: formData), parse);

  Future<Result<T>> _send<T>(
    Future<Response<dynamic>> Function() request,
    DataParser<T> parse,
  ) async {
    try {
      final response = await request();
      final body = response.data;
      final topLevelError = _errorMessage(body);
      if (topLevelError != null) {
        return Err(
          RemoteFailure(
            message: topLevelError,
            statusCode: response.statusCode,
          ),
        );
      }
      return Ok(parse(body));
    } on DioException catch (e, st) {
      return Err(_mapDioException(e, st));
    } on JsonFormatException catch (e, st) {
      return Err(UnknownFailure(message: e.message, cause: e, stackTrace: st));
    } catch (e, st) {
      return Err(UnknownFailure(message: '$e', cause: e, stackTrace: st));
    }
  }

  AppFailure _mapDioException(DioException e, StackTrace st) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return TimeoutFailure(cause: e, stackTrace: st);
      case DioExceptionType.connectionError:
        return NetworkFailure(cause: e, stackTrace: st);
      case DioExceptionType.cancel:
        return UnknownFailure(
          message: 'request cancelled',
          cause: e,
          stackTrace: st,
        );
      case DioExceptionType.badCertificate:
        return NetworkFailure(
          message: 'bad TLS certificate',
          cause: e,
          stackTrace: st,
        );
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final status = e.response?.statusCode;
    final errorBody = e.response?.data;
    final serverMessage = _errorMessage(errorBody);
    final code = _errorCode(errorBody);
    final message = serverMessage ?? e.message ?? 'request failed';

    switch (status) {
      case 401:
        _unauthorized.add(null);
        return UnauthorizedFailure(
          message: message,
          code: code,
          serverMessage: serverMessage,
          cause: e,
          stackTrace: st,
        );
      case 404:
        return NotFoundFailure(message: message, cause: e, stackTrace: st);
      case 409:
        return ConflictFailure(message: message, cause: e, stackTrace: st);
      case 410:
        return GoneFailure(message: message, cause: e, stackTrace: st);
      case 429:
        return RateLimitFailure(message: message, cause: e, stackTrace: st);
    }
    if (status != null && status >= 500) {
      return ServerFailure(
        message: message,
        statusCode: status,
        cause: e,
        stackTrace: st,
      );
    }
    // Any other 4xx that carried an `error` message — the backend wrote it
    // for the user.
    if (status != null && status >= 400 && serverMessage != null) {
      return RemoteFailure(
        message: serverMessage,
        statusCode: status,
        cause: e,
        stackTrace: st,
      );
    }
    if (e.type == DioExceptionType.unknown) {
      return NetworkFailure(cause: e, stackTrace: st);
    }
    return ServerFailure(
      message: message,
      statusCode: status,
      cause: e,
      stackTrace: st,
    );
  }

  /// The API's one consistent error shape: `{"error": "..."}` — present on
  /// both a 200 (see class doc) and a non-2xx error body.
  String? _errorMessage(Object? body) {
    if (body is Map && body['error'] is String) return body['error'] as String;
    return null;
  }

  /// e.g. `"rate_limited"`, `"session_superseded"` — present alongside
  /// `error` on some responses, absent on most.
  String? _errorCode(Object? body) {
    if (body is Map && body['code'] is String) return body['code'] as String;
    return null;
  }
}

/// The shared [Dio] instance. A plain synchronous provider — the one thing
/// that needs async setup, the cookie jar, is resolved up front in
/// `bootstrap()` and supplied via `overrideWithValue` (see
/// cookie_jar_provider.dart), so nothing built on top of this has to deal
/// with a `FutureProvider`.
final dioProvider = Provider<Dio>((ref) {
  final config = ref.watch(appConfigProvider);

  final dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 20),
      headers: const {'Accept': 'application/json'},
      // We classify status codes ourselves; let dio surface non-2xx as
      // DioExceptions instead of silently returning them as a Response.
      validateStatus: (status) =>
          status != null && status >= 200 && status < 300,
    ),
  );

  // Cookies before retry: a retried request needs the (possibly just
  // refreshed) cookie jar re-applied, same as any other request.
  dio.interceptors.add(CookieManager(ref.watch(cookieJarProvider)));
  dio.interceptors.add(RetryInterceptor(dio));
  if (kDebugMode) {
    dio.interceptors.add(
      LogInterceptor(requestBody: true, responseBody: true, logPrint: _logLine),
    );
  }

  ref.onDispose(dio.close);
  return dio;
});

/// `logPrint` for dio's [LogInterceptor]: uses `debugPrint` (not `print`,
/// so it's lint-clean) and masks any `cookie` / `set-cookie` header line —
/// this API's session lives entirely in the cookie, so that line is as
/// sensitive as a bearer token would be elsewhere. Only attached in debug
/// builds.
void _logLine(Object line) {
  final text = line.toString();
  final lower = text.toLowerCase().trimLeft();
  final redacted =
      lower.startsWith('cookie:') || lower.startsWith('set-cookie:');
  final safe = redacted ? text.replaceAll(RegExp(r':.*'), ': ***') : text;
  debugPrint('[api] $safe');
}

final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(ref.watch(dioProvider));
  ref.onDispose(client.dispose);
  return client;
});
