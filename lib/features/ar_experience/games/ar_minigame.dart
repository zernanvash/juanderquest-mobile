import 'dart:math' as math;

import 'ar_sprites.dart';
import 'tumbang_preso.dart';

/// Shared shell for the Plan 77 AR mini-games after Tumbang Preso (owner
/// 2026-11-06: "build the mini games altogether then we check it all at the
/// same time"). A game is pure logic: the screen feeds it the time and the
/// camera pose and drains what it wants drawn, said and felt.
///
/// Coordinates: metres relative to the game's anchor (world axes, y up from the
/// anchor's floor point), as in [TumbangPresoGame].

/// Camera position and unit view direction, relative to the anchor.
class ArPose {
  const ArPose(this.camera, this.forward);
  final V3 camera;
  final V3 forward;
}

enum ArButtonMode { hold, tap }

enum ArHaptic { none, light, heavy }

/// A bar under the HUD: [value] 0..1 and an optional green zone.
typedef ArMeter = ({double value, double? from, double? to});

extension V3Math on V3 {
  double dot(V3 o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(x * x + y * y + z * z);
  V3 get unit {
    final l = length;
    return l < 1e-9 ? const V3(0, 0, -1) : this * (1 / l);
  }
}

/// Degrees between two directions.
double angleDeg(V3 a, V3 b) {
  final c = (a.unit.dot(b.unit)).clamp(-1.0, 1.0);
  return math.acos(c) * 180 / math.pi;
}

/// Camera right on the ground plane for a view direction (what the native
/// renderer turns upright sprites towards).
V3 rightOf(V3 forward) {
  final r = V3(-forward.z, 0, forward.x);
  final l = r.horizontalLength;
  return l < 1e-6 ? const V3(1, 0, 0) : r * (1 / l);
}

/// Seconds of flight from height [y0] with upward speed [vy] until height [y1]
/// on the way down, under gravity [g]; null if it never gets that low/high.
double? timeToFallTo(double y0, double vy, double g, double y1) {
  final d = vy * vy + 2 * g * (y0 - y1);
  if (d < 0) return null;
  return (vy + math.sqrt(d)) / g;
}

/// True when [point] is inside the aim circle: within [coneDeg] of the view
/// direction, widened by the angular size of a [radius]-metre target.
bool inReticle(ArPose pose, V3 point, {required double radius, required double coneDeg}) {
  final to = point - pose.camera;
  final d = to.length;
  if (d < 1e-6) return true;
  final size = math.atan(radius / d) * 180 / math.pi;
  return angleDeg(pose.forward, to) <= coneDeg + size;
}

/// Turn hint toward [point] when it is far off to the side, else null.
String? turnHint(ArPose? pose, V3 point, {double beyondDeg = 30}) {
  if (pose == null) return null;
  final to = point - pose.camera;
  final a = math.atan2(pose.forward.x, -pose.forward.z);
  final c = math.atan2(to.x, -to.z);
  var d = (c - a) * 180 / math.pi;
  while (d > 180) {
    d -= 360;
  }
  while (d < -180) {
    d += 360;
  }
  if (d.abs() <= beyondDeg) return null;
  return d < 0 ? '◀ TURN LEFT' : 'TURN RIGHT ▶';
}

/// A sine swing with a [period]; [phaseAt] gives what the native renderer
/// needs to continue it in a new scene.
class Swing {
  Swing(this.period, this.epoch);
  double period;
  double epoch;

  double angle(double now) => 2 * math.pi * (now - epoch) / period;
  double sinAt(double now) => math.sin(angle(now));
  double phaseAt(double now) => angle(now) % (2 * math.pi);

  /// Changes speed without a jump.
  void retime(double now, double newPeriod) {
    final a = angle(now);
    period = newPeriod;
    epoch = now - a * newPeriod / (2 * math.pi);
  }
}

/// One game in the AR Lab. Subclasses set state and use [show], [say] and
/// [buzz]; the screen drains them with [takeScene], [takeCallout], [takeHaptic].
abstract class ArMiniGame {
  String get title;
  String get placeLabel;
  String get placeHint;
  String get wonText;
  int get targetHits;
  int get hits;
  bool get placed;
  bool get won;
  ArButtonMode get buttonMode;

  /// Whether the big button works right now.
  bool canPress(double now);
  String buttonLabel(double now);
  ArMeter? meter(double now, ArPose? pose);
  String? meterCaption(double now, ArPose? pose);

  /// null = no aim circle; true = on target.
  bool? reticle(double now, ArPose? pose);
  String? status(ArPose? pose);
  String? hint(double now, ArPose? pose);

  void place(double now, ArPose? pose);
  void unplace();
  void restart(double now, ArPose? pose);
  void press(double now, ArPose? pose);
  void release(double now, ArPose? pose) {}
  void update(double now, ArPose? pose);

  List<ArSprite>? _scene;
  String? _callout;
  ArHaptic _haptic = ArHaptic.none;

  void show(List<ArSprite> scene) => _scene = scene;
  void say(String text) => _callout = text;
  void buzz(ArHaptic h) {
    if (h.index > _haptic.index) _haptic = h;
  }

  List<ArSprite>? takeScene() {
    final s = _scene;
    _scene = null;
    return s;
  }

  String? takeCallout() {
    final c = _callout;
    _callout = null;
    return c;
  }

  ArHaptic takeHaptic() {
    final h = _haptic;
    _haptic = ArHaptic.none;
    return h;
  }

  /// Horizontal distance from the camera to the anchor.
  static double? distance(ArPose? pose) => pose?.camera.horizontalLength;
}
