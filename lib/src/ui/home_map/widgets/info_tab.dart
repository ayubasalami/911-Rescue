import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import 'data_sources_dialog.dart';
import 'how_to_use_dialog.dart';

Future<void> _openLink(BuildContext context, String url) async {
  final launched = await launchUrl(Uri.parse(url));
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
  }
}

/// The Info tab: what the app is, how to use it, the data behind it, who
/// made it and how to get in touch.
class InfoTab extends StatelessWidget {
  const InfoTab({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: const [
        Text(
          'About 911 Rescue',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12),
        HowToUseContent(),
        Divider(height: 24),
        DataSourcesContent(),
        Divider(height: 24),
        _ContactSection(),
      ],
    );
  }
}

class _ContactSection extends StatelessWidget {
  const _ContactSection();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () =>
                      _openLink(context, 'https://bwanalytics.com.ng/'),
                  child: Text(
                    'Made by BW Analytics',
                    style: TextStyle(
                      color: context.palette.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap: () => _openLink(
                  context,
                  'https://www.linkedin.com/company/bwanalytics/',
                ),
                child: Image.asset(
                  'assets/images/linkedin_icon.png',
                  width: 22,
                  height: 22,
                  color: context.palette.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _openLink(context, 'https://wa.me/2348154225124'),
                child: Image.asset(
                  'assets/images/whatsapp_icon.png',
                  width: 22,
                  height: 22,
                  color: context.palette.textSecondary,
                  colorBlendMode: BlendMode.srcIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => _openLink(context, 'mailto:ogdi@bwanalytics.com'),
            child: Text(
              'ogdi@bwanalytics.com',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          GestureDetector(
            onTap: () => _openLink(context, 'tel:+2348154225124'),
            child: Text(
              '+234 815 422 5124',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
