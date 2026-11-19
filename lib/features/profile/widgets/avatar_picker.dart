import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../auth/providers/auth_provider.dart';
import '../../cosmetics/widgets/cosmetic_avatar.dart';
import '../../spots/widgets/spot_add_photo_sheet.dart';

/// Picks a profile picture from the camera or gallery (tests override it).
typedef AvatarPhotoPicker = Future<PickedSpotPhoto?> Function(
    ImageSource source);

/// Square-ish 512 px JPEG: the avatar is drawn small and centre-cropped
/// (BoxFit.cover), so this keeps uploads around 100 KB.
final avatarPhotoPickerProvider = Provider<AvatarPhotoPicker>(
  (ref) => (source) async {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.front,
    );
    if (file == null) return null;
    return PickedSpotPhoto(
        bytes: await file.readAsBytes(), filename: file.name);
  },
);

/// v0.3.10 (team review): "add option to take or upload profile picture".
/// Take photo / Choose from gallery / Remove, then PUT or DELETE
/// `/users/me/avatar` and refresh the signed-in account.
Future<void> showAvatarOptions(BuildContext context, WidgetRef ref) async {
  final hasPhoto =
      resolveAvatarUrl(ref.read(authProvider).user?.avatarUrl) != null;
  void close(String? v) => Navigator.of(context, rootNavigator: true).pop(v);
  final choice = await showPixelDialog<String>(
    context: context,
    title: tr(context, en: 'Profile picture', tl: 'Larawan sa profile'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelButton(
          key: const ValueKey('avatar_take_photo'),
          label: tr(context, en: 'Take photo', tl: 'Kumuha ng litrato'),
          variant: PixelButtonVariant.secondary,
          expand: true,
          onPressed: () => close('camera'),
        ),
        const SizedBox(height: 6),
        PixelButton(
          key: const ValueKey('avatar_choose_photo'),
          label:
              tr(context, en: 'Choose from gallery', tl: 'Pumili sa gallery'),
          variant: PixelButtonVariant.secondary,
          expand: true,
          onPressed: () => close('gallery'),
        ),
        if (hasPhoto) ...[
          const SizedBox(height: 6),
          PixelButton(
            key: const ValueKey('avatar_remove_photo'),
            label: tr(context, en: 'Remove photo', tl: 'Alisin ang litrato'),
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => close('remove'),
          ),
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
  if (choice == null || !context.mounted) return;

  final dio = ref.read(apiClientProvider).dio;
  try {
    if (choice == 'remove') {
      await dio.delete('/users/me/avatar');
    } else {
      final picked = await ref.read(avatarPhotoPickerProvider)(
          choice == 'camera' ? ImageSource.camera : ImageSource.gallery);
      if (picked == null || !context.mounted) return;
      if (picked.bytes.lengthInBytes > 8 * 1024 * 1024) {
        showPixelToast(context,
            tr(context, en: 'Photo exceeds 8 MB.', tl: 'Lampas 8 MB.'));
        return;
      }
      await dio.put(
        '/users/me/avatar',
        data: FormData.fromMap({
          'photo':
              MultipartFile.fromBytes(picked.bytes, filename: picked.filename),
        }),
      );
    }
    await ref.read(authProvider.notifier).refreshProfile();
    if (context.mounted) {
      showPixelToast(
        context,
        choice == 'remove'
            ? tr(context, en: 'Photo removed.', tl: 'Naalis ang litrato.')
            : tr(context,
                en: 'Profile picture updated.', tl: 'Na-update ang larawan.'),
      );
    }
  } on DioException catch (e) {
    final body = e.response?.data;
    final err = body is Map ? body['error'] : null;
    final message = err is Map ? err['message']?.toString() : null;
    if (context.mounted) {
      showPixelToast(
          context,
          message ??
              tr(context,
                  en: 'Could not update your picture. Try again.',
                  tl: 'Hindi ma-update ang larawan. Subukan muli.'));
    }
  } catch (_) {
    if (context.mounted) {
      showPixelToast(
          context,
          tr(context,
              en: 'Could not open that photo.',
              tl: 'Hindi mabuksan ang litrato.'));
    }
  }
}
