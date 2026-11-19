import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_text.dart';
import '../models/app_version_info.dart';
import '../providers/app_update_provider.dart';

/// Hosts the admin-configured in-app announcement banner above [child]
/// whenever an active, non-expired, non-dismissed announcement exists.
class AppAnnouncementHost extends ConsumerWidget {
  final Widget child;

  const AppAnnouncementHost({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcement = ref.watch(activeAnnouncementProvider);
    if (announcement == null) {
      return child;
    }

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: AppAnnouncementBanner(
            announcement: announcement,
            onDismiss: () => ref
                .read(dismissedAnnouncementProvider.notifier)
                .dismiss(announcement.dismissalKey),
          ),
        ),
        Expanded(
          child: MediaQuery.removePadding(
            context: context,
            removeTop: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class AppAnnouncementBanner extends StatelessWidget {
  final AppAnnouncement announcement;
  final VoidCallback onDismiss;

  const AppAnnouncementBanner({
    super.key,
    required this.announcement,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final fg = announcement.isWarning ? PixelPalette.ink : PixelPalette.white;
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
        child: PixelPanel(
          style: announcement.isWarning
              ? PixelBoxStyle.gold
              : PixelBoxStyle.coin,
          padding: 1,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, right: 8),
                child: Icon(
                  announcement.isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.campaign_rounded,
                  size: 18,
                  color: fg,
                ),
              ),
              Expanded(
                child: Text(
                  announcement.text,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: fg),
                ),
              ),
              Semantics(
                button: true,
                label: 'Dismiss announcement',
                child: InkWell(
                  key: const Key('dismiss_app_announcement_btn'),
                  onTap: onDismiss,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: fg,
                      ),
                    ),
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
