import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../providers/spot_recognition_provider.dart';
import '../studio/pixel/studio_icons.dart';
import '../studio/pixel/studio_text.dart';
import '../utils/spot_posting.dart';

const Duration kRecognizeDebounce = Duration(milliseconds: 450);

/// Plan 66 stage 1: a center pin over the map. Ignores touches so the map pans under it.
class PinReticle extends StatelessWidget {
  const PinReticle({super.key});

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Center(
        child: Padding(
          // Lift the pin so its tip, not its middle, marks the map center.
          padding: EdgeInsets.only(bottom: 40),
          child: PixelSprite(StudioIcons.pin, scale: 3),
        ),
      ),
    );
  }
}

/// Live "recognized place" card: what the crosshair is over, before the composer opens.
class PinAimCard extends ConsumerStatefulWidget {
  final double? lat;
  final double? lng;
  final void Function(
      double lat, double lng, SpotRecognitionResult? recognition) onContinue;
  final VoidCallback onUseMyLocation;
  final VoidCallback onCancel;
  final bool locating;

  const PinAimCard({
    super.key,
    required this.lat,
    required this.lng,
    required this.onContinue,
    required this.onUseMyLocation,
    required this.onCancel,
    this.locating = false,
  });

  @override
  ConsumerState<PinAimCard> createState() => _PinAimCardState();
}

class _PinAimCardState extends ConsumerState<PinAimCard> {
  Timer? _debounce;
  SpotRecognitionResult? _result;
  String _resultKey = '';
  int _request = 0;

  String get _key => widget.lat == null || widget.lng == null
      ? ''
      : '${widget.lat!.toStringAsFixed(5)},${widget.lng!.toStringAsFixed(5)}';

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PinAimCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lat != widget.lat || oldWidget.lng != widget.lng) _schedule();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    final lat = widget.lat;
    final lng = widget.lng;
    if (lat == null || lng == null) return;
    final key = _key;
    _debounce = Timer(kRecognizeDebounce, () async {
      final request = ++_request;
      final result = await ref
          .read(spotRecognitionApiProvider)
          .recognizeLocation(lat: lat, lng: lng);
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _resultKey = key;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final current = _resultKey == _key ? _result : null;
    final duplicate = current?.nearbyDuplicates.isNotEmpty == true
        ? current!.nearbyDuplicates.first
        : null;
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Move the map to aim the pin',
                  style: PixelType.small(
                    context,
                    color: PixelPalette.goldDeep,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              SizedBox(width: grid.px(1)),
              PixelIconButton(
                icon: StudioIcons.close,
                semanticLabel: 'Cancel adding a spot',
                iconHeight: 16,
                onPressed: widget.onCancel,
              ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          if (current == null)
            Row(
              children: [
                const PixelLoader(artPx: 4),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Text(
                    'Recognizing this place',
                    style: PixelType.small(
                      context,
                      color: PixelPalette.slate,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            Text(
              current.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: PixelType.title(context),
            ),
            if (current.formattedAddress.isNotEmpty)
              Text(
                current.formattedAddress,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            SizedBox(height: grid.px(1)),
            PixelChip(
              '${studioCategoryName(current.suggestedCategory)} · ${studioSubcategoryName(current.suggestedSubcategory)}',
              style: PixelBoxStyle.slot,
              textColor: PixelPalette.greenDark,
            ),
            if (current.outsidePangasinan) ...[
              SizedBox(height: grid.px(1)),
              Text(
                'Outside Pangasinan; double-check the pin.',
                style: PixelType.small(
                  context,
                  color: PixelPalette.goldDeep,
                ),
              ),
            ],
          ],
          if (duplicate != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Looks close to ${duplicate.name} (${duplicate.distanceMeters} m away). Continue only if it is a different place.',
              style: PixelType.small(context, color: PixelPalette.goldDeep),
            ),
          ],
          SizedBox(height: grid.px(2)),
          Row(
            children: [
              Expanded(
                child: PixelButton(
                  label: 'Use my GPS',
                  variant: PixelButtonVariant.secondary,
                  loading: widget.locating,
                  onPressed: widget.locating ? null : widget.onUseMyLocation,
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: PixelButton(
                  label: 'Continue',
                  onPressed: widget.lat == null || widget.lng == null
                      ? null
                      : () => widget.onContinue(
                            widget.lat!,
                            widget.lng!,
                            current,
                          ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
