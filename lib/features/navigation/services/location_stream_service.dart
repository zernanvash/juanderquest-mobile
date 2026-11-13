import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationStreamService {
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  });

  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
}

class GeolocatorLocationStreamService implements LocationStreamService {
  const GeolocatorLocationStreamService();

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: locationSettings ??
          const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
    );
  }

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  @override
  Future<LocationPermission> requestPermission() =>
      Geolocator.requestPermission();
}

class FakeLocationStreamService implements LocationStreamService {
  final Stream<Position> _stream;
  LocationPermission permission;
  bool serviceEnabled;

  FakeLocationStreamService({
    Stream<Position>? stream,
    this.permission = LocationPermission.always,
    this.serviceEnabled = true,
  }) : _stream = stream ?? const Stream<Position>.empty();

  @override
  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  }) {
    return _stream;
  }

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() async => permission;
}

final locationStreamServiceProvider = Provider<LocationStreamService>((ref) {
  return const GeolocatorLocationStreamService();
});
