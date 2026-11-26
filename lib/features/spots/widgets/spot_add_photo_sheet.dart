import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';

class PickedSpotPhoto {
  const PickedSpotPhoto({
    required this.bytes,
    required this.filename,
  });

  final Uint8List bytes;
  final String filename;
}

typedef SpotPhotoPickerFn = Future<PickedSpotPhoto?> Function(
  ImageSource source,
);

/// Photo-only submission sheet for an existing destination (Plan 102).
/// Plan 124b: several photos per send (gallery multi-select), up to
/// [SpotAddPhotoSheet.maxPhotos], the server's pending limit per traveler and
/// destination. Each photo still goes through moderator review.
class SpotAddPhotoSheet extends ConsumerStatefulWidget {
  const SpotAddPhotoSheet({
    super.key,
    required this.spot,
    this.pickPhotoOverride,
  });

  final SpotModel spot;
  final SpotPhotoPickerFn? pickPhotoOverride;

  /// Matches the backend MAX_PENDING_PHOTOS_PER_USER_SPOT.
  static const int maxPhotos = 3;

  static Future<bool?> show(
    BuildContext context, {
    required SpotModel spot,
    SpotPhotoPickerFn? pickPhotoOverride,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotAddPhotoSheet(
        spot: spot,
        pickPhotoOverride: pickPhotoOverride,
      ),
    );
  }

  @override
  ConsumerState<SpotAddPhotoSheet> createState() => _SpotAddPhotoSheetState();
}

class _SpotAddPhotoSheetState extends ConsumerState<SpotAddPhotoSheet> {
  static const int _maxBytes = 8 * 1024 * 1024;
  final _picker = ImagePicker();
  final _caption = TextEditingController();

  final List<PickedSpotPhoto> _photos = [];
  bool _picking = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  int get _room => SpotAddPhotoSheet.maxPhotos - _photos.length;

