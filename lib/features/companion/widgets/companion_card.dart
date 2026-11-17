import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../providers/companion_provider.dart';
import '../../spots/providers/spot_discovery_provider.dart';

class CompanionCard extends ConsumerWidget {
  final int tabIndex;
  const CompanionCard({super.key, required this.tabIndex});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = ref.watch(companionMessageProvider(tabIndex));
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;

    final card = message == null
        ? const SizedBox.shrink()
        : Dismissible(
            key: ValueKey('companion-${message.id}'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              ref
                  .read(companionControllerProvider.notifier)
                  .dismiss(message.id);
            },
            background: Container(
              margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppSpacing.roundedLg,
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:
                  const Icon(Icons.close_rounded, color: AppColors.textMuted),
            ),
            secondaryBackground: Container(
              margin: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: AppSpacing.roundedLg,
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child:
                  const Icon(Icons.close_rounded, color: AppColors.textMuted),
            ),
            child: Semantics(
              container: true,
              liveRegion: true,
              label:
                  'Juan, your travel companion. ${message.title}. ${message.body}',
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _JuanAvatar(),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              message.title,
                              style: PixelType.title(
                                context,
                                color: PixelPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              message.body,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            if (message.actionLabel != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: PixelButton(
                                    label: message.actionLabel!,
                                    variant: PixelButtonVariant.secondary,
                                    onPressed: () {
                                      if (message.id == 'discovery-offline') {
                                        ref
                                            .read(
                                                spotDiscoveryProvider.notifier)
                                            .load(refresh: true);
                                      } else if (message.route != null) {
                                        context.push(message.route!);
                                      }
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Clean 'X' Close Button (>=48dp tap target)
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: IconButton(
                          icon: const Icon(Icons.close_rounded,
                              size: 18, color: PixelPalette.slate),
                          tooltip: 'Dismiss hint',
                          onPressed: () {
                            ref
                                .read(companionControllerProvider.notifier)
                                .dismiss(message.id);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );

    return AnimatedSwitcher(
      duration:
          reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
      child: KeyedSubtree(key: ValueKey(message?.id), child: card),
    );
  }
}

class _JuanAvatar extends StatelessWidget {
  const _JuanAvatar();
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.surfaceContainerHigh,
          border: Border.all(color: AppColors.borderLowContrast),
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset(
          'assets/images/logo.png',
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: AppColors.sunGold,
            child: const Icon(Icons.explore_rounded,
                color: AppColors.woodBrown, size: 24),
          ),
        ),
      );
}
