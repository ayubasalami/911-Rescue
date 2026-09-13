import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

/// The 911 Rescue API is cookie-session based, not bearer-token — "every
/// authenticated request must send cookies... on mobile you need a
/// persistent cookie jar." [PersistCookieJar] writes cookies to disk so a
/// signed-in session (public user, responder, or admin — the API allows
/// all three at once) survives an app restart, matching how a browser
/// would behave.
///
/// Resolving it needs disk access, so it can't be a plain synchronous
/// provider like the rest of this app's services — it's created once in
/// `bootstrap()` via [createCookieJar] and supplied with
/// `overrideWithValue`, the same way `appConfigProvider` is. Every other
/// network provider built on top of this (see api_client.dart) stays a
/// normal synchronous `Provider` as a result.
final cookieJarProvider = Provider<PersistCookieJar>((ref) {
  throw UnimplementedError(
    'cookieJarProvider must be overridden in bootstrap()',
  );
});

Future<PersistCookieJar> createCookieJar() async {
  final dir = await getApplicationDocumentsDirectory();
  return PersistCookieJar(
    ignoreExpires: true,
    storage: FileStorage('${dir.path}/.cookies/'),
  );
}
