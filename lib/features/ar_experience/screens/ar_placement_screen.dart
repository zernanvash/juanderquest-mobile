import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/ar_device.dart';
import '../core/geo_anchor.dart';
import '../core/world_ar.dart';
import '../widgets/world_ar_view.dart';

/// Where the creator put the object (Plan 76).
class ArPlacementResult {
  final double lat;
  final double lng;
  final double accuracyM;

  const ArPlacementResult(
      {required this.lat, required this.lng, required this.accuracyM});
}

/// GPS fixes from the last few seconds while the creator stands still,
/// averaged by accuracy.
class PlacementGps {
  static const window = Duration(seconds: 20);
  static const minFixes = 3;

  /// Live placement needs at least this GPS accuracy, in metres.
  static const maxAccuracyM = 8.0;

  final List<({double lat, double lng, double acc, DateTime at})> _fixes = [];

  void add(double lat, double lng, double acc, DateTime at) {
    _fixes.add((lat: lat, lng: lng, acc: acc.clamp(0.5, 100), at: at));
    _fixes.removeWhere((f) => at.difference(f.at) > window);
  }

  /// Best single-fix accuracy in the window, or null with too few fixes.
  double? get accuracy => _fixes.length < minFixes
      ? null
      : _fixes.map((f) => f.acc).reduce((a, b) => a < b ? a : b);

  bool get good => (accuracy ?? double.infinity) <= maxAccuracyM;

  /// Mean position, each fix weighted by 1/accuracy².
  ({double lat, double lng})? get position {
    if (_fixes.length < minFixes) return null;
    var w = 0.0, lat = 0.0, lng = 0.0;
    for (final f in _fixes) {
      final k = 1 / (f.acc * f.acc);
      w += k;
      lat += f.lat * k;
      lng += f.lng * k;
    }
    return (lat: lat / w, lng: lng / w);
  }
}

/// The creator stands at the spot and drops the object on the floor with the
/// camera. Returns an [ArPlacementResult], or null when cancelled.
class ArPlacementScreen extends StatefulWidget {
  final Color color;

  const ArPlacementScreen({super.key, this.color = const Color(0xFFFFB703)});

  @override
  State<ArPlacementScreen> createState() => _ArPlacementScreenState();
}

class _ArPlacementScreenState extends State<ArPlacementScreen> {
  final ArDevice _device = ArDevice();
  final HeadingCalibration _heading = HeadingCalibration();
  final PlacementGps _gps = PlacementGps();
  StreamSubscription<Position>? _gpsSub;
  WorldArSession? _world;
  DateTime _lastHeadingSample = DateTime.fromMillisecondsSinceEpoch(0);

