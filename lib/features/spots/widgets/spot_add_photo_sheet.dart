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
class SpotAddPhotoSheet extends ConsumerStatefulWidget {
  const SpotAddPhotoSheet({
    super.key,
    required this.spot,
    this.pickPhotoOverride,
  });

  final SpotModel spot;
  final SpotPhotoPickerFn? pickPhotoOverride;

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

  PickedSpotPhoto? _photo;
  bool _picking = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    if (_picking || _submitting) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      PickedSpotPhoto? result;
      if (widget.pickPhotoOverride != null) {
        result = await widget.pickPhotoOverride!(source);
      } else {
        final file = await _picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1920,
          imageQuality: 85,
        );
        if (file != null) {
          result = PickedSpotPhoto(
            bytes: await file.readAsBytes(),
            filename: file.name,
          );
        }
      }
      if (!mounted) return;
      if (result == null) {
        setState(() => _picking = false);
        return;
      }
      if (result.bytes.lengthInBytes > _maxBytes) {
        setState(() {
          _picking = false;
          _error = 'Photo exceeds the 8 MB limit.';
        });
        return;
      }
      setState(() {
        _photo = result;
        _picking = false;
        _error = null;
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
    final photo = _photo;
    if (photo == null || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final dio = ref.read(apiClientProvider).dio;
      final formData = FormData.fromMap({
        'media': MultipartFile.fromBytes(
          photo.bytes,
          filename: photo.filename,
        ),
      });
      final uploadRes = await dio.post('/spot-media', data: formData);
      final uploadData = uploadRes.data is Map ? uploadRes.data['data'] : null;
      final assetId =
          uploadData is Map ? uploadData['asset_id'] as String? : null;
      if (assetId == null || assetId.isEmpty) {
        throw Exception('Upload did not return an asset id.');
      }

      final caption = _caption.text.trim();
      await dio.post(
        '/spots/${widget.spot.id}/photos',
        data: {
          'asset_id': assetId,
          if (caption.isNotEmpty) 'caption': caption,
        },
      );
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
                      onPressed:
                          _submitting ? null : () => _pick(ImageSource.camera),
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: PixelButton(
                      key: const ValueKey('spot_add_photo_gallery'),
                      label: 'GALLERY',
                      variant: PixelButtonVariant.secondary,
                      expand: true,
                      onPressed:
                          _submitting ? null : () => _pick(ImageSource.gallery),
                    ),
                  ),
                ],
              ),
              if (_photo != null) ...[
                SizedBox(height: grid.px(2)),
                PixelPanel(
                  style: PixelBoxStyle.stone,
                  padding: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 140,
                        child: Image.memory(
                          _photo!.bytes,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              _photo!.filename,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.paper,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: grid.px(1)),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _photo!.filename,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.paperDim,
                              ),
                            ),
                          ),
                          PixelButton(
                            key: const ValueKey('spot_add_photo_remove'),
                            label: 'REMOVE',
                            variant: PixelButtonVariant.ghost,
                            onPressed: _submitting
                                ? null
                                : () => setState(() => _photo = null),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                label: _submitting ? 'SENDING…' : 'SEND FOR REVIEW',
                variant: PixelButtonVariant.primary,
                expand: true,
                onPressed: (_photo == null || _submitting) ? null : _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
