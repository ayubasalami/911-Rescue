import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

/// The web's "Data Sources & Attribution" modal — same sources, links and
/// descriptions.
Future<void> showDataSourcesDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const DataSourcesDialog(),
);

const _sources = [
  (
    name: 'Mapbox',
    url: 'https://www.mapbox.com/about/maps/',
    desc:
        'Primary engine for turn-by-turn directions, accessibility '
        '(isochrone) analysis, and live traffic conditions.',
  ),
  (
    name: 'OpenStreetMap (OSM)',
    url: 'https://www.openstreetmap.org/copyright',
    desc:
        'Underlying road network and base map data. © OpenStreetMap '
        'contributors.',
  ),
  (
    name: 'Project OSRM',
    url: 'http://project-osrm.org/',
    desc:
        'Fallback routing engine used only if the primary routing service '
        'is unavailable.',
  ),
  (
    name: 'Humanitarian Data Exchange (HDX)',
    url: 'https://data.humdata.org/dataset/nigeria-health-facilities',
    desc:
        'Population raster data used to estimate affected population '
        'within each catchment area.',
  ),
  (
    name: 'Groq (Llama 3.3)',
    url: 'https://groq.com/',
    desc:
        'Powers the AI emergency triage assistant that classifies incident '
        'reports and routes them to the right responder.',
  ),
  (
    name: 'BW Analytics (O.G.D.I)',
    url: 'https://bwanalytics.com.ng/ogdi/',
    desc:
        'Supplemental road network data and spatial infrastructure '
        'integration.',
  ),
];

class DataSourcesDialog extends StatelessWidget {
  const DataSourcesDialog({super.key});

  Future<void> _open(BuildContext context, String url) async {
    final launched = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(25),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(right: 32),
                    child: Text(
                      'Data Sources & Attribution',
                      style: TextStyle(
                        color: context.palette.primary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Divider(height: 1),
                  const SizedBox(height: 15),
                  for (final source in _sources)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            onTap: () => _open(context, source.url),
                            child: Text(
                              source.name,
                              style: TextStyle(
                                color: context.palette.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                height: 1.6,
                              ),
                            ),
                          ),
                          Text(
                            source.desc,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 13,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: context.palette.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
