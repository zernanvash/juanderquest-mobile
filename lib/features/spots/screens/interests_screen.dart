import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Same choices as the web onboarding (`/onboarding/interests`).
const travelInterests = <String, String>{
  'eat_drink': 'Food & coffee',
  'nature_outdoors': 'Nature',
  'culture_heritage': 'Culture',
  'activities_wellness': 'Sports & activities',
  'shopping_local': 'Local finds',
  'stay': 'Places to stay',
};

/// Decides whether to ask for interests after sign-in.
///
/// The server keeps preferences in memory and reports `pending` again after a
/// restart, so the device also remembers that this account already answered.
class InterestsPrompt {
  static const _storage = FlutterSecureStorage();
  static String _key(String userId) => 'jdq_interests_answered_$userId';

  static Future<bool> answeredOnDevice(String userId) async {
    try {
      return await _storage.read(key: _key(userId)) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAnswered(String userId) async {
    try {
      await _storage.write(key: _key(userId), value: 'true');
    } catch (_) {}
  }

  /// Opens the interests screen once if the account has never answered.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || await answeredOnDevice(userId)) return;
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/me/discovery-preferences');
      final data = res.data is Map ? res.data['data'] : null;
      final state = data is Map ? data['onboarding_state'] : null;
      if (state != 'pending') {
        await markAnswered(userId);
        return;
      }
    } catch (_) {
      return; // Never block the dashboard on this.
    }
    if (context.mounted) await context.push('/onboarding/interests');
  }
}

/// "What do you enjoy while traveling?" (Plan 47 B5).
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final Set<String> _selected = {};
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadCurrent);
  }

  Future<void> _loadCurrent() async {
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/me/discovery-preferences');
      final data = res.data is Map ? res.data['data'] : null;
      final cats = data is Map ? data['categories'] : null;
      if (cats is List && mounted) {
        setState(() => _selected.addAll(
            cats.whereType<String>().where(travelInterests.containsKey)));
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _finish(bool completed) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put('/me/discovery-preferences', data: {
        'categories': completed ? _selected.toList() : <String>[],
        'tags': <String>[],
        'occasions': <String>[],
        'price_levels': <int>[],
        'radius_km': 25,
        'onboarding_state': completed ? 'completed' : 'skipped',
      });
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) await InterestsPrompt.markAnswered(userId);
      if (!mounted) return;
      final nav = Navigator.of(context);
      if (nav.canPop()) {
        nav.pop(true);
      } else {
        context.go('/explore');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      showPixelToast(context, 'Could not save your interests. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Your Interests',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelPanel(
                          style: PixelBoxStyle.wood,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PERSONALIZE YOUR DISCOVERIES',
                                style: PixelType.small(
                                  context,
                                  color: PixelPalette.sun,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'What do you enjoy while traveling?',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'Choose any that fit. You can change these later in Settings.',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        if (!_loaded)
                          const Center(
                            child: PixelLoader(label: 'Loading interests'),
                          )
                        else
                          Wrap(
                            spacing: grid.px(1),
                            runSpacing: grid.px(1),
                            children: [
                              for (final entry in travelInterests.entries)
                                GestureDetector(
                                  key: ValueKey('interest_${entry.key}'),
                                  onTap: () {
                                    pixelTick(context);
                                    setState(() => _selected.contains(entry.key)
                                        ? _selected.remove(entry.key)
                                        : _selected.add(entry.key));
                                  },
                                  child: PixelPanel(
                                    style: _selected.contains(entry.key)
                                        ? PixelBoxStyle.green
                                        : PixelBoxStyle.parchment,
                                    padding: 1,
                                    child: Text(
                                      entry.value,
                                      style: PixelType.body(
                                        context,
                                        color: _selected.contains(entry.key)
                                            ? PixelPalette.white
                                            : PixelPalette.ink,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        SizedBox(height: grid.px(4)),
                        PixelButton(
                          key: const ValueKey('interests_save'),
                          label: 'Save my interests',
                          expand: true,
                          loading: _saving,
                          onPressed: _saving || _selected.isEmpty
                              ? null
                              : () => _finish(true),
                        ),
                        SizedBox(height: grid.px(2)),
                        PixelButton(
                          key: const ValueKey('interests_skip'),
                          label: 'Skip for now',
                          variant: PixelButtonVariant.secondary,
                          expand: true,
                          onPressed: _saving ? null : () => _finish(false),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
