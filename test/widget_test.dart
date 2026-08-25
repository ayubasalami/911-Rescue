import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescue_911/src/app.dart';
import 'package:rescue_911/src/core/config/app_config.dart';

void main() {
  testWidgets('App boots to the Home/Map screen', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              appDisplayName: '911 Rescue Dev',
              apiBaseUrl: 'example.com',
              mapboxAccessToken: 'pk.test',
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('🚨'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);

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

  testWidgets('Bottom nav switches between shell branches', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(
              environment: AppEnvironment.dev,
              appDisplayName: '911 Rescue Dev',
              apiBaseUrl: 'example.com',
              mapboxAccessToken: 'pk.test',
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Triage'));
    await tester.pumpAndSettle();
    expect(find.text('Triage Chat — coming soon'), findsOneWidget);

    await tester.tap(find.text('Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Dashboard — coming soon'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('🚨'), findsOneWidget);
  });
}
