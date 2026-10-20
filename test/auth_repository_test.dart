import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/app_failure.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/app_user.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/repositories/auth_repository.dart';
import 'package:rescue_911/src/data/services/apple_sign_in_service.dart';
import 'package:rescue_911/src/data/services/auth_service.dart';
import 'package:rescue_911/src/data/services/google_sign_in_service.dart';

class _FakeGoogle extends GoogleSignInService {
  _FakeGoogle(this.outcome) : super('');

  final GoogleSignInOutcome outcome;
  var signedOut = false;

  @override
  Future<GoogleSignInOutcome> signIn() async => outcome;

  @override
  Future<void> signOut() async => signedOut = true;
}

class _FakeAuthService extends AuthService {
  _FakeAuthService(this.result) : super(ApiClient(Dio()));

  final Result<AppUser> result;
  String? sentToken;
  String? sentAppleCode;
  String? sentFullName;

  @override
  Future<Result<AppUser>> signInWithGoogle(String idToken) async {
    sentToken = idToken;
    return result;
  }

  @override
  Future<Result<AppUser>> signInWithApple({
    required String identityToken,
    required String authorizationCode,
    String? fullName,
  }) async {
    sentToken = identityToken;
    sentAppleCode = authorizationCode;
    sentFullName = fullName;
    return result;
  }

  @override
  Future<Result<void>> deleteAccount() async => const Ok(null);
}

class _FakeApple extends AppleSignInService {
  const _FakeApple(this.outcome);

  final AppleSignInOutcome outcome;

  @override
  Future<AppleSignInOutcome> signIn() async => outcome;
}

const _picked = GoogleSignInSucceeded(
  GoogleIdentity(email: 'a@b.com', idToken: 'token-123'),
);

AuthRepository _repository(
  _FakeAuthService service,
  _FakeGoogle google, {
  AppleSignInOutcome? apple,
  CookieJar? cookies,
}) => AuthRepository(
  service,
  google,
  cookies ?? CookieJar(),
  Uri.parse('https://api.911rescueme.com'),
  apple: _FakeApple(apple ?? const AppleSignInCancelled()),
);

void main() {
  test('sends the Google ID token and returns the user', () async {
    final service = _FakeAuthService(const Ok(AppUser(email: 'a@b.com')));
    final outcome = await _repository(service, _FakeGoogle(_picked)).signIn();
    expect(service.sentToken, 'token-123');
    expect(outcome, isA<SignedIn>());
  });

  test('a closed account picker is not an error', () async {
    final service = _FakeAuthService(const Ok(AppUser(email: 'a@b.com')));
    final outcome = await _repository(
      service,
      _FakeGoogle(const GoogleSignInCancelled()),
    ).signIn();
    expect(outcome, isA<SignInCancelled>());
    expect(service.sentToken, isNull);
  });

  test('503 says retry, not a credentials error', () async {
    final google = _FakeGoogle(_picked);
    final outcome = await _repository(
      _FakeAuthService(
        const Err(ServerFailure(message: 'unavailable', statusCode: 503)),
      ),
      google,
    ).signIn();
    expect(
      (outcome as SignInFailed).message,
      'Couldn\'t reach Google to confirm your sign-in. Please try again.',
    );
    expect(outcome.reason, 'google_unreachable');
    expect(google.signedOut, isTrue);
  });

  test('401 is a rejected sign-in', () async {
    final outcome = await _repository(
      _FakeAuthService(
        const Err(UnauthorizedFailure(serverMessage: 'Malformed token')),
      ),
      _FakeGoogle(_picked),
    ).signIn();
    expect(
      (outcome as SignInFailed).message,
      'Google sign-in was rejected. Please try again.',
    );
    expect(outcome.reason, 'rejected');
  });

  test('Apple sends the token, code and first-time name', () async {
    final service = _FakeAuthService(const Ok(AppUser(email: 'a@b.com')));
    final outcome = await _repository(
      service,
      _FakeGoogle(_picked),
      apple: const AppleSignInSucceeded(
        AppleIdentity(
          identityToken: 'apple-token',
          authorizationCode: 'one-time-code',
          fullName: 'Ada Okafor',
        ),
      ),
    ).signInWithApple();
    expect(outcome, isA<SignedIn>());
    expect(service.sentToken, 'apple-token');
    expect(service.sentAppleCode, 'one-time-code');
    expect(service.sentFullName, 'Ada Okafor');
  });

  test('an Apple 503 says Apple, and is a retry', () async {
    final outcome = await _repository(
      _FakeAuthService(
        const Err(ServerFailure(message: 'unavailable', statusCode: 503)),
      ),
      _FakeGoogle(_picked),
      apple: const AppleSignInSucceeded(
        AppleIdentity(identityToken: 't', authorizationCode: 'c'),
      ),
    ).signInWithApple();
    expect(
      (outcome as SignInFailed).message,
      'Couldn\'t reach Apple to confirm your sign-in. Please try again.',
    );
    expect(outcome.reason, 'apple_unreachable');
  });

  test('deleting the account clears the session here too', () async {
    final cookies = CookieJar();
    final host = Uri.parse('https://api.911rescueme.com');
    await cookies.saveFromResponse(host, [Cookie('session', 'abc')]);
    final google = _FakeGoogle(_picked);
    final result = await _repository(
      _FakeAuthService(const Ok(AppUser(email: 'a@b.com'))),
      google,
      cookies: cookies,
    ).deleteAccount();
    expect(result.isOk, isTrue);
    expect(await cookies.loadForRequest(host), isEmpty);
    expect(google.signedOut, isTrue);
  });
}
