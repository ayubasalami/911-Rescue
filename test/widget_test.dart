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

    expect(find.text('SOS'), findsOneWidget);
    expect(find.text('Map'), findsOneWidget);

    await tester.tap(find.text('SOS'));
    await tester.pumpAndSettle();

    expect(find.text('🚨 Get Help Fast'), findsOneWidget);
    expect(find.text('Ping for Help'), findsOneWidget);
    expect(find.text('Go to Help'), findsOneWidget);

    await tester.tap(find.text('Go to Help'));
    await tester.pumpAndSettle();

    expect(find.text('Then choose help type'), findsOneWidget);
    expect(find.text('Hospital'), findsOneWidget);
  });
}
