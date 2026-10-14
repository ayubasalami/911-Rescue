import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_config.dart';
import '../../../data/services/crash_reporting_service.dart';
import 'app_button.dart';

/// Staging builds only. Crashes the app on purpose — a real native crash —
/// so Crashlytics reporting and alerts can be tested. The report shows up
/// after the next launch.
///
/// Gated on the flavor, not `kDebugMode`: TestFlight builds are release
/// builds (and debug builds don't send reports at all — see
/// [CrashReportingService.create]). Renders nothing on dev and prod.
class StagingTestCrashButton extends ConsumerWidget {
  const StagingTestCrashButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final environment = ref.watch(appConfigProvider).environment;
    if (environment != AppEnvironment.staging) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: AppButton(
        label: '🧪 Trigger test crash',
        variant: AppButtonVariant.danger,
        filled: false,
        onPressed: ref.read(crashReportingServiceProvider).forceCrash,
      ),
    );
  }
}
