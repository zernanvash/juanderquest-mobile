import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../auth/providers/auth_provider.dart';

/// Home town (owner 2026-11-08): the town the traveler says they are from.
/// It decides the My Town board; travelers do most quests away from home, so
/// it is never guessed from where they played.
class HomeTownInfo {
  final String? town;
  final List<String> options;
  const HomeTownInfo({required this.town, required this.options});
}

// Not autoDispose so the picker can read it on tap; the picker refreshes it
// each time it opens (another account may have signed in since).
final homeTownProvider = FutureProvider<HomeTownInfo>((ref) async {
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/me/home-town');
  final data = res.data is Map ? res.data['data'] : null;
  return HomeTownInfo(
    town: data is Map ? data['home_municipality'] as String? : null,
    options: data is Map
        ? List<String>.from(data['options'] as List? ?? const [])
        : const [],
  );
});

/// Opens the picker; returns true when the traveler saved a choice.
Future<bool> showHomeTownPicker(BuildContext context, WidgetRef ref) async {
  final HomeTownInfo info;
  ref.invalidate(homeTownProvider);
  try {
    info = await ref.read(homeTownProvider.future);
  } catch (_) {
    if (context.mounted)
      showPixelToast(context, 'Could not load the towns. Try again.');
    return false;
  }
  if (!context.mounted) return false;
  // '' = "I'm visiting / not from Pangasinan".
  final picked = await showPixelDialog<String>(
    context: context,
    title: 'Your home town',
    message:
        'My Town ranks you with explorers from the same town, wherever you travel.',
    content: SizedBox(
      height: math.min(360, MediaQuery.sizeOf(context).height * 0.45),
      child: ListView(
        key: const ValueKey('home_town_list'),
        children: [
          for (final t in ['', ...info.options])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: PixelButton(
                key: ValueKey('home_town_${t.isEmpty ? 'none' : t}'),
                label: (t.isEmpty ? "I'm visiting / not from Pangasinan" : t) +
                    ((t.isEmpty ? info.town == null : t == info.town)
                        ? ' *'
                        : ''),
                variant: (t.isEmpty ? info.town == null : t == info.town)
                    ? PixelButtonVariant.primary
                    : PixelButtonVariant.secondary,
                expand: true,
                onPressed: () =>
                    Navigator.of(context, rootNavigator: true).pop(t),
              ),
            ),
        ],
      ),
    ),
    actions: [
      PixelButton(
        label: 'Close',
        variant: PixelButtonVariant.secondary,
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
  if (picked == null) return false;
  try {
    await ref.read(apiClientProvider).dio.put('/me/home-town',
        data: {'municipality': picked.isEmpty ? null : picked});
  } catch (_) {
    if (context.mounted)
      showPixelToast(context, 'Could not save your home town. Try again.');
    return false;
  }
  ref.invalidate(homeTownProvider);
  return true;
}
