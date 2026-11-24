import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_language.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_poppers.dart';
import '../../core/pixel/pixel_text.dart';
import '../celebrations/celebration.dart';
import '../dashboard/pixel/home_pixel_art.dart';
import '../quests/screens/qr_scan_screen.dart';
import 'models/suki_models.dart';
import 'providers/suki_provider.dart';
import 'suki_codes.dart';

/// A fresh GPS fix, the same way the quest host scan takes one.
Future<Position?> sukiPosition() async {
  try {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied ||
          requested == LocationPermission.deniedForever) {
        return null;
      }
    }
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
      timeLimit: const Duration(seconds: 12),
    );
  } catch (_) {
    return null;
  }
}

/// Plan 107 J2: scan the counter standee, take a GPS fix, record the visit.
/// Returns the result, or null when cancelled or refused (a dialog explains).
Future<SukiVisitResult?> scanSukiStandee(
  BuildContext context,
  WidgetRef ref, {
  Future<Position?> Function() getPosition = sukiPosition,
  Future<String?> Function(BuildContext context)? scan,
  bool celebrate = true,
}) async {
  final standee = await (scan ??
      (ctx) => Navigator.of(ctx).push<String>(
            MaterialPageRoute(
              builder: (c) => QrScanScreen(
                title: tr(c,
                    en: 'Scan the Suki Card QR', tl: 'I-scan ang Suki Card QR'),
                extract: extractSukiStandee,
                rejectedMessage: tr(c,
                    en: 'That is not a Suki Card QR.',
                    tl: 'Hindi ito Suki Card QR.'),
              ),
            ),
          ))(context);
  if (standee == null || !context.mounted) return null;
  final pos = await getPosition();
  if (!context.mounted) return null;
  if (pos == null) {
    await showSukiMessage(context,
        title: tr(context, en: 'Location needed', tl: 'Kailangan ang lokasyon'),
        message: tr(context,
            en: 'Turn on location: Suki visits are collected at the shop.',
            tl: 'I-on ang lokasyon: sa tindahan kinukuha ang Suki visit.'));
    return null;
  }
  try {
    final result = await ref.read(sukiApiProvider).recordVisit(
          standee: standee,
          lat: pos.latitude,
          lng: pos.longitude,
          accuracyM: pos.accuracy,
        );
    ref.invalidate(mySukiCardsProvider);
    ref.invalidate(sukiProgramProvider(result.program.id));
    if (celebrate && context.mounted) await celebrateSukiVisit(context, result);
    return result;
  } catch (error) {
    if (context.mounted) {
      await showSukiMessage(
        context,
        title: isSukiDisabled(error)
            ? tr(context, en: 'Suki Cards', tl: 'Suki Cards')
            : tr(context, en: 'Visit not recorded', tl: 'Hindi naitala'),
        message: sukiErrorText(context, error),
      );
    }
    return null;
  }
}

/// Plan 107 §7.2: the stamp-drop scene for a visit. A completed card adds
/// confetti and a reward dialog with "Show reward".
Future<void> celebrateSukiVisit(
  BuildContext context,
  SukiVisitResult result, {
  bool openRewardRoute = true,
}) async {
  final shop = result.program.merchant.name;
  final reward = result.rewardIssued;
  final caption = tr(context,
      en: 'Visit ${result.visitNumber} of ${result.card.required} at $shop',
      tl: 'Bisita ${result.visitNumber} sa ${result.card.required} sa $shop');
  await showCelebration(
    context,
    StampEarned(
      title: reward != null ? 'SUKI REWARD!' : 'SUKI VISIT!',
      stampName: caption,
      stamp: HomePixelArt.stampCheck,
      actionLabel: tr(context, en: 'Continue', tl: 'Tuloy'),
    ),
  );
  if (!context.mounted) return;
  if (result.pointsAwarded > 0) {
    showPixelToast(
      context,
      tr(context,
          en: '+${result.pointsAwarded} Suki Points earned!',
          tl: '+${result.pointsAwarded} Suki Points ang nakuha!'),
    );
  }
  for (final badge in result.badges) {
    showPixelToast(
        context,
        tr(context,
            en: 'New badge: ${_badgeName(badge)}',
            tl: 'Bagong badge: ${_badgeName(badge)}'));
  }
  if (reward == null) return;
  PixelPoppers.fire(context, size: PixelPopperSize.big);
  final show = await showPixelDialog<bool>(
    context: context,
    title: tr(context, en: 'Suki reward unlocked!', tl: 'May Suki reward ka!'),
    content: Text(
      tr(context,
          en: '${reward.rewardText} at $shop. Show the reward code at the counter.',
          tl: '${reward.rewardText} sa $shop. Ipakita ang code sa counter.'),
      key: const ValueKey('suki_reward_message'),
      textAlign: TextAlign.center,
      style: PixelType.body(context, color: PixelPalette.ink),
    ),
    actions: [
      PixelButton(
        key: const ValueKey('suki_show_reward'),
        label: tr(context, en: 'Show reward', tl: 'Ipakita ang reward'),
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
      ),
    ],
  );
  if (show == true && openRewardRoute && context.mounted) {
    context.push('/suki/${Uri.encodeComponent(result.program.id)}');
  }
}

String _badgeName(String id) => switch (id) {
      'suki_first_card' => 'Suki',
      'suki_three_shops' => 'Barangay Regular',
      'suki_three_towns' => 'Suki ng Bayan',
      _ => id,
    };

Future<void> showSukiMessage(BuildContext context,
    {required String title, required String message}) {
  return showPixelDialog<void>(
    context: context,
    title: title,
    content: Text(message,
        key: const ValueKey('suki_message'),
        textAlign: TextAlign.center,
        style: PixelType.body(context, color: PixelPalette.ink)),
    actions: [
      PixelButton(
        label: 'OK',
        onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
      ),
    ],
  );
}
