import 'package:flutter/material.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../models/spot_model.dart';

/// Sends the chosen asset id to the server and returns the new cover url.
typedef SpotCoverPickFn = Future<String> Function(String assetId);

/// Plan 124b: the author picks the destination's cover from its approved
/// photos (uploads that passed review and licensed catalog photos).
class SpotCoverPickerSheet extends StatefulWidget {
  const SpotCoverPickerSheet({
    super.key,
    required this.candidates,
    required this.currentUrl,
    required this.onPick,
  });

  final List<SpotCoverCandidate> candidates;
  final String? currentUrl;
  final SpotCoverPickFn onPick;

  /// Pops with the new cover url, or null when nothing changed.
  static Future<String?> show(
    BuildContext context, {
    required List<SpotCoverCandidate> candidates,
    required String? currentUrl,
    required SpotCoverPickFn onPick,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => SpotCoverPickerSheet(
        candidates: candidates,
        currentUrl: currentUrl,
        onPick: onPick,
      ),
    );
  }

  @override
  State<SpotCoverPickerSheet> createState() => _SpotCoverPickerSheetState();
}

class _SpotCoverPickerSheetState extends State<SpotCoverPickerSheet> {
  String? _busyId;
  String? _error;

  Future<void> _pick(SpotCoverCandidate candidate) async {
    if (_busyId != null || candidate.url == widget.currentUrl) return;
    setState(() {
      _busyId = candidate.assetId;
      _error = null;
    });
    try {
      final url = await widget.onPick(candidate.assetId);
      if (mounted) Navigator.of(context).pop(url);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busyId = null;
          _error = 'Could not change the cover. Try again.';
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
          bottom: MediaQuery.paddingOf(context).bottom + grid.px(3),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: SingleChildScrollView(
            key: const ValueKey('spot_cover_picker_sheet'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: PixelSectionTitle(
                        'CHOOSE COVER',
                        colors: PixelText3DColors.cream,
                      ),
                    ),
                    InkWell(
                      key: const ValueKey('spot_cover_picker_close'),
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          minHeight: 48,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '✕',
                          style: PixelType.title(
                            context,
                            color: PixelPalette.paper,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  'Pick one of the approved photos. It becomes the photo on '
                  'Explore, the map and this page.',
                  style: PixelType.small(context, color: PixelPalette.mist),
                ),
                SizedBox(height: grid.px(2)),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: grid.px(1),
                  crossAxisSpacing: grid.px(1),
                  children: [
                    for (final c in widget.candidates) _tile(context, c),
                  ],
                ),
                if (_error != null) ...[
                  SizedBox(height: grid.px(1.5)),
                  Text(
                    _error!,
                    key: const ValueKey('spot_cover_error'),
                    style: PixelType.small(context, color: PixelPalette.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, SpotCoverCandidate c) {
    final isCover = c.url == widget.currentUrl;
    final busy = _busyId == c.assetId;
    return Semantics(
      button: !isCover,
      selected: isCover,
      label: isCover ? 'Current cover photo' : 'Set this photo as the cover',
      child: GestureDetector(
        key: ValueKey('spot_cover_option_${c.assetId}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _pick(c),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: PixelPalette.woodDeep,
                child: Image.network(
                  c.url,
                  fit: BoxFit.cover,
                  cacheWidth: 480,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.image_not_supported_outlined,
                    color: PixelPalette.mist,
                  ),
                ),
              ),
              if (isCover)
                Positioned(
                  left: 6,
                  top: 6,
                  child: Container(
                    key: ValueKey('spot_cover_badge_${c.assetId}'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: PixelPalette.gold,
                      borderRadius: BorderRadius.circular(3),
                    ),
                    child: Text(
                      'COVER',
                      style: PixelType.small(context, color: PixelPalette.ink),
                    ),
                  ),
                ),
              if (busy)
                ColoredBox(
                  color: PixelPalette.woodNight.withValues(alpha: 0.6),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
