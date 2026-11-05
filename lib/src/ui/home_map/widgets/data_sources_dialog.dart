import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

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
    url: 'https://project-osrm.org/',
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

/// The web's "Data Sources & Attribution" — same sources, links and
/// descriptions — for the Info tab.
class DataSourcesContent extends StatelessWidget {
  const DataSourcesContent({super.key});

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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Data Sources & Attribution',
          style: TextStyle(
            color: context.palette.primary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
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
    );
  }
}