  Future<void> _pick(ImageSource source) async {
    if (_picking || _submitting || _room <= 0) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = <PickedSpotPhoto>[];
      if (widget.pickPhotoOverride != null) {
        final one = await widget.pickPhotoOverride!(source);
        if (one != null) picked.add(one);
      } else {
        final List<XFile> files;
        if (source == ImageSource.gallery) {
          files = await _picker.pickMultiImage(
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
            limit: _room > 1 ? _room : null,
          );
        } else {
          final file = await _picker.pickImage(
            source: source,
            maxWidth: 1920,
            maxHeight: 1920,
            imageQuality: 85,
          );
          files = file == null ? const [] : [file];
        }
        for (final file in files) {
          picked.add(PickedSpotPhoto(
            bytes: await file.readAsBytes(),
            filename: file.name,
          ));
        }
      }
      if (!mounted) return;
      final tooBig =
          picked.where((p) => p.bytes.lengthInBytes > _maxBytes).length;
      final fits = picked
          .where((p) => p.bytes.lengthInBytes <= _maxBytes)
          .take(_room)
          .toList();
      final dropped = picked.length - tooBig - fits.length;
      setState(() {
        _photos.addAll(fits);
        _picking = false;
        _error = tooBig > 0
            ? 'Photo exceeds the 8 MB limit.'
            : dropped > 0
                ? 'Up to ${SpotAddPhotoSheet.maxPhotos} photos per send.'
                : null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _picking = false;
          _error = 'Could not open the selected photo.';
        });
      }
    }
  }

  Future<void> _submit() async {
    if (_photos.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    final dio = ref.read(apiClientProvider).dio;
    final caption = _caption.text.trim();
    try {
      // One at a time, so a failure leaves only the unsent photos in the list.
      while (_photos.isNotEmpty) {
        final photo = _photos.first;
        final formData = FormData.fromMap({
          'media': MultipartFile.fromBytes(
            photo.bytes,
            filename: photo.filename,
          ),
        });
        final uploadRes = await dio.post('/spot-media', data: formData);
        final uploadData =
            uploadRes.data is Map ? uploadRes.data['data'] : null;
        final assetId =
            uploadData is Map ? uploadData['asset_id'] as String? : null;
        if (assetId == null || assetId.isEmpty) {
          throw Exception('Upload did not return an asset id.');
        }
        await dio.post(
          '/spots/${widget.spot.id}/photos',
          data: {
            'asset_id': assetId,
            if (caption.isNotEmpty) 'caption': caption,
          },
        );
        if (!mounted) return;
        setState(() => _photos.removeAt(0));
      }
      if (mounted) Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final respData = e.response?.data;
      final errObj = respData is Map ? respData['error'] : null;
      final serverMsg = errObj is Map ? errObj['message'] : null;
      setState(() {
        _submitting = false;
        _error = serverMsg?.toString() ?? 'Could not upload photo. Try again.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = 'Could not upload photo. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Material(
      color: PixelPalette.ink,
      child: Padding(
        padding: EdgeInsets.only(
          left: grid.px(3),
          right: grid.px(3),
          top: grid.px(3),
          bottom: MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              grid.px(3),
        ),
        child: SingleChildScrollView(
          key: const ValueKey('spot_add_photo_sheet'),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: PixelSectionTitle(
                      'ADD PHOTO',
                      colors: PixelText3DColors.cream,
                    ),
                  ),
                  InkWell(
                    key: const ValueKey('spot_add_photo_close'),
                    onTap: () => Navigator.of(context).pop(false),
                    child: Container(
                      constraints:
                          const BoxConstraints(minWidth: 48, minHeight: 48),
                      alignment: Alignment.center,
                      child: Text(
                        '✕',
                        style:
                            PixelType.title(context, color: PixelPalette.paper),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: grid.px(0.5)),
              Text(
                widget.spot.name,
                style: PixelType.small(context, color: PixelPalette.mist),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                'Submitted photos go to LGU moderators for review before appearing here.',
                style: PixelType.body(context, color: PixelPalette.paperDim),
              ),
              SizedBox(height: grid.px(2)),
              Row(
                children: [
                  Expanded(
                    child: PixelButton(
                      key: const ValueKey('spot_add_photo_camera'),
                      label: 'CAMERA',
                      variant: PixelButtonVariant.secondary,
                      expand: true,
                      onPressed: (_submitting || _room <= 0)
                          ? null
                          : () => _pick(ImageSource.camera),
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: PixelButton(
                      key: const ValueKey('spot_add_photo_gallery'),
                      label: 'GALLERY',
                      variant: PixelButtonVariant.secondary,
                      expand: true,
                      onPressed: (_submitting || _room <= 0)
                          ? null
                          : () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              if (_photos.isNotEmpty) ...[
                SizedBox(height: grid.px(2)),
                Text(
                  '${_photos.length}/${SpotAddPhotoSheet.maxPhotos} photos',
                  key: const ValueKey('spot_add_photo_count'),
                  style: PixelType.small(context, color: PixelPalette.mist),
                ),
                for (var i = 0; i < _photos.length; i++) ...[
                  SizedBox(height: grid.px(1)),
                  PixelPanel(
                    key: ValueKey('spot_add_photo_tile_$i'),
                    style: PixelBoxStyle.stone,
                    padding: 1,
                    child: Row(
                      children: [
                        SizedBox(
                          width: 64,
                          height: 64,
                          child: Image.memory(
                            _photos[i].bytes,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const ColoredBox(color: PixelPalette.ink),
                          ),
                        ),
                        SizedBox(width: grid.px(1)),
                        Expanded(
                          child: Text(
                            _photos[i].filename,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PixelType.small(
                              context,
                              color: PixelPalette.paperDim,
                            ),
                          ),
                        ),
                        PixelButton(
                          key: ValueKey(i == 0
                              ? 'spot_add_photo_remove'
                              : 'spot_add_photo_remove_$i'),
                          label: 'REMOVE',
                          variant: PixelButtonVariant.ghost,
                          onPressed: _submitting
                              ? null
                              : () => setState(() => _photos.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ],
                SizedBox(height: grid.px(2)),
                TextField(
                  key: const ValueKey('spot_add_photo_caption'),
                  controller: _caption,
                  enabled: !_submitting,
                  maxLines: 2,
                  maxLength: 240,
                  style: PixelType.body(context, color: PixelPalette.paper),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: PixelPalette.ink,
                    contentPadding: EdgeInsets.all(grid.px(1.5)),
                    hintText: 'Optional caption (e.g. Morning tide view)',
                    hintStyle:
                        PixelType.body(context, color: PixelPalette.stone),
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide:
                          BorderSide(color: PixelPalette.stone, width: 2),
                    ),
                    enabledBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide:
                          BorderSide(color: PixelPalette.stone, width: 2),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderRadius: BorderRadius.zero,
                      borderSide:
                          BorderSide(color: PixelPalette.gold, width: 2),
                    ),
                    counterText: '',
                  ),
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: grid.px(1.5)),
                Text(
                  _error!,
                  style: PixelType.small(context, color: PixelPalette.red),
                ),
              ],
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('spot_add_photo_submit'),
                label: _submitting
                    ? 'SENDING…'
                    : _photos.length > 1
                        ? 'SEND ${_photos.length} FOR REVIEW'
                        : 'SEND FOR REVIEW',
                variant: PixelButtonVariant.primary,
                expand: true,
                onPressed: (_photos.isEmpty || _submitting) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
