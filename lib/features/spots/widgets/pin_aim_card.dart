import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/spot_recognition_provider.dart';
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
          child: Icon(Icons.location_on_rounded, size: 44, color: AppColors.woodBrown, semanticLabel: 'Pin aim'),
        ),
      ),
    );
  }
}

/// Live "recognized place" card: what the crosshair is over, before the composer opens.
class PinAimCard extends ConsumerStatefulWidget {
  final double? lat;
  final double? lng;
  final void Function(double lat, double lng, SpotRecognitionResult? recognition) onContinue;
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
      final result = await ref.read(spotRecognitionApiProvider).recognizeLocation(lat: lat, lng: lng);
      if (!mounted || request != _request) return;
      setState(() {
        _result = result;
        _resultKey = key;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final current = _resultKey == _key ? _result : null;
    final duplicate = current?.nearbyDuplicates.isNotEmpty == true ? current!.nearbyDuplicates.first : null;
    return Material(
      color: Colors.white,
      elevation: 6,
      borderRadius: AppSpacing.roundedXl,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'MOVE THE MAP TO AIM THE PIN',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Color(0xFFB45309), letterSpacing: 0.8),
                  ),
                ),
                IconButton(
                  onPressed: widget.onCancel,
                  tooltip: 'Cancel adding a spot',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ),
            if (current == null)
              const Row(
                children: [
                  SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Flexible(child: Text('Recognizing this place…', style: TextStyle(fontWeight: FontWeight.w800))),
                ],
              )
            else ...[
              Text(current.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
              if (current.formattedAddress.isNotEmpty)
                Text(current.formattedAddress, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: AppSpacing.roundedLg),
                child: Text(
                  '${categoryLabel(current.suggestedCategory)} · ${current.suggestedSubcategory.replaceAll('_', ' ')}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
              if (current.outsidePangasinan)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Outside Pangasinan — double-check the pin.',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF92400E))),
                ),
            ],
            if (duplicate != null)
              Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Text(
                  'Looks close to ${duplicate.name} (${duplicate.distanceMeters} m away). Continue only if it is a different place.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: widget.locating ? null : widget.onUseMyLocation,
                  icon: widget.locating
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location_rounded, size: 16),
                  label: const Text('Use my GPS'),
                ),
                FilledButton.icon(
                  onPressed: widget.lat == null || widget.lng == null
                      ? null
                      : () => widget.onContinue(widget.lat!, widget.lng!, current),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                  label: const Text('Continue with this place'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
