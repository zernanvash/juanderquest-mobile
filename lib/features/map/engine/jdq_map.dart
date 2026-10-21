import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../utils/admin_areas.dart';

class JdqCamera {
  const JdqCamera(
      {required this.center,
      required this.zoom,
      required this.southWest,
      required this.northEast,
      this.size = Size.zero});
  final LatLng center, southWest, northEast;
  final double zoom;
  final Size size;
}

class JdqPin {
  const JdqPin(this.id, this.point, this.label, {this.quest = false});
  final String id, label;
  final LatLng point;
  final bool quest;
}

/// No platform controller escapes into screen logic or widget tests.
abstract class JdqMap {
  JdqCamera camera = const JdqCamera(
      center: LatLng(16.035, 120.333),
      zoom: 10.5,
      southWest: LatLng(15.5, 119.5),
      northEast: LatLng(16.6, 121));
  void Function(String id)? onTapPlace, onTapPin;
  void Function(LatLng point)? onTapEmpty;
  VoidCallback? onCameraIdle;
  Future<void> setStyle(String style);
  Future<void> easeTo(LatLng point, double zoom, {bool reducedMotion = false});
  Future<void> fitBounds(
      LatLng southWest, LatLng northEast, EdgeInsets padding);
  Future<void> setPins(List<JdqPin> pins);
  Future<void> setPlaces(List<AdminArea> places);
  Future<void> setFocusArea(AreaShape shape);
  Future<void> clearFocus();
  void setMyLocation(bool enabled);
  Widget build(
      {required VoidCallback onReady, required VoidCallback onFailure});
  void dispose();
}

/// Injectable non-platform surface; tests explicitly exercise callbacks.
class FakeJdqMap extends JdqMap {
  String? style;
  List<JdqPin> pins = [];
  List<AdminArea> places = [];
  AreaShape? focus;
  bool locationEnabled = false;
  @override
  Future<void> setStyle(String style) async {
    this.style = style;
  }

  @override
  Future<void> easeTo(LatLng point, double zoom,
      {bool reducedMotion = false}) async {
    camera = JdqCamera(
        center: point,
        zoom: zoom,
        southWest: camera.southWest,
        northEast: camera.northEast,
        size: camera.size);
    onCameraIdle?.call();
  }

  @override
  Future<void> fitBounds(
      LatLng southWest, LatLng northEast, EdgeInsets padding) async {
    camera = JdqCamera(
        center: LatLng((southWest.latitude + northEast.latitude) / 2,
            (southWest.longitude + northEast.longitude) / 2),
        zoom: camera.zoom,
        southWest: southWest,
        northEast: northEast,
        size: camera.size);
    onCameraIdle?.call();
  }

  @override
  Future<void> setPins(List<JdqPin> pins) async {
    this.pins = pins;
  }

  @override
  Future<void> setPlaces(List<AdminArea> places) async {
    this.places = places;
  }

  @override
  Future<void> setFocusArea(AreaShape shape) async {
    focus = shape;
  }

  @override
  Future<void> clearFocus() async {
    focus = null;
  }

  @override
  void setMyLocation(bool enabled) {
    locationEnabled = enabled;
  }

  @override
  Widget build(
      {required VoidCallback onReady, required VoidCallback onFailure}) {
    return _FakeSurface(onReady: onReady);
  }

  @override
  void dispose() {}
}

class _FakeSurface extends StatefulWidget {
  const _FakeSurface({required this.onReady});
  final VoidCallback onReady;
  @override
  State<_FakeSurface> createState() => _FakeSurfaceState();
}

class _FakeSurfaceState extends State<_FakeSurface> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onReady();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const ColoredBox(key: ValueKey('fake-jdq-map'), color: Color(0xfffaf9f5));
}
