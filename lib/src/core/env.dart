import 'dart:io' show Platform;

/// True when running under `flutter test`. Several services short-circuit
/// real platform-channel/network calls in this environment — neither
/// works under the test harness, and for a network call specifically,
/// letting it actually attempt and retry against an unreachable host would
/// make every widget test slow and flaky rather than fail fast.
bool get isTestEnvironment => Platform.environment.containsKey('FLUTTER_TEST');
