/// A typed failure surfaced by the data layer. Repositories return it
/// wrapped in [Err] (see `result.dart`).
///
/// [ApiClient] is the only place that constructs these: it turns transport
/// errors and error responses into the right subtype so the UI can branch
/// with a `switch` and show [userMessage] without re-deriving it per call
/// site.
sealed class AppFailure implements Exception {
  const AppFailure({required this.message, this.cause, this.stackTrace});

  /// Technical description for logs. **Not** shown to users.
  final String message;

  final Object? cause;
  final StackTrace? stackTrace;

  /// Copy suitable to show a user. Screens may override per context, but
  /// this is the sensible default.
  String get userMessage => switch (this) {
    NetworkFailure() =>
      'No internet connection. Check your network and try again.',
    TimeoutFailure() => 'The request timed out. Please try again.',
    UnauthorizedFailure(code: 'session_superseded') =>
      'You signed in on another device. Please sign in again here.',
    UnauthorizedFailure(:final serverMessage?) => serverMessage,
    UnauthorizedFailure() => 'Your session has expired. Please sign in again.',
    // The backend writes these for the user (e.g. "Incorrect responder ID
    // or password").
    RemoteFailure(:final message) => message,
    NotFoundFailure() => 'We couldn\'t find what you were looking for.',
    ConflictFailure() => 'That was just taken. Please try again.',
    GoneFailure() => 'This is no longer available.',
    RateLimitFailure() =>
      'Too many attempts. Please wait a moment and try again.',
    ServerFailure() => 'Something went wrong on our end. Please try again.',
    UnknownFailure() => 'Something went wrong. Please try again.',
  };

  @override
  String toString() => '$runtimeType(${message.isEmpty ? '—' : message})';
}

/// Device is offline / the host is unreachable.
class NetworkFailure extends AppFailure {
  const NetworkFailure({
    super.message = 'network unreachable',
    super.cause,
    super.stackTrace,
  });
}

/// Connect / send / receive timed out.
class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    super.message = 'request timed out',
    super.cause,
    super.stackTrace,
  });
}

/// HTTP 401. [code] carries the backend's `code` field when present —
/// `session_superseded` means a responder logged in on another device and
/// this session was invalidated; that case clears local state and returns
/// to login rather than retrying.
///
/// A wrong-credentials login attempt is *also* a 401 (confirmed live
/// against `/api/responder/login`) and carries its own specific
/// [serverMessage] — e.g. "Incorrect responder ID or password" — which
/// must be shown verbatim rather than a generic "session expired," since
/// there was never a session to expire.
class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    super.message = 'unauthorized',
    this.code,
    this.serverMessage,
    super.cause,
    super.stackTrace,
  });

  final String? code;
  final String? serverMessage;
}

/// The backend rejected the request and wrote [message] for the user —
/// show it verbatim. Covers both `{"error": "..."}` on an HTTP 200 (several
/// endpoints do this instead of a non-2xx status) and a 4xx that carried a
/// message we don't model as a more specific failure.
class RemoteFailure extends AppFailure {
  const RemoteFailure({
    required super.message,
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// HTTP 404 — includes a Directions request with no route (long walk/cycle
/// requests beyond ~24 km are refused by both providers; treat as "too far
/// to walk," not as an error banner).
class NotFoundFailure extends AppFailure {
  const NotFoundFailure({
    super.message = 'not found',
    super.cause,
    super.stackTrace,
  });
}

/// HTTP 409 — lost a race for a resource another caller just claimed (e.g.
/// two responders accepting the same ping). Refresh and move on rather
/// than retry.
class ConflictFailure extends AppFailure {
  const ConflictFailure({
    super.message = 'conflict',
    super.cause,
    super.stackTrace,
  });
}

/// HTTP 410 — the resource existed but is now permanently unavailable
/// (voice playback for a closed incident: recordings are deleted when a
/// ping closes).
class GoneFailure extends AppFailure {
  const GoneFailure({super.message = 'gone', super.cause, super.stackTrace});
}

/// HTTP 429 — rate limited.
class RateLimitFailure extends AppFailure {
  const RateLimitFailure({
    super.message = 'rate limited',
    super.cause,
    super.stackTrace,
  });
}

/// HTTP 5xx, or a 4xx we don't model specifically.
class ServerFailure extends AppFailure {
  const ServerFailure({
    required super.message,
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  final int? statusCode;
}

/// A response we couldn't parse, or anything else unexpected.
class UnknownFailure extends AppFailure {
  const UnknownFailure({
    super.message = 'unknown error',
    super.cause,
    super.stackTrace,
  });
}
