import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../auth/providers/auth_provider.dart';

/// Another explorer's public id and picture (`GET /users/:handle/profile`).
class PublicAvatar {
  const PublicAvatar({required this.id, required this.avatarUrl});
  final String id;
  final String avatarUrl;
}

final publicAvatarProvider = FutureProvider.autoDispose
    .family<PublicAvatar?, String>((ref, handle) async {
  if (handle.isEmpty) return null;
  final res = await ref
      .watch(apiClientProvider)
      .dio
      .get('/users/${Uri.encodeComponent(handle)}/profile');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! Map) return null;
  return PublicAvatar(
    id: '${data['id'] ?? ''}',
    avatarUrl: '${data['avatar_url'] ?? ''}',
  );
});

/// Three dots for the profile's "more" menu.
const profileMoreIcon = PixelArt('profileMore', [
  '00.00.00.',
  '00.00.00.',
]);

/// v0.3.10 (owner): report another explorer's uploaded profile picture.
/// Reason, confirm, then POST `/users/:id/avatar/report` (409 = already sent).
Future<void> showReportAvatar(
    BuildContext context, WidgetRef ref, String userId) async {
  void close(String? v) => Navigator.of(context, rootNavigator: true).pop(v);
  final reasons = [
    ('inappropriate', tr(context, en: 'Inappropriate', tl: 'Hindi angkop')),
    (
      'impersonation',
      tr(context, en: 'Not a person / impersonation', tl: 'Nagpapanggap na iba')
    ),
    ('spam', tr(context, en: 'Spam', tl: 'Spam')),
    ('other', tr(context, en: 'Other', tl: 'Iba pa')),
  ];
  final reason = await showPixelDialog<String>(
    context: context,
    title: tr(context, en: 'Report picture', tl: 'I-report ang larawan'),
    message: tr(context,
        en: 'Why should a moderator look at this picture?',
        tl: 'Bakit dapat tingnan ng moderator ang larawang ito?'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (key, label) in reasons) ...[
          PixelButton(
            key: ValueKey('avatar_report_reason_$key'),
            label: label,
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => close(key),
          ),
          const SizedBox(height: 6),
        ],
      ],
    ),
    actions: [
      PixelButton(
        label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
        variant: PixelButtonVariant.ghost,
        onPressed: () => close(null),
      ),
    ],
  );
  if (reason == null || !context.mounted) return;
  final confirmed = await showPixelDialog<String>(
    context: context,
    title: tr(context, en: 'Send report?', tl: 'Ipadala ang report?'),
    message: tr(context,
        en: 'A moderator will review this picture.',
        tl: 'Susuriin ng moderator ang larawang ito.'),
    actions: [
      PixelButton(
        label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
        variant: PixelButtonVariant.ghost,
        onPressed: () => close(null),
      ),
      PixelButton(
        key: const ValueKey('avatar_report_confirm'),
        label: tr(context, en: 'Report', tl: 'I-report'),
        onPressed: () => close('yes'),
      ),
    ],
  );
  if (confirmed != 'yes' || !context.mounted) return;
  String message;
  try {
    await ref.read(apiClientProvider).dio.post(
        '/users/${Uri.encodeComponent(userId)}/avatar/report',
        data: {'reason': reason});
    if (!context.mounted) return;
    message = tr(context,
        en: 'Thanks. A moderator will take a look.',
        tl: 'Salamat. Titingnan ito ng moderator.');
  } on DioException catch (e) {
    if (!context.mounted) return;
    message = e.response?.statusCode == 409
        ? tr(context,
            en: 'You already reported this picture.',
            tl: 'Na-report mo na ang larawang ito.')
        : tr(context,
            en: 'Could not send the report. Try again.',
            tl: 'Hindi maipadala ang report. Subukan muli.');
  }
  if (context.mounted) showPixelToast(context, message);
}
