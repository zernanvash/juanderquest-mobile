import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/app_language.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_text.dart';
import '../auth/providers/auth_provider.dart';
import '../navigation/services/location_stream_service.dart';

/// Home town (Plan 100 WP-7): derived automatically from GPS sightings
/// (most distinct days in the last 30 days, min 5), with an opt-out switch
/// in Settings to pick a town manually.
class HomeTownInfo {
  final String? town;
  final String? source;
  final bool gpsEnabled;
  final int currentDays;
  final int requiredDays;
  final String? leadingTown;
  final List<String> options;

  const HomeTownInfo({
    required this.town,
    this.source,
    this.gpsEnabled = true,
    this.currentDays = 0,
    this.requiredDays = 5,
    this.leadingTown,
    required this.options,
  });

  factory HomeTownInfo.fromJson(Map<String, dynamic> data) {
    final progress = data['days_progress'];
    return HomeTownInfo(
      town: data['home_municipality'] as String?,
      source: data['home_town_source'] as String?,
      gpsEnabled: data['home_town_gps'] as bool? ?? true,
      currentDays: progress is Map
          ? (progress['current_days'] as num?)?.toInt() ?? 0
          : 0,
      requiredDays: progress is Map
          ? (progress['required_days'] as num?)?.toInt() ?? 5
          : 5,
      leadingTown: progress is Map ? progress['leading_town'] as String? : null,
      options: List<String>.from(data['options'] as List? ?? const []),
    );
  }
}

final homeTownProvider = FutureProvider<HomeTownInfo>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) {
    return const HomeTownInfo(town: null, options: []);
  }
  final api = ref.watch(apiClientProvider);
  final res = await api.dio.get('/me/home-town');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is Map<String, dynamic>) {
    return HomeTownInfo.fromJson(data);
  }
  if (data is Map) {
    return HomeTownInfo.fromJson(Map<String, dynamic>.from(data));
  }
  return const HomeTownInfo(town: null, options: []);
});

class HomeTownSightingThrottle {
  DateTime? lastAttempt;
  static const interval = Duration(minutes: 30);

  bool shouldSend(DateTime now) {
    final prev = lastAttempt;
    if (prev != null && now.difference(prev) < interval) {
      return false;
    }
    return true;
  }

  void markSent(DateTime now) {
    lastAttempt = now;
  }

  void reset() {
    lastAttempt = null;
  }
}

final homeTownSightingThrottleProvider =
    Provider<HomeTownSightingThrottle>((ref) => HomeTownSightingThrottle());

/// Sends at most one GPS sighting every 30 minutes while the app is open
/// and the user has `home_town_gps` enabled. Never runs in the background.
final homeTownSightingProvider = FutureProvider<void>((ref) async {
  final auth = ref.watch(authProvider);
  if (!auth.isAuthenticated) return;
  final info = await ref.watch(homeTownProvider.future);
  if (!info.gpsEnabled) return;

  final throttle = ref.read(homeTownSightingThrottleProvider);
  final now = DateTime.now();
  if (!throttle.shouldSend(now)) return;

  final locationService = ref.read(locationStreamServiceProvider);
  try {
    if (!await locationService.isLocationServiceEnabled()) return;
    final perm = await locationService.checkPermission();
    final hasPerm = perm.name == 'whileInUse' || perm.name == 'always';
    if (!hasPerm) return;
    final pos = await locationService.getCurrentPosition(
      timeLimit: const Duration(seconds: 6),
    );
    if (pos == null) return;
    throttle.markSent(now);
    final res = await ref.read(apiClientProvider).dio.post(
      '/me/home-town/sighting',
      data: {
        'lat': pos.latitude,
        'lng': pos.longitude,
        'accuracy': pos.accuracy,
        'is_mocked': pos.isMocked,
      },
    );
    final body = res.data;
    final data = body is Map ? body['data'] : null;
    if (data is Map && data['accepted'] == true) {
      ref.invalidate(homeTownProvider);
    }
  } catch (_) {
    // Non-blocking best-effort sighting; retry after cooldown.
  }
});

