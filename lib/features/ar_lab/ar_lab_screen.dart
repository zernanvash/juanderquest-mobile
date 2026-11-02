import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../ar_experience/core/ar_device.dart';
import '../ar_experience/core/geo_anchor.dart';
import '../ar_experience/core/world_ar.dart';
import '../ar_experience/engine/shapes_factory.dart';
import '../ar_experience/widgets/ar_overlay.dart';
import '../ar_experience/widgets/world_ar_view.dart';

/// A place in the real world the gem should spawn at.
class LabTarget {
  const LabTarget(this.label, this.lat, this.lng);
  final String label;
  final double lat;
  final double lng;
}

/// AR Lab (owner 2026-11-02: "create another build just for the AR so we can
/// polish then integrate that to the main app"). Spawns the gem at a real
/// latitude/longitude using ARCore world tracking + a calibrated compass
/// heading, and shows every number that decides where it lands.
class ArLabScreen extends StatefulWidget {
  const ArLabScreen({super.key});

  @override
  State<ArLabScreen> createState() => _ArLabScreenState();
}

class _ArLabScreenState extends State<ArLabScreen> {
  final ArDevice _device = ArDevice();
  final HeadingCalibration _cal = HeadingCalibration();
  final ValueNotifier<ArScreenObject?> _object = ValueNotifier(null);
  WorldArSession? _world;
  StreamSubscription<Position>? _gps;
  Position? _fix;
  LabTarget? _target;
  LabTarget? _saved;
  ({double x, double y, double z, bool onPlane})? _placed;
  String? _placedTarget;
  bool _permissionsOk = false;
  String? _error;
  DateTime _lastSample = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastUi = DateTime.fromMillisecondsSinceEpoch(0);
  final List<String> _log = [];

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
    _start();
  }

  Future<void> _start() async {
    final statuses = await [Permission.camera, Permission.locationWhenInUse].request();
    if (!statuses.values.every((s) => s.isGranted)) {
      setState(() => _error = 'Camera and location permission are needed.');
      return;
    }
    final ar = await WorldArSupport.check();
    if (ar != WorldArAvailability.installed) {
      setState(() => _error = 'ARCore is not available on this phone ($ar).');
      return;
    }
    _device.start();
    _gps = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 0),
    ).listen((p) => _fix = p, onError: (_) {});
    setState(() => _permissionsOk = true);
  }

  void _onViewCreated(int id) {
    final s = WorldArSession(id);
    s.frame.addListener(_onFrame);
    _world = s;
  }

  void _onFrame() {
    final frame = _world?.frame.value;
    if (frame == null || !mounted) return;
    final now = DateTime.now();
    if (frame.tracking) {
      // Heading link: compass bearing of the camera vs its yaw in ARCore space.
      final yaw = GeoAnchor.cameraYaw(frame.view!);
      final pose = _device.pose.value;
      final cam = pose.camera;
      if (yaw != null && pose.hasData && !pose.compassUnreliable && cam.elevation.abs() < 40 &&
          now.difference(_lastSample).inMilliseconds >= 150) {
        _cal.add(compassBearing: cam.bearing, arYaw: yaw);
        _lastSample = now;
      }
    }
    final screen = MediaQuery.sizeOf(context);
    final p = WorldProjection.project(frame, screen);
    _object.value = p == null
        ? null
        : ArScreenObject.from(
            p,
            WorldProjection.focalPx(frame, screen) * ArObjectLayer.objectSizeM / (p.depth <= 0 ? 1 : p.depth),
            WorldProjection.relativeDegrees(frame),
          );
    if (now.difference(_lastUi).inMilliseconds > 250) {
      _lastUi = now;
      setState(() {});
    }
  }

  void _note(String s) {
    _log.insert(0, '${TimeOfDay.now().format(context)}  $s');
    if (_log.length > 5) _log.removeLast();
  }

  LabTarget? _relative(String label, double bearing, double distance) {
    final f = _fix;
    if (f == null) return null;
    final a = bearing * math.pi / 180;
    final north = distance * math.cos(a), east = distance * math.sin(a);
    return LabTarget(
      label,
      f.latitude + north / 111320,
      f.longitude + east / (111320 * math.cos(f.latitude * math.pi / 180)),
    );
  }

  void _pick(LabTarget? t) {
    if (t == null) {
      setState(() => _note('No GPS fix yet.'));
      return;
    }
    setState(() {
      _target = t;
      _note('Target: ${t.label} (${t.lat.toStringAsFixed(6)}, ${t.lng.toStringAsFixed(6)})');
    });
  }

  Future<void> _place() async {
    final frame = _world?.frame.value;
    final f = _fix, t = _target, offset = _cal.offset;
    if (frame == null || !frame.tracking) return setState(() => _note('ARCore is not tracking yet: move the phone slowly.'));
    if (f == null) return setState(() => _note('No GPS fix yet.'));
    if (t == null) return setState(() => _note('Pick a target first.'));
    if (offset == null) return setState(() => _note('Compass not calibrated: look at the horizon and turn slowly.'));
    final enu = GeoAnchor.enuOffset(f.latitude, f.longitude, t.lat, t.lng);
    final polar = GeoAnchor.polar(enu.east, enu.north);
    final cam = GeoAnchor.cameraPosition(frame.view!);
    final local = GeoAnchor.localPoint(
      camX: cam.x, camZ: cam.z, bearing: polar.bearing, distance: polar.distance, headingOffset: offset);
    final placed = await _world?.placeAnchorAt(local.x, local.z);
    if (!mounted) return;
    setState(() {
      _placed = placed;
      _placedTarget = t.label;
      _note(placed == null
          ? 'Place failed (not tracking).'
          : 'Placed ${polar.distance.toStringAsFixed(1)} m @ ${polar.bearing.toStringAsFixed(0)}° '
              '(${placed.onPlane ? 'on a detected floor' : 'floor estimated'}), '
              'heading ±${_cal.spread.toStringAsFixed(0)}°, GPS ±${f.accuracy.toStringAsFixed(0)} m');
    });
  }

  Future<void> _clear() async {
    await _world?.clearAnchor();
    setState(() {
      _placed = null;
      _note('Cleared.');
    });
  }

  Future<void> _custom() async {
    final c = TextEditingController();
    final t = await showDialog<LabTarget>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Target coordinates'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '16.198, 119.987'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final parts = c.text.split(RegExp(r'[,\s]+')).where((s) => s.isNotEmpty).toList();
              final lat = parts.isNotEmpty ? double.tryParse(parts[0]) : null;
              final lng = parts.length > 1 ? double.tryParse(parts[1]) : null;
              Navigator.pop(ctx, lat != null && lng != null ? LabTarget('Custom', lat, lng) : null);
            },
            child: const Text('Use'),
          ),
        ],
      ),
    );
    if (t != null) _pick(t);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations(const []);
    _gps?.cancel();
    _world?.frame.removeListener(_onFrame);
    _world?.dispose();
    _device.dispose();
    _object.dispose();
    super.dispose();
  }

  String _readout() {
    final frame = _world?.frame.value;
    final pose = _device.pose.value;
    final f = _fix;
    final lines = <String>[];
    lines.add('ARCORE  ${frame?.state ?? '-'}'
        '${frame != null && !frame.tracking ? ' (${frame.reason})' : ''}  planes ${frame?.planes ?? 0}');
    lines.add(f == null
        ? 'GPS     waiting…'
        : 'GPS     ${f.latitude.toStringAsFixed(6)}, ${f.longitude.toStringAsFixed(6)}  ±${f.accuracy.toStringAsFixed(0)} m');
    lines.add(pose.hasData
        ? 'COMPASS ${pose.camera.bearing.toStringAsFixed(0)}°  ±${pose.headingAccuracyDeg?.toStringAsFixed(0) ?? '?'}°'
            '  mag ${pose.magneticStatus ?? '?'}${pose.compassUnreliable ? '  UNRELIABLE' : ''}'
        : 'COMPASS waiting…');
    final yaw = frame?.tracking == true ? GeoAnchor.cameraYaw(frame!.view!) : null;
    lines.add('HEADING offset ${_cal.offset?.toStringAsFixed(0) ?? '-'}°  ±${_cal.count < 2 ? '-' : _cal.spread.toStringAsFixed(0)}°'
        '  n=${_cal.count}  ${_cal.ready ? 'READY' : 'calibrating'}  arYaw ${yaw?.toStringAsFixed(0) ?? '-'}°');
    final t = _target;
    if (t != null && f != null) {
      final enu = GeoAnchor.enuOffset(f.latitude, f.longitude, t.lat, t.lng);
      final p = GeoAnchor.polar(enu.east, enu.north);
      lines.add('TARGET  ${t.label}: ${p.distance.toStringAsFixed(1)} m @ ${p.bearing.toStringAsFixed(0)}°');
    }
    final a = frame?.anchor, v = frame?.view;
    if (_placed != null && a != null && v != null) {
      final cam = GeoAnchor.cameraPosition(v);
      final d = math.sqrt(math.pow(a[12] - cam.x, 2) + math.pow(a[14] - cam.z, 2));
      final drift = math.sqrt(math.pow(a[12] - _placed!.x, 2) + math.pow(a[14] - _placed!.z, 2));
      lines.add('GEM     $_placedTarget: ${d.toStringAsFixed(1)} m from you'
          '  ${_placed!.onPlane ? 'on floor' : 'floor est.'}  moved ${(drift * 100).toStringAsFixed(0)} cm');
    }
    return lines.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))));
    }
    if (!_permissionsOk) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    const mono = TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.white, height: 1.35);
    final pose = _device.pose.value;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: WorldArView(onCreated: _onViewCreated)),
        ArObjectLayer(
          object: _object,
          mesh: ShapesFactory.createShape(ShapeType.gem, themeColor: const Color(0xFFFFB703)),
          color: const Color(0xFFFFB703),
          collectable: false,
          onTap: () {},
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              color: const Color(0xCC0D1B2A),
              width: double.infinity,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text('JDQ AR LAB · world-location spawn', style: mono.copyWith(color: const Color(0xFFFFB703))),
                const SizedBox(height: 4),
                Text(_readout(), style: mono),
                if (_log.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(_log.join('\n'), style: mono.copyWith(color: const Color(0xFFC1ECD4))),
                ],
              ]),
            ),
          ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              color: const Color(0xCC0D1B2A),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
                  for (final (label, b) in const [('N', 0.0), ('E', 90.0), ('S', 180.0), ('W', 270.0)])
                    ActionChip(label: Text('5 m $label'), onPressed: () => _pick(_relative('5 m $label', b, 5))),
                  ActionChip(
                    label: const Text('10 m ahead (phone)'),
                    onPressed: () => _pick(pose.hasData ? _relative('10 m ahead', pose.camera.bearing, 10) : null),
                  ),
                  ActionChip(
                    label: const Text('Save this spot'),
                    onPressed: () {
                      final f = _fix;
                      if (f == null) return;
                      setState(() {
                        _saved = LabTarget('Saved spot', f.latitude, f.longitude);
                        _note('Saved this spot. Walk away, then pick "Saved spot" and PLACE.');
                      });
                    },
                  ),
                  if (_saved != null) ActionChip(label: const Text('Saved spot'), onPressed: () => _pick(_saved)),
                  ActionChip(label: const Text('Lat, lng…'), onPressed: _custom),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _place,
                      child: Text(_cal.ready ? 'PLACE GEM AT TARGET' : 'PLACE (heading not ready)'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _clear, child: const Text('CLEAR')),
                ]),
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}
