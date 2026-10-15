import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/core/app_failure.dart';
import 'package:rescue_911/src/core/result.dart';
import 'package:rescue_911/src/data/models/app_user.dart';
import 'package:rescue_911/src/data/network/api_client.dart';
import 'package:rescue_911/src/data/repositories/auth_repository.dart';
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

  @override
  Future<Result<AppUser>> signInWithGoogle(String idToken) async {
    sentToken = idToken;
    return result;
  }
}

const _picked = GoogleSignInSucceeded(
  GoogleIdentity(email: 'a@b.com', idToken: 'token-123'),
);

AuthRepository _repository(_FakeAuthService service, _FakeGoogle google) =>
    AuthRepository(
      service,
      google,
      CookieJar(),
      Uri.parse('https://api.911rescueme.com'),
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
  });
}
