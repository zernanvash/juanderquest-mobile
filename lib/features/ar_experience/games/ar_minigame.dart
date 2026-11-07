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

/// How the player throws: hold-and-release, tap, swipe up (Ring Shoot), or
/// pull the bow string back (Pana).
enum ArButtonMode { hold, tap, swipe, pull }

enum ArHaptic { none, light, heavy }

/// A bar under the HUD: [value] 0..1 and an optional green zone.
typedef ArMeter = ({double value, double? from, double? to});

/// A bow sight (Pana): how far the string is drawn, whether an arrow is nocked,
/// seconds since the last release (recoil), where the arrow will land relative
/// to the sight ([pinRightDeg], [pinDownDeg]), the wind (-2..2) and whether the
/// sight is on the target.
typedef ArSight = ({
  double draw,
  bool loaded,
  double sinceRelease,
  double pinRightDeg,
  double pinDownDeg,
  int wind,
  bool onTarget,
});

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
///
/// Fair play (owner 2026-11-07): the player marks where they stand and the target
/// appears [standDistance] metres straight ahead, so everyone plays from the same
/// distance. [stand] is that spot (on the floor, relative to the target); a throw
/// only counts from within [lineReach] of it.
abstract class ArMiniGame {
  ArMiniGame({this.rangeScale = 1});

  /// 1 = real distances; less for testing indoors.
  final double rangeScale;

  /// Where the player stands, relative to the target (y = 0). Set before [place].
  V3 stand = const V3(0, 0, 5);

  /// How far you may drift from the line: a little towards the target (so the
  /// distance stays the same for everyone), more sideways and backwards.
  static const lineForward = 0.25;
  static const lineReach = 1.0;

  String get title;

  /// Metres from the line to the target at full range.
  double get fullDistance;
  double get standDistance => fullDistance * rangeScale;
  String get placeHint;

  /// Short summary on the end panel.
  String get endText;
  int get targetHits;
  int get hits;
  bool get placed;

  /// The session is over (won, or out of throws).
  bool get over;

  /// Reached the goal (the quest task would pass).
  bool get passed;
  ArButtonMode get buttonMode;

  /// Screen goes dark (Palayok piring).
  bool blind(double now) => false;

  /// A bow sight instead of the aim circle (Pana); null for other games.
  ArSight? sight(double now, ArPose? pose) => null;

  /// Close enough to the chalk line to throw (and not stepped over it).
  bool onLine(ArPose pose) {
    final off = V3(pose.camera.x, 0, pose.camera.z) - stand;
    return off.dot(downrange) <= lineForward && off.horizontalLength <= lineReach;
  }

  /// Unit horizontal direction from the line to the target.
  V3 get downrange => V3(-stand.x, 0, -stand.z).unit;

  /// Unit horizontal direction to the player's right as they face the target.
  V3 get across => rightOf(downrange);

  /// The chalk line at the player's feet.
  ArSprite get lineSprite => ArSprite('chalk_line', x: stand.x, y: 0, z: stand.z, floor: true);

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

  /// Swipe up to throw; [sideDeg] is how far the swipe leaned from straight up.
  void swipe(double now, ArPose? pose, double sideDeg) {}

  /// Bow string pulled back by [amount] (0..1) while held.
  void pull(double now, double amount) {}
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
