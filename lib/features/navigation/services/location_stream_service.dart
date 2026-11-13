import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

abstract class LocationStreamService {
  Duration get gpsAcquireTimeout => const Duration(seconds: 15);

  Stream<Position> getPositionStream({
    LocationSettings? locationSettings,
  });

  Future<Position?> getCurrentPosition({Duration? timeLimit});

  Future<bool> isLocationServiceEnabled();
  Future<LocationPermission> checkPermission();
  Future<LocationPermission> requestPermission();
}

class GeolocatorLocationStreamService implements LocationStreamService {
  const GeolocatorLocationStreamService();

  @override
  Duration get gpsAcquireTimeout => const Duration(seconds: 15);

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
  Future<Position?> getCurrentPosition({Duration? timeLimit}) async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.bestForNavigation,
        timeLimit: timeLimit ?? gpsAcquireTimeout,
      );
    } catch (_) {
      return null;
    }
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
  Position? currentFix;
  @override
  final Duration gpsAcquireTimeout;
  LocationPermission permission;
  bool serviceEnabled;

  FakeLocationStreamService({
    Stream<Position>? stream,
    this.currentFix,
    this.gpsAcquireTimeout = const Duration(seconds: 15),
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
  Future<Position?> getCurrentPosition({Duration? timeLimit}) async {
    if (currentFix != null) return currentFix;
    try {
      return await _stream.first.timeout(timeLimit ?? gpsAcquireTimeout);
    } catch (_) {
      return null;
    }
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
