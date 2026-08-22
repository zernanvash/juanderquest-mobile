import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
        : Semantics(
            container: true,
            liveRegion: true,
            label:
                'Juan, your travel companion. ${message.title}. ${message.body}',
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
              child: Material(
                elevation: 3,
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedLg,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
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
                              Text(message.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(message.body,
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (message.actionLabel != null)
                                Align(
                                    alignment: Alignment.centerLeft,
                                    child: TextButton(
                                        onPressed: () {
                                          if (message.id ==
                                              'discovery-offline') {
                                            ref
                                                .read(spotDiscoveryProvider
                                                    .notifier)
                                                .load(refresh: true);
                                          } else if (message.route != null) {
                                            context.push(message.route!);
                                          }
                                        },
                                        child: Text(message.actionLabel!))),
                            ])),
                        PopupMenuButton<String>(
                            tooltip: 'Juan companion options',
                            onSelected: (value) {
                              if (value == 'dismiss') {
                                ref
                                    .read(companionControllerProvider.notifier)
                                    .dismiss(message.id);
                              }
                              if (value == 'mute') {
                                ref
                                    .read(companionControllerProvider.notifier)
                                    .toggleMuted();
                              }
                            },
                            itemBuilder: (_) => const [
                                  PopupMenuItem(
                                      value: 'dismiss',
                                      child: Text('Dismiss this tip')),
                                  PopupMenuItem(
                                      value: 'mute', child: Text('Mute Juan'))
                                ]),
                      ]),
                ),
              ),
            ),
          );
    return AnimatedSwitcher(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 280),
        child: KeyedSubtree(key: ValueKey(message?.id), child: card));
  }
}

class _JuanAvatar extends StatelessWidget {
  const _JuanAvatar();
  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: AppColors.sunGold),
        child: const Stack(alignment: Alignment.center, children: [
          Icon(Icons.explore_rounded, color: AppColors.woodBrown, size: 25),
          Positioned(
              right: 3,
              bottom: 3,
              child: CircleAvatar(
                  radius: 7,
                  backgroundColor: AppColors.primary,
                  child: Text('J',
                      style: TextStyle(
                          fontSize: 8,
                          color: Colors.white,
                          fontWeight: FontWeight.bold))))
        ]),
      );
}
