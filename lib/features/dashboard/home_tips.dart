import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/pixel/generated/designer_art.g.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';

const homeTipTexts = <String>[
  "HI, I'M JUAN! THIS CARD IS YOUR TRAVEL LOG. VISIT PLACES AND FINISH QUESTS TO LEVEL UP.",
  'TAP HERE TO FIND YOUR NEXT ADVENTURE: PLACES NEAR YOU, THE MAP, OR A QUEST.',
  'USE THIS BAR TO JUMP BETWEEN HOME, MAP, QUESTS, JUANCHOICE AND YOUR PROFILE.',
];

abstract interface class HomeTipsStore {
  Future<bool> seen();

  Future<void> markSeen();

  Future<void> reset();
}

class SecureHomeTipsStore implements HomeTipsStore {
  const SecureHomeTipsStore();

  static const _storage = FlutterSecureStorage();
  static const _key = 'pixel_home_tips_seen_v1';

  @override
  Future<bool> seen() async {
    try {
      return await _storage.read(key: _key) == 'true';
    } catch (_) {
      return true;
    }
  }

  @override
  Future<void> markSeen() async {
    try {
      await _storage.write(key: _key, value: 'true');
    } catch (_) {
      return;
    }
  }

  @override
  Future<void> reset() async {
    try {
      await _storage.delete(key: _key);
    } catch (_) {
      return;
    }
  }
}

final homeTipsStoreProvider = Provider<HomeTipsStore>(
  (ref) => const SecureHomeTipsStore(),
);

class HomeTipsKeys {
  final GlobalKey hero = GlobalKey();
  final GlobalKey nextStop = GlobalKey();
  final GlobalKey hotbar = GlobalKey();
}

final homeTipsKeysProvider = Provider<HomeTipsKeys>((ref) => HomeTipsKeys());

class HomeTipsState {
  const HomeTipsState({this.showing = false, this.step = 0});

  final bool showing;
  final int step;

  HomeTipsState copyWith({bool? showing, int? step}) => HomeTipsState(
        showing: showing ?? this.showing,
        step: step ?? this.step,
      );
}

class HomeTipsController extends StateNotifier<HomeTipsState> {
  HomeTipsController(this._store) : super(const HomeTipsState());

  final HomeTipsStore _store;
  bool _completed = false;
  bool _checking = false;

  Future<void> maybeStart() async {
    if (state.showing || _completed || _checking) return;
    _checking = true;
    final seen = await _store.seen();
    _checking = false;
    if (!mounted || seen) {
      if (seen) _completed = true;
      return;
    }
    state = const HomeTipsState(showing: true);
  }

  void next() {
    if (!state.showing) return;
    if (state.step >= homeTipTexts.length - 1) {
      finish();
      return;
    }
    state = state.copyWith(step: state.step + 1);
  }

  void skip() => finish();

  Future<void> finish() async {
    if (_completed) return;
    _completed = true;
    state = const HomeTipsState();
    await _store.markSeen();
  }

  Future<void> resetForReplay() async {
    _completed = false;
    state = const HomeTipsState();
    await _store.reset();
  }
}

final homeTipsControllerProvider =
    StateNotifierProvider<HomeTipsController, HomeTipsState>(
  (ref) => HomeTipsController(ref.watch(homeTipsStoreProvider)),
);

class PixelHomeTipsOverlay extends StatelessWidget {
  const PixelHomeTipsOverlay({
    super.key,
    required this.keys,
    required this.step,
    required this.onSkip,
    required this.onNext,
  });

  final HomeTipsKeys keys;
  final int step;
  final VoidCallback onSkip;
  final VoidCallback onNext;

  Rect? _rectFor(GlobalKey key) {
    final context = key.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final safeStep = step.clamp(0, homeTipTexts.length - 1).toInt();
    final text = homeTipTexts[safeStep];
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = Offset.zero & constraints.biggest;
        final hotbar = _rectFor(keys.hotbar);
        final rawTarget = switch (step) {
          0 => _rectFor(keys.hero),
          1 => _rectFor(keys.nextStop),
          _ => hotbar,
        };
        final target = rawTarget?.intersect(screen);
        final visibleTarget = target == null || target.isEmpty ? null : target;
        final bottom = hotbar == null
            ? grid.px(12)
            : (constraints.maxHeight - hotbar.top + grid.px(3))
                .clamp(grid.px(4), constraints.maxHeight)
                .toDouble();
        final above = hotbar == null
            ? constraints.maxHeight * 0.6
            : hotbar.top - MediaQuery.paddingOf(context).top - grid.px(8);
        final maxHeight =
            above > grid.px(40) ? above : constraints.maxHeight * 0.6;
        return Stack(
          children: [
            Positioned.fill(
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: CustomPaint(
                    painter: _SpotlightPainter(
                      target: visibleTarget,
                      unit: grid.unit,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: grid.px(3),
              right: grid.px(3),
              bottom: bottom,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        container: true,
                        liveRegion: true,
                        label: text,
                        child: ExcludeSemantics(
                          child: PixelDialogue(
                            key: ValueKey('home-tip-$safeStep'),
                            speaker: 'Juan',
                            lines: [text],
                            portrait: DesignerArt.juanIdle.frames.first,
                            animate: !reduceMotion,
                          ),
                        ),
                      ),
                      SizedBox(height: grid.px(2)),
                      PixelPanel(
                        style: PixelBoxStyle.parchment,
                        padding: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'TIP ${safeStep + 1} OF ${homeTipTexts.length}',
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            SizedBox(height: grid.px(2)),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: grid.px(2),
                              runSpacing: grid.px(2),
                              children: [
                                PixelButton(
                                  label: 'Skip',
                                  style: PixelBoxStyle.wood,
                                  textColor: PixelPalette.white,
                                  onPressed: onSkip,
                                ),
                                PixelButton(
                                  label: step >= homeTipTexts.length - 1
                                      ? 'Got it'
                                      : 'Next >',
                                  onPressed: onNext,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SpotlightPainter extends CustomPainter {
  _SpotlightPainter({required this.target, required this.unit});

  final Rect? target;
  final double unit;

  @override
  void paint(Canvas canvas, Size size) {
    final screen = Offset.zero & size;
    final dim = Paint()..color = PixelPalette.ink.withValues(alpha: 0.6);
    final spot = target;
    if (spot == null) {
      canvas.drawRect(screen, dim);
      return;
    }
    final path = Path.combine(
      PathOperation.difference,
      Path()..addRect(screen),
      Path()..addRect(spot),
    );
    canvas.drawPath(path, dim);
    final outline = Paint()
      ..color = PixelPalette.sun
      ..style = PaintingStyle.stroke
      ..strokeWidth = unit * 2
      ..isAntiAlias = false;
    canvas.drawRect(spot, outline);
  }

  @override
  bool shouldRepaint(_SpotlightPainter old) =>
      old.target != target || old.unit != unit;
}
