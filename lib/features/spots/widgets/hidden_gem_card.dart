import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/hidden_gem_model.dart';
import '../providers/hidden_gem_provider.dart';

class HiddenGemCard extends ConsumerWidget {
  const HiddenGemCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gems = ref.watch(hiddenGemProvider);
    final grid = PixelGrid.of(context);
    return gems.when(
      loading: () => const _HiddenGemPlaceholder(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: EdgeInsets.only(bottom: grid.px(3)),
              child: _HiddenGemAd(gem: items.first),
            ),
    );
  }
}

class _HiddenGemAd extends StatelessWidget {
  const _HiddenGemAd({required this.gem});

  final HiddenGemModel gem;

  void _open(BuildContext context) =>
      context.push('/explore/${Uri.encodeComponent(gem.id)}');

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final crowdStyle = switch (gem.crowdStatus) {
      'quiet' => PixelBoxStyle.green,
      'moderate' => PixelBoxStyle.gold,
      'busy' || 'crowded' => PixelBoxStyle.red,
      _ => PixelBoxStyle.slot,
    };
    final crowdText = switch (gem.crowdStatus) {
      'quiet' || 'busy' || 'crowded' => PixelPalette.white,
      _ => PixelPalette.ink,
    };
    return Semantics(
      container: true,
      label:
          'Hidden Gem recommendation, not sponsored: ${gem.name}, ${gem.municipality}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: PixelPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                children: const [
                  PixelChip(
                    'HIDDEN GEM',
                    style: PixelBoxStyle.green,
                    textColor: PixelPalette.white,
                  ),
                  PixelChip(
                    'Not sponsored',
                    style: PixelBoxStyle.slot,
                    textColor: PixelPalette.slate,
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),
              PixelPanel(
                style: PixelBoxStyle.slot,
                sunken: true,
                padding: 1,
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: gem.imageUrl != null
                        ? Image.network(
                            gem.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _ImageFallback(),
                          )
                        : const _ImageFallback(),
                  ),
                ),
              ),
              SizedBox(height: grid.px(2)),
              Text(
                gem.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                gem.municipality,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(
                  context,
                  color: PixelPalette.greenDark,
                ),
              ),
              SizedBox(height: grid.px(1)),
              PixelText.rich(
                gem.reason,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(2)),
              Wrap(
                spacing: grid.px(2),
                runSpacing: grid.px(1),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PixelChip(
                    gem.crowdLabel,
                    style: crowdStyle,
                    textColor: crowdText,
                  ),
                ],
              ),
              SizedBox(height: grid.px(2)),
              PixelButton(
                label: 'View this gem',
                expand: true,
                onPressed: () => _open(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback();

  @override
  Widget build(BuildContext context) => const DitherBackground(
        top: PixelPalette.paperDim,
        bottom: PixelPalette.paper,
      );
}

class _HiddenGemPlaceholder extends StatelessWidget {
  const _HiddenGemPlaceholder();

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: grid.px(3)),
      child: Semantics(
        label: 'Loading Hidden Gem recommendation',
        child: PixelPanel(
          child: Row(
            children: [
              const PixelLoader(),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Text(
                  'Loading Hidden Gem recommendation',
                  style: PixelType.small(
                    context,
                    color: PixelPalette.slate,
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
