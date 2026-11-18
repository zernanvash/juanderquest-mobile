import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_search_bar.dart';
import 'package:juanderquest_app/features/spots/explore/widgets/explore_search_results.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';

// Owner 2026-11-18 (v0.3.3): Explore search panel; 0 overflow at the
// smallest phones with 2x text.
SpotModel _spot(int i) => SpotModel(
      id: 's$i',
      slug: 'spot-$i',
      name: 'Very Long Destination Name Number $i In Pangasinan Province',
      description: '',
      category: 'nature_outdoors',
      municipality: 'San Fabian Municipality Long Name',
      subcategory: '',
      address: '',
      sourceName: '',
      trustLevel: 'community',
      gpsLat: 16,
      gpsLng: 120,
      tags: const ['beach'],
      reasons: const [],
      crowdStatus: 'quiet',
      crowdConfidence: 'low',
    );

void main() {
  final controller = TextEditingController(text: 'very long destination');
  final focus = FocusNode();

  Future<void> pump(
      WidgetTester tester, Size size, String query, List<String> recent) async {
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.pixel,
      home: MediaQuery(
        data: MediaQueryData(
            size: size, textScaler: const TextScaler.linear(2.0)),
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(8),
            children: [
              ExploreSearchBar(
                controller: controller,
                focusNode: focus,
                active: true,
                onChanged: (_) {},
                onSubmitted: (_) {},
                onClose: () {},
              ),
              ExploreSearchResults(
                query: query,
                spots: [for (var i = 0; i < 4; i++) _spot(i)],
                recent: recent,
                onPickRecent: (_) {},
                onRemoveRecent: (_) {},
                onClearRecent: () {},
                onOpenSpot: (_) {},
                onMoreFilters: () {},
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('search matches do not overflow at $size', (tester) async {
      await pump(tester, size, 'destination', const []);
      expect(find.byKey(const ValueKey('explore_search_result_0')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('recent searches do not overflow at $size', (tester) async {
      await pump(tester, size, '', [
        'a very long previous search about beaches and waterfalls',
        'manaoag',
      ]);
      expect(find.text('RECENT SEARCHES'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
