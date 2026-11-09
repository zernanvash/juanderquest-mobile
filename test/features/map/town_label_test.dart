import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Town Label Metrics & Rasterization (Plan 82b WP-1 & WP-3)', () {
    // Owner 2026-11-09: no box, plain text with a halo, like Google Maps.
    test('label style by level: towns 13 dp bold, province 15, barangays 10 dp grey', () {
      final province = computeTownLabelMetrics(text: 'Pangasinan', level: 'province');
      expect((province.fontSizeDp, province.fontWeight), (15.0, FontWeight.bold));
      for (final level in ['city', 'municipality', 'town']) {
        final t = computeTownLabelMetrics(text: 'Dagupan', level: level);
        expect((t.fontSizeDp, t.fontWeight), (13.0, FontWeight.bold), reason: level);
      }
      final barangay = computeTownLabelMetrics(text: 'Bonuan Gueset', level: 'barangay');
      expect((barangay.fontSizeDp, barangay.fontWeight), (10.0, FontWeight.normal));
      expect(barangay.color, isNot(province.color));
      expect(province.haloDp, 2.0);
    });

    test('long names shrink to fit, never below 9 dp', () {
      expect(computeTownLabelMetrics(text: 'Alaminos', level: 'city').effectiveFontSizeDp, 13.0);
      final long = computeTownLabelMetrics(text: 'SAN CARLOS CITY AGRICULTURAL DISTRICT THREE', level: 'city');
      expect(long.effectiveFontSizeDp, lessThan(13.0));
      expect(long.effectiveFontSizeDp, greaterThanOrEqualTo(9.0));
    });

    test('rasterizeTownLabel produces valid image buffer with expected dimensions at dpr 3', () async {
      final bytesCity = await rasterizeTownLabel(
        'Dagupan',
        level: 'city',
        isFocused: false,
        dpr: 3.0,
      );
      expect(bytesCity, isNotNull);
      final codecCity = await ui.instantiateImageCodec(bytesCity!);
      final frameCity = await codecCity.getNextFrame();
      final imgCity = frameCity.image;

      // 13 dp at dpr 3 = 39 px text plus a 6 px halo on each side, and no box padding.
      expect(imgCity.height, inInclusiveRange(40, 70));

      final bytesProvince = await rasterizeTownLabel(
        'Pangasinan',
        level: 'province',
        isFocused: false,
        dpr: 3.0,
      );
      final codecProvince = await ui.instantiateImageCodec(bytesProvince!);
      final frameProvince = await codecProvince.getNextFrame();
      final imgProvince = frameProvince.image;

      final bytesBarangay = await rasterizeTownLabel(
        'Bonuan',
        level: 'barangay',
        isFocused: false,
        dpr: 3.0,
      );
      final codecBarangay = await ui.instantiateImageCodec(bytesBarangay!);
      final frameBarangay = await codecBarangay.getNextFrame();
      final imgBarangay = frameBarangay.image;

      // Province height > City height > Barangay height
      expect(imgProvince.height, greaterThan(imgCity.height));
      expect(imgCity.height, greaterThan(imgBarangay.height));
    });
  });
}