  /// null while checking; otherwise why live placement can't run.
  String? _blocked;
  bool _ready = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    _start();
  }

  Future<void> _start() async {
    bool granted;
    try {
      final s =
          await [Permission.camera, Permission.locationWhenInUse].request();
      granted = s.values.every((p) => p.isGranted);
    } catch (_) {
      granted = false;
    }
    if (!granted) {
      _block('Live placement needs the camera and your location.');
      return;
    }
    if (await WorldArSupport.check() != WorldArAvailability.installed) {
      _block('This phone can\'t place objects live (it needs Google Play '
          'Services for AR).');
      return;
    }
    _device.start();
    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best, distanceFilter: 0),
    ).listen((p) {
      _gps.add(p.latitude, p.longitude, p.accuracy, DateTime.now());
      if (mounted) setState(() {});
    }, onError: (_) {});
    if (mounted) setState(() => _ready = true);
  }

  void _block(String why) {
    if (mounted) setState(() => _blocked = why);
  }

  void _onViewCreated(int id) {
    final session = WorldArSession(id);
    session.frame.addListener(_onFrame);
    session.setNativeObject(true, color: widget.color);
    _world = session;
  }

  void _onFrame() {
    final frame = _world?.frame.value;
    if (frame == null || !mounted) return;
    if (frame.error != null) {
      _block('The AR camera stopped: ${frame.error}');
      return;
    }
    final now = DateTime.now();
    final yaw = frame.tracking ? GeoAnchor.cameraYaw(frame.view!) : null;
    final pose = _device.pose.value;
    if (yaw != null &&
        pose.hasData &&
        !pose.compassUnreliable &&
        pose.camera.elevation.abs() < 40 &&
        now.difference(_lastHeadingSample).inMilliseconds >= 150) {
      _heading.add(compassBearing: pose.camera.bearing, arYaw: yaw);
      _lastHeadingSample = now;
    }
    setState(() {});
  }

  Future<void> _drop() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _world?.clearAnchor();
    await _world?.placeAnchor();
    if (mounted) setState(() => _busy = false);
  }

  void _save() {
    final frame = _world?.frame.value;
    final a = frame?.anchor;
    final gps = _gps.position;
    final offset = _heading.offset;
    if (frame == null ||
        !frame.tracking ||
        a == null ||
        gps == null ||
        offset == null) {
      return;
    }
    final cam = GeoAnchor.cameraPosition(frame.view!);
    final p = geoPointOf(
      lat: gps.lat,
      lng: gps.lng,
      camX: cam.x,
      camZ: cam.z,
      anchorX: a[12],
      anchorZ: a[14],
      headingOffset: offset,
    );
    Navigator.of(context).pop(
        ArPlacementResult(lat: p.lat, lng: p.lng, accuracyM: _gps.accuracy!));
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _world?.frame.removeListener(_onFrame);
    _world?.dispose();
    _device.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final frame = _world?.frame.value;
    final tracking = frame?.tracking ?? false;
    final placed = frame?.anchor != null;
    final canDrop = tracking && (frame?.planes ?? 0) > 0 && !_busy;
    final canSave = placed && tracking && _heading.ready && _gps.good;
    final acc = _gps.accuracy;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Place in AR')),
      body: _blocked != null
          ? _Blocked(message: _blocked!)
          : !_ready
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  children: [
                    Positioned.fill(
                        child: WorldArView(onCreated: _onViewCreated)),
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: SafeArea(
                        minimum: const EdgeInsets.all(16),
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  !tracking
                                      ? frame?.trackingHint ??
                                          'Move your phone slowly to scan the ground.'
                                      : !placed
                                          ? 'Stand where the object belongs, aim at the floor and tap DROP HERE.'
                                          : 'Is this the spot? Walk around it to check, then save.',
                                  key: const ValueKey('ar-place-hint'),
                                ),
                                const SizedBox(height: 8),
                                _Check(
                                  ok: _heading.ready,
                                  label: _heading.ready
                                      ? 'Direction locked'
                                      : 'Finding north: turn slowly left and right',
                                ),
                                _Check(
                                  ok: _gps.good,
                                  label: acc == null
                                      ? 'Waiting for GPS…'
                                      : _gps.good
                                          ? 'GPS ±${acc.round()} m'
                                          : 'GPS ±${acc.round()} m: step into the open, it needs ±${PlacementGps.maxAccuracyM.round()} m',
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        key: const ValueKey('ar-place-drop'),
                                        onPressed: canDrop ? _drop : null,
                                        child: Text(
                                            placed ? 'MOVE IT' : 'DROP HERE'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: FilledButton(
                                        key: const ValueKey('ar-place-save'),
                                        onPressed: canSave ? _save : null,
                                        child: const Text('SAVE SPOT'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _Check extends StatelessWidget {
  final bool ok;
  final String label;

  const _Check({required this.ok, required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 18, color: ok ? Colors.green : Colors.grey),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
          ],
        ),
      );
}

class _Blocked extends StatelessWidget {
  final String message;

  const _Blocked({required this.message});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 16),
              FilledButton(
                key: const ValueKey('ar-place-back'),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('BACK (USE THE MAP)'),
              ),
            ],
          ),
        ),
      );
}
