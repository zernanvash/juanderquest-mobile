import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';
import 'package:juanderquest_app/features/map/screens/map_view_screen.dart';
import 'package:juanderquest_app/features/map/utils/admin_areas.dart';
import 'package:juanderquest_app/features/spots/studio/pixel/studio_picker_field.dart';
import 'package:juanderquest_app/features/spots/utils/pangasinan_towns.dart';
import 'package:juanderquest_app/features/spots/utils/spot_posting.dart';
import 'package:juanderquest_app/features/spots/widgets/spot_posting_sheet.dart';
import 'package:latlong2/latlong.dart';

const _area = AdminArea(
  id: 'a1',
  level: 'municipality',
  name: 'Bolinao',
  displayName: 'Bolinao, Pangasinan',
  label: LatLng(16.38, 119.89),
  hasBoundary: true,
);

Map<String, dynamic> _recognition(String? town) => {
      'recognized': true,
      'place_name': 'Patar White Beach',
      'name_suggestions': ['Patar White Beach'],
      'formatted_address': 'Patar Road, Brgy. Patar, Bolinao, Pangasinan',
      'municipality': town,
      'barangay': 'Brgy. Patar',
      'outside_pangasinan': false,
      'suggested_category': 'nature_outdoors',
      'suggested_subcategory': 'beach',
      'suggested_details': {},
      'story_starters': [
        'Patar White Beach in Brgy. Patar, Bolinao with relaxing views and fresh air.',
      ],
      'nearby_duplicates': [],
    };

ApiClient _client(Map<String, dynamic> recognition, List<dynamic> posted) {
  final client = ApiClient();
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (o.path == '/spots/recognize') {
      return h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {'success': true, 'data': recognition}));
    }
    if (o.path == '/spots' && o.method == 'POST') {
      posted.add(o.data);
      return h.resolve(Response(requestOptions: o, statusCode: 201, data: {
        'success': true,
        'data': {
          'id': 's1',
          'slug': 'patar',
          'name': 'Patar White Beach',
          'gps_lat': 16.3268,
          'gps_lng': 119.7842
        },
      }));
    }
    return h.next(o);
  }));
  return client;
}

Widget _sheet(ApiClient client) => ProviderScope(
      overrides: [apiClientProvider.overrideWithValue(client)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
            body: SpotPostingSheet(initialLat: 16.3268, initialLng: 119.7842)),
      ),
    );