/// Opens the Home town settings dialog; returns true when saved.
Future<bool> showHomeTownPicker(BuildContext context, WidgetRef ref) async {
  HomeTownInfo info;
  ref.invalidate(homeTownProvider);
  try {
    info = await ref.read(homeTownProvider.future);
  } catch (_) {
    if (context.mounted) {
      showPixelToast(
        context,
        tr(
          context,
          en: 'Could not load the towns. Try again.',
          tl: 'Hindi ma-load ang mga bayan. Subukan muli.',
        ),
      );
    }
    return false;
  }
  if (!context.mounted) return false;

  var gpsEnabled = info.gpsEnabled;
  var currentTown = info.town;
  var currentSource = info.source;
  var currentDays = info.currentDays;
  final requiredDays = info.requiredDays;
  var savingGps = false;

  final picked = await showPixelDialog<String>(
    context: context,
    title: tr(context, en: 'Your home town', tl: 'Iyong sariling bayan'),
    message: tr(
      context,
      en: 'My Town ranks you with explorers from the same town, wherever you travel.',
      tl: 'Pinagsasama ka ng My Town sa mga explorer mula sa parehong bayan.',
    ),
    content: StatefulBuilder(
      builder: (ctx, setModalState) {
        final town = currentTown;
        final statusText = town != null
            ? (currentSource == 'gps'
                ? tr(ctx, en: '$town · from GPS', tl: '$town · mula sa GPS')
                : town)
            : (gpsEnabled
                ? tr(ctx,
                    en: 'finding… ($currentDays/$requiredDays days)',
                    tl: 'hinahanap… ($currentDays/$requiredDays araw)')
                : tr(ctx, en: 'Not set', tl: 'Hindi nakatakda'));

        // QA 2026-11-17: one short line, so the towns stay in view.
        final explanation = gpsEnabled
            ? tr(
                ctx,
                en: 'Set from the town you are in on 5 of the last 30 days. Turn off to pick.',
                tl: 'Mula sa bayang kinaroroonan mo sa 5 sa huling 30 araw. I-off para pumili.',
              )
            : tr(
                ctx,
                en: 'Pick your home town, or Visiting.',
                tl: 'Piliin ang iyong bayan, o Bumisita.',
              );

        return SizedBox(
          height: math.min(380, MediaQuery.sizeOf(ctx).height * 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tr(
                        ctx,
                        en: 'Set my home town from GPS',
                        tl: 'Itakda ang sariling bayan gamit ang GPS',
                      ),
                      style: PixelType.body(ctx, color: PixelPalette.ink),
                    ),
                  ),
                  Switch(
                    key: const ValueKey('home_town_gps_switch'),
                    value: gpsEnabled,
                    onChanged: savingGps
                        ? null
                        : (next) async {
                            setModalState(() => savingGps = true);
                            try {
                              final res = await ref
                                  .read(apiClientProvider)
                                  .dio
                                  .put('/me/home-town/gps',
                                      data: {'enabled': next});
                              final body = res.data;
                              final data = body is Map ? body['data'] : null;
                              if (data is Map<String, dynamic>) {
                                final updated = HomeTownInfo.fromJson(data);
                                setModalState(() {
                                  gpsEnabled = updated.gpsEnabled;
                                  currentTown = updated.town;
                                  currentSource = updated.source;
                                  currentDays = updated.currentDays;
                                });
                              } else {
                                setModalState(() => gpsEnabled = next);
                              }
                              ref.invalidate(homeTownProvider);
                            } catch (_) {
                              if (ctx.mounted) {
                                showPixelToast(
                                  ctx,
                                  tr(
                                    ctx,
                                    en: 'Could not update GPS setting.',
                                    tl: 'Hindi ma-update ang GPS setting.',
                                  ),
                                );
                              }
                            } finally {
                              if (ctx.mounted) {
                                setModalState(() => savingGps = false);
                              }
                            }
                          },
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                statusText,
                key: const ValueKey('home_town_status_text'),
                style: PixelType.small(ctx, color: PixelPalette.greenDeep)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              // QA 2026-11-17: the explanation scrolls with the towns, so
              // the list never gets squeezed out of the fixed-height sheet.
              Expanded(
                child: ListView(
                  key: const ValueKey('home_town_list'),
                  children: [
                    Text(
                      explanation,
                      style: PixelType.small(ctx, color: PixelPalette.slate),
                    ),
                    const SizedBox(height: 8),
                    for (final t in ['', ...info.options])
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: PixelButton(
                          key: ValueKey('home_town_${t.isEmpty ? 'none' : t}'),
                          label: (t.isEmpty
                                  ? tr(
                                      ctx,
                                      en: "I'm visiting / not from Pangasinan",
                                      tl: 'Bumisita lang / hindi taga-Pangasinan',
                                    )
                                  : t) +
                              ((t.isEmpty
                                      ? currentTown == null
                                      : t == currentTown)
                                  ? ' *'
                                  : ''),
                          variant: (t.isEmpty
                                  ? currentTown == null
                                  : t == currentTown)
                              ? PixelButtonVariant.primary
                              : PixelButtonVariant.secondary,
                          expand: true,
                          onPressed: gpsEnabled
                              ? null
                              : () =>
                                  Navigator.of(ctx, rootNavigator: true).pop(t),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
    actions: [
      PixelButton(
        label: tr(context, en: 'Close', tl: 'Isara'),
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
    if (context.mounted) {
      showPixelToast(
        context,
        tr(
          context,
          en: 'Could not save your home town. Try again.',
          tl: 'Hindi nai-save ang sariling bayan. Subukan muli.',
        ),
      );
    }
    return false;
  }
  ref.invalidate(homeTownProvider);
  return true;
}
