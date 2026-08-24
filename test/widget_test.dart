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
              apiBaseUrl: 'https://dev.api.911rescueme.com',
            ),
          ),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('911 Rescue'), findsOneWidget);
  });
}