Widget _banner({VoidCallback? onClear}) => MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: MapAreaBanner(
            area: _area,
            questsCount: 2,
            spotsCount: 3,
            onClear: onClear ?? () {},
            onPinSpot: () {},
          ),
        ),
      ),
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('town focus banner', () {
    testWidgets('one small unboxed X closes it; no ZOOM OUT button',
        (tester) async {
      var cleared = 0;
      await tester.pumpWidget(_banner(onClear: () => cleared++));
      expect(find.text('ZOOM OUT'), findsNothing);
      final x = find.byKey(const ValueKey('area_clear'));
      expect(x, findsOneWidget);
      final button = tester.widget<PixelIconButton>(x);
      expect(button.boxed, isFalse);
      expect(button.iconHeight, 16);
      expect(find.byType(PixelIconButton), findsOneWidget);
      expect(find.byTooltip('Close map'), findsOneWidget);
      expect(find.bySemanticsLabel('Close map'), findsOneWidget);
      final size = tester.getSize(x);
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(x);
      expect(cleared, 1);
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('does not overflow at $size, 2.0x text', (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_banner());
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('map pins', () {
    test('render clearly bigger, at whole-number pixel scales', () {
      for (final dpr in const [2.0, 2.625, 2.75, 3.0, 3.5]) {
        final quest = MapLibreJdqMap.pinScale(
            MapLibreJdqMap.questPinDp, dpr, DesignerArt.questMarker.height);
        final spot = MapLibreJdqMap.pinScale(
            MapLibreJdqMap.spotPinDp, dpr, DesignerArt.spotMarker.height);
        expect(quest, quest.roundToDouble(), reason: 'dpr $dpr');
        expect(spot, spot.roundToDouble(), reason: 'dpr $dpr');
        final questDp = DesignerArt.questMarker.height * quest / dpr;
        final spotDp = DesignerArt.spotMarker.height * spot / dpr;
        // Before: ~37 dp quest and ~21-23 dp spot on a 3x / 2.75x phone.
        expect(questDp, greaterThanOrEqualTo(50), reason: 'dpr $dpr');
        expect(spotDp, greaterThanOrEqualTo(40), reason: 'dpr $dpr');
      }
    });
  });

  group('post-a-spot location pickers', () {
    test('town list: Pangasinan, 44 towns + 4 cities, GPS names matched', () {
      final towns = spotProvinceTowns['Pangasinan']!;
      expect(spotProvinceTowns.keys, ['Pangasinan']);
      expect(towns.length, 48);
      expect(towns.toSet().length, 48);
      expect(
          towns,
          containsAll(const [
            'Alaminos City',
            'Dagupan City',
            'San Carlos City',
            'Urdaneta City'
          ]));
      expect(canonicalSpotTown('City of Dagupan'), 'Dagupan City');
      expect(canonicalSpotTown('dagupan'), 'Dagupan City');
      expect(canonicalSpotTown('Lingayen (Capital)'), 'Lingayen');
      expect(canonicalSpotTown('Sta. Barbara'), 'Santa Barbara');
      expect(canonicalSpotTown('Baguio City'), isNull);
      expect(canonicalSpotTown('Bolinao', province: 'Elsewhere'), isNull);
      expect(
          validatePostingDraft(const SpotPostingDraft(municipality: 'Baguio'))
              .containsKey('municipality'),
          isTrue);
      expect(
          validatePostingDraft(const SpotPostingDraft(municipality: 'Bolinao'))
              .containsKey('municipality'),
          isFalse);
    });

    testWidgets(
        'pre-fills the GPS town, picks another from the list and posts it',
        (tester) async {
      final posted = <dynamic>[];
      await tester
          .pumpWidget(_sheet(_client(_recognition('City of Dagupan'), posted)));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('studio_edit_address')));

      final province = tester.widget<StudioPickerField>(
          find.byKey(const ValueKey('studio_province')));
      expect(province.value, 'Pangasinan');
      final town = tester.widget<StudioPickerField>(
          find.byKey(const ValueKey('studio_municipality')));
      expect(town.value, 'Dagupan City');
      expect(town.options, spotProvinceTowns['Pangasinan']);
      expect(find.byType(TextField).evaluate().length, lessThan(5));

      await _tap(tester, find.byKey(const ValueKey('studio_municipality')));
      expect(find.byKey(const ValueKey('studio_pick_Agno')), findsOneWidget);
      await _tap(tester, find.byKey(const ValueKey('studio_pick_Bolinao')));
      expect(
          tester
              .widget<StudioPickerField>(
                  find.byKey(const ValueKey('studio_municipality')))
              .value,
          'Bolinao');

      await _tap(
          tester, find.textContaining('+ Patar White Beach in Brgy. Patar'));
      await tester.tap(find.text('Publish spot'));
      await tester.pumpAndSettle();
      expect((posted.single as Map)['municipality'], 'Bolinao');
    });

    testWidgets('an unlisted GPS town leaves the town unpicked',
        (tester) async {
      await tester.pumpWidget(_sheet(_client(_recognition('Baguio City'), [])));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const ValueKey('studio_edit_address')));
      expect(
          tester
              .widget<StudioPickerField>(
                  find.byKey(const ValueKey('studio_municipality')))
              .value,
          isNull);
      expect(find.text('Choose a town'), findsOneWidget);
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('open place pickers do not overflow at $size, 2.0x text',
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await tester.pumpWidget(_sheet(_client(_recognition('Bolinao'), [])));
        await tester.pumpAndSettle();
        await _tap(tester, find.byKey(const ValueKey('studio_edit_address')));
        await tester
            .ensureVisible(find.byKey(const ValueKey('studio_municipality')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('town list dialog does not overflow at $size, 2.0x text',
          (tester) async {
        tester.view.physicalSize = size * 2;
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        String? picked;
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => StudioPickerField(
                key: const ValueKey('field'),
                label: 'Municipality / city',
                value: picked,
                hint: 'Choose a town',
                options: spotProvinceTowns['Pangasinan']!,
                onSelected: (t) => setState(() => picked = t),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('field')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await _tap(tester, find.byKey(const ValueKey('studio_pick_Villasis')));
        expect(picked, 'Villasis');
        expect(find.text('Villasis'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
