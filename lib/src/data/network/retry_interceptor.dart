import 'dart:async';
import 'dart:io' show HttpDate, HttpException, SocketException;
import 'dart:math';

import 'package:dio/dio.dart';

/// Retries **GET** requests that failed on a transient network or server
/// error.
///
/// Mutations are never retried — a replayed `POST /api/ping` could raise a
/// duplicate emergency, and a replayed accept/cancel could double-fire.
/// Failed mutations surface their error and the user retries explicitly.
///
/// Runs `dio.fetch(requestOptions)` for the retry, so cookies and the rest
/// of the interceptor chain are re-applied each attempt.
class RetryInterceptor extends Interceptor {
  RetryInterceptor(
    this._dio, {
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 400),
    this.maxElapsed = const Duration(seconds: 20),
  });

  final Dio _dio;
  final int maxAttempts;
  final Duration baseDelay;

  /// Hard cap on total time spent retrying one request — so a dead server
  /// behind a live interface can't stretch a call to ~1 minute.
  final Duration maxElapsed;

  final _rng = Random();

  static const _attemptKey = 'retry_attempt';
  static const _startedKey = 'retry_started_ms';
  static const _retriableStatus = {408, 425, 429, 500, 502, 503, 504};

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final attempt = (options.extra[_attemptKey] as int?) ?? 0;
    final startedMs =
        (options.extra[_startedKey] as int?) ??
        DateTime.now().millisecondsSinceEpoch;

    if (!_shouldRetry(err, options, attempt, startedMs)) {
      return handler.next(err);
    }

    await Future<void>.delayed(_backoff(err, attempt));

    try {
      options.extra[_attemptKey] = attempt + 1;
      options.extra[_startedKey] = startedMs;
      final response = await _dio.fetch<dynamic>(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  bool _shouldRetry(
    DioException err,
    RequestOptions options,
    int attempt,
    int startedMs,
  ) {
    if (attempt >= maxAttempts - 1) return false;
    if (options.method.toUpperCase() != 'GET') return false;
    final elapsed = DateTime.now().millisecondsSinceEpoch - startedMs;
    if (elapsed >= maxElapsed.inMilliseconds) return false;
    return switch (err.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout => true,
      // dio's catch-all — retry only when it wraps an actual transport
      // error, not a response-parsing / downstream-interceptor exception.
      DioExceptionType.unknown =>
        err.error is SocketException || err.error is HttpException,
      DioExceptionType.badResponse => _retriableStatus.contains(
        err.response?.statusCode,
      ),
      _ => false,
    };
  }

  Duration _backoff(DioException err, int attempt) {
    final retryAfter = _retryAfter(err.response?.headers.value('retry-after'));
    if (retryAfter != null) return retryAfter;
    // baseDelay × 3^attempt (400ms, 1.2s, 3.6s …) plus jitter.
    final base = baseDelay.inMilliseconds * pow(3, attempt).toInt();
    return Duration(milliseconds: base + _rng.nextInt(250));
  }

  /// `Retry-After` is either delta-seconds or an HTTP-date. Clamped to 30s.
  Duration? _retryAfter(String? header) {
    if (header == null) return null;
    final seconds = int.tryParse(header);
    if (seconds != null) return Duration(seconds: seconds.clamp(0, 30));
    try {
      final delta = HttpDate.parse(header).difference(DateTime.now());
      if (delta <= Duration.zero) return Duration.zero;
      return delta > const Duration(seconds: 30)
          ? const Duration(seconds: 30)
          : delta;
    } on Object {
      return null;
    }
  }
}
