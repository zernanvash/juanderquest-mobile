import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/features/map/utils/map_focus.dart';

void main() {
  group('focusTargetAboveCard', () {
    test('lifts the pin above the card by moving the center south', () {
      final target = focusTargetAboveCard(
        lat: 16.032,
        lng: 120.332,
        zoom: 13,
        mapHeightPx: 600,
      );
      expect(target.latitude, lessThan(16.032));
      expect(target.longitude, 120.332);
    });

    test('offset shrinks as zoom increases (smaller ground distance per pixel)', () {
      final lowZoom = focusTargetAboveCard(lat: 16.032, lng: 120.332, zoom: 12, mapHeightPx: 600);
      final highZoom = focusTargetAboveCard(lat: 16.032, lng: 120.332, zoom: 17, mapHeightPx: 600);
      final lowDelta = 16.032 - lowZoom.latitude;
      final highDelta = 16.032 - highZoom.latitude;
      expect(highDelta, lessThan(lowDelta));
      expect(highDelta, greaterThan(0));
    });

    test('stays valid near the poles and with extreme zoom input', () {
      final target = focusTargetAboveCard(lat: 84.9, lng: 10, zoom: 40, mapHeightPx: 800);
      expect(target.latitude.isFinite, isTrue);
      expect(target.latitude, lessThan(84.9));
      expect(target.longitude, 10);
    });
  });
}
