import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../core/widgets/app_button.dart';

/// The Discover tab's states other than results: the analysis starts as soon
/// as the tab opens, so it's either running or couldn't run.
class DiscoverStatus extends StatelessWidget {
  const DiscoverStatus({
    super.key,
    required this.scrollController,
    this.message,
    this.onRetry,
  });

  final ScrollController scrollController;

  /// Why there are no results. Null while the analysis runs.
  final String? message;

  /// Offered with [message] when running it again could help.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        if (message == null) ...[
          const Center(child: CircularProgressIndicator()),
          const SizedBox(height: 16),
          Text(
            'Analyzing access near you…',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
        ] else ...[
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: context.palette.textSecondary),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            Center(
              child: AppButton(label: 'Try again', onPressed: onRetry!),
            ),
          ],
        ],
      ],
    );
  }
}
