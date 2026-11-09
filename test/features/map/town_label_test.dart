import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/engine/maplibre_jdq_map.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Town Label Metrics & Rasterization (Plan 82b WP-1 & WP-3)', () {
    test('computeTownLabelMetrics computes sizes and weights by administrative level', () {
      final province = computeTownLabelMetrics(text: 'Pangasinan', level: 'province');
      expect(province.fontSizeDp, 16.0);
      expect(province.fontWeight, FontWeight.bold);
      expect(province.padHDp, 6.0);
      expect(province.padVDp, 4.0);
      expect(province.outlineDp, 1.5);
      expect(province.underlineDp, 2.0);

      final city = computeTownLabelMetrics(text: 'Dagupan', level: 'city');
      expect(city.fontSizeDp, 14.0);
      expect(city.fontWeight, FontWeight.bold);

      final municipality = computeTownLabelMetrics(text: 'Bolinao', level: 'municipality');
      expect(municipality.fontSizeDp, 14.0);
      expect(municipality.fontWeight, FontWeight.bold);

      final town = computeTownLabelMetrics(text: 'Calasiao', level: 'town');
      expect(town.fontSizeDp, 14.0);
      expect(town.fontWeight, FontWeight.bold);

      final barangay = computeTownLabelMetrics(text: 'Poblacion', level: 'barangay');
      expect(barangay.fontSizeDp, 12.0);
      expect(barangay.fontWeight, FontWeight.normal);
    });

    test('Long town names scale down font size with a minimum of 10 dp', () {
      final shortName = computeTownLabelMetrics(text: 'Alaminos', level: 'city');
      expect(shortName.effectiveFontSizeDp, 14.0);

      // Very long place name
      final longName = computeTownLabelMetrics(
        text: 'SAN CARLOS CITY AGRICULTURAL DISTRICT THREE',
        level: 'city',
      );
      expect(longName.effectiveFontSizeDp, lessThan(14.0));
      expect(longName.effectiveFontSizeDp, greaterThanOrEqualTo(10.0));
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

      // Font size at dpr 3: 14 * 3 = 42 px. With padding and underline, height is around 42 + pad (24) + underline (6)
      expect(imgCity.height, greaterThan(40));

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
