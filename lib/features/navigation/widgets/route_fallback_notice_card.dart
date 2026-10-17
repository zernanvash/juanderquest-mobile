import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/route_model.dart';

class RouteFallbackNoticeCard extends StatelessWidget {
  const RouteFallbackNoticeCard({super.key, required this.route, required this.destination});

  final RouteModel route;
  final String destination;

  Future<void> _open(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final warning = route.warningMessage ?? 'Road routing is unavailable. This line is a distance estimate.';
    final km = route.summary.distanceKm.toStringAsFixed(1);
    return Card(
      color: const Color(0xFFFFF3CD),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(warning, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('≈ $km km straight-line distance${route.coverageLabel == null ? '' : ' • ${route.coverageLabel} coverage'}'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 4, children: [
            OutlinedButton.icon(
              onPressed: () => _open(Uri.https('www.google.com', '/maps/dir/', {
                'api': '1', 'destination': destination, 'travelmode': 'driving',
              })),
              icon: const Icon(Icons.map_outlined), label: const Text('Google Maps'),
            ),
            OutlinedButton.icon(
              onPressed: () => _open(Uri.https('waze.com', '/ul', {'ll': destination, 'navigate': 'yes'})),
              icon: const Icon(Icons.navigation), label: const Text('Waze'),
            ),
          ]),
        ]),
      ),
    );
  }
}
