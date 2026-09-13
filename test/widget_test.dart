import 'package:cookie_jar/cookie_jar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/app.dart';
import 'package:rescue_911/src/core/config/app_config.dart';
import 'package:rescue_911/src/data/network/cookie_jar_provider.dart';

void main() {
  testWidgets('App boots to the Home/Map screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              appDisplayName: '911 Rescue Dev',
              // Needs a real scheme — Dio's BaseOptions.baseUrl setter
              // validates this eagerly when dioProvider builds, before
              // FacilityService's own test-environment short-circuit
              // (which only guards the network call, not provider
              // construction) ever runs.
              apiBaseUrl: 'https://api.911rescueme.com',
              mapboxAccessToken: 'pk.test',
            ),
          ),
          // A plain in-memory CookieJar — no disk/platform-channel access,
          // unlike the PersistCookieJar bootstrap() builds for the real
          // app. HomeMapViewModel now fetches facilities from the API on
          // load; the test sandbox has no real network access, so that
          // call fails gracefully to an empty list rather than hanging on
          // an unoverridden provider.
          cookieJarProvider.overrideWithValue(CookieJar()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🚨'), findsOneWidget);
    expect(find.textContaining('Rescue', findRichText: true), findsOneWidget);

    await tester.tap(find.text('🚨'));
    await tester.pumpAndSettle();

    expect(find.text('Report Incident'), findsOneWidget);
    expect(find.text('Call for Help - 112'), findsOneWidget);

    await tester.tap(find.text('Report Incident'));
    await tester.pumpAndSettle();

    expect(find.text('911 Rescue Triage'), findsOneWidget);
    expect(find.text('Call 112 Now'), findsOneWidget);

    await tester.tap(find.text('Report Incident'));
    await tester.pumpAndSettle();

    expect(find.text('Chest pain'), findsOneWidget);
    expect(find.text('Describe your symptoms...'), findsOneWidget);
  });
}
