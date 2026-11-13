import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_rpg.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../spots/models/spot_model.dart';
import '../../spots/providers/spot_discovery_provider.dart';
import '../providers/profile_stats_provider.dart';
import '../providers/user_spots_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? username;
  const ProfileScreen({super.key, this.username});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isFollowing = false;

  Color? _cosmeticColor(dynamic value) {
    if (value is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)) {
      return null;
    }
    return Color(int.parse(value.substring(1), radix: 16) | 0xff000000);
  }

  Map<String, dynamic>? _cosmeticAsset(
      Map<String, dynamic>? cosmetics, String slot) {
    final item = cosmetics?[slot];
    if (item is! Map || item['asset'] is! Map) return null;
    return Map<String, dynamic>.from(item['asset'] as Map);
  }

  Widget _buildAvatarWidget(
    BuildContext context,
    PixelGrid grid,
    String? avatarUrl,
    String displayName,
  ) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));
    final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'J';
    return SizedBox(
      width: grid.px(42),
      height: grid.px(42),
      child: ClipRect(
        child: isValidUrl
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _avatarFallback(context, initial),
              )
            : _avatarFallback(context, initial),
      ),
    );
  }

  Widget _avatarFallback(BuildContext context, String initial) {
    return DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.greenDeep,
      child: Center(
        child: Text(
          initial,
          style: PixelType.display(context, color: PixelPalette.paper),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);
    final spotsState = ref.watch(spotDiscoveryProvider);

    final isMine = widget.username == null ||
        widget.username == currentUser?.id ||
        widget.username == currentUser?.seedId ||
        (currentUser != null &&
            widget.username == currentUser.handle.replaceFirst('@', ''));

    final displayName = isMine
        ? (currentUser?.displayName ?? 'Juan Dela Cruz')
        : (widget.username ?? 'Pangasinan Explorer');

    final displayHandle = isMine
        ? currentUser?.publicHandle
        : (widget.username != null &&
                !RegExp(r'^usr-[0-9a-f-]+$', caseSensitive: false)
                    .hasMatch(widget.username!.trim())
            ? (widget.username!.trim().startsWith('@')
                ? widget.username!.trim()
                : '@${widget.username!.trim()}')
            : null);
    final cosmetics = isMine ? currentUser?.cosmetics : null;
    final titleAsset = _cosmeticAsset(cosmetics, 'title');
    final nameColorAsset = _cosmeticAsset(cosmetics, 'nameColor');

    final pointsBalance = currentUser?.points ?? stats.pointsBalance;
    final level = (pointsBalance / 50).floor() + 1;

    final earnedBadges = [
      stats.ecoPioneerState,
      stats.heritageKeeperState,
      stats.foodExplorerState,
    ].where((s) => s == BadgeState.earned).length;

    final savedSpots = spotsState.spots.where((s) => s.saved).length;

    final targetHandle = isMine
        ? (currentUser?.handle.replaceFirst('@', '') ?? currentUser?.id ?? '')
        : (widget.username ?? '').replaceFirst('@', '');
    final userSpotsAsync = targetHandle.isNotEmpty
        ? ref.watch(userSpotsProvider(targetHandle))
        : const AsyncValue<List<SpotModel>>.data([]);

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: isMine ? 'Traveler Passport' : 'Explorer Profile',
                    isTab: isMine,
                    onBack: canPop && !isMine
                        ? () => Navigator.of(context).maybePop()
                        : null,
                    actions: [
                      if (isMine)
                        PixelIconButton(
                          icon: DesignerArt.notifBell,
                          semanticLabel: 'Notifications',
                          onPressed: () => context.push('/notifications'),
                        ),
                      if (isMine)
                        PixelIconButton(
                          icon: DesignerArt.navSettings,
                          semanticLabel: 'Explorer Settings',
                          onPressed: () => context.push('/settings'),
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        _identity(
                          context,
                          grid,
                          isMine,
                          displayName,
                          displayHandle,
                          currentUser,
                          cosmetics,
                          titleAsset,
                          nameColorAsset,
                          level,
                          pointsBalance,
                        ),
                        SizedBox(height: grid.px(3)),
                        _actionButtons(context, grid, isMine, earnedBadges, savedSpots),
                        if (isMine) ...[
                          SizedBox(height: grid.px(2)),
                          Semantics(
                            button: true,
                            label: 'Open Shop',
                            child: GestureDetector(
                              key: const ValueKey('profile_shop'),
                              behavior: HitTestBehavior.opaque,
                              onTap: () => context.push('/shop'),
                              child: PixelPanel(
                                style: PixelBoxStyle.parchment,
                                child: Row(
                                  children: [
                                    const PixelMicro(PixelMicroArt.coin,
                                        scale: 2),
                                    SizedBox(width: grid.px(2)),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text('Shop',
                                              style: PixelType.title(context)),
                                          Text(
                                            'Cosmetics & merchant vouchers ›',
                                            style: PixelType.small(context,
                                                color: PixelPalette.slate),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        SizedBox(height: grid.px(4)),
                        _postedDestinations(
                          context,
                          grid,
                          isMine,
                          targetHandle,
                          userSpotsAsync,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _identity(
    BuildContext context,
    PixelGrid grid,
    bool isMine,
    String displayName,
    String? displayHandle,
    UserModel? currentUser,
    Map<String, dynamic>? cosmetics,
    Map<String, dynamic>? titleAsset,
    Map<String, dynamic>? nameColorAsset,
    int level,
    int pointsBalance,
  ) {
    final nameColor = _cosmeticColor(nameColorAsset?['color']);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isMine)
            SizedBox(
              height: grid.px(36),
              child: const DitherBackground(
                top: PixelPalette.greenMid,
                bottom: PixelPalette.greenDeep,
              ),
            ),
          if (isMine) SizedBox(height: grid.px(2)),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelPanel(
                style: PixelBoxStyle.gold,
                padding: 1,
                child: _buildAvatarWidget(
                  context,
                  grid,
                  isMine ? currentUser?.avatarUrl : null,
                  displayName,
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      style:
                          PixelType.title(context).copyWith(color: nameColor),
                    ),
                    if (displayHandle != null) ...[
                      SizedBox(height: grid.px(1)),
                      Text(
                        displayHandle,
                        maxLines: 2,
                        style: PixelType.body(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                    ],
                    if ((titleAsset?['text']?.toString() ?? '').isNotEmpty) ...[
                      SizedBox(height: grid.px(1)),
                      PixelPanel(
                        style: PixelBoxStyle.gold.copyWith(
                          corner: 1,
                          shadowPx: 0,
                        ),
                        padding: 1,
                        child: Text(
                          titleAsset!['text'].toString(),
                          maxLines: 2,
                          style: PixelType.small(context),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelChip(
                'Level $level Explorer',
                style: PixelBoxStyle.green,
                textColor: PixelPalette.white,
              ),
              PixelChip('$pointsBalance mJDQ'),
            ],
          ),
          if (isMine) ...[
            SizedBox(height: grid.px(3)),
            PixelButton(
              key: const ValueKey('profile_customize'),
              label: 'Customize Look ›',
              variant: PixelButtonVariant.secondary,
              onPressed: () => context.push('/settings/appearance'),
            ),
          ] else ...[
            SizedBox(height: grid.px(3)),
            PixelButton(
              key: const ValueKey('profile_follow'),
              label: _isFollowing ? 'Following' : 'Follow Scout',
              onPressed: () {
                setState(() => _isFollowing = !_isFollowing);
                showPixelToast(
                  context,
                  _isFollowing
                      ? 'Now following $displayName.'
                      : 'Unfollowed $displayName.',
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionButtons(
    BuildContext context,
    PixelGrid grid,
    bool isMine,
    int earnedBadges,
    int savedSpots,
  ) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Badges and stamps case',
            child: GestureDetector(
              key: const ValueKey('profile_badges'),
              behavior: HitTestBehavior.opaque,
              onTap: () => context.push('/profile/badges'),
              child: PixelPanel(
                style: PixelBoxStyle.parchment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const PixelMicro(PixelMicroArt.sparkle, scale: 2),
                        SizedBox(width: grid.px(1)),
                        Text('Badges', style: PixelType.title(context)),
                      ],
                    ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      '$earnedBadges of 3 Earned ›',
                      style: PixelType.small(context, color: PixelPalette.greenDark),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (isMine) ...[
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Semantics(
              button: true,
              label: 'Saved places',
              child: GestureDetector(
                key: const ValueKey('profile_saved'),
                behavior: HitTestBehavior.opaque,
                onTap: () => context.push('/saved'),
                child: PixelPanel(
                  style: PixelBoxStyle.parchment,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const PixelMicro(PixelMicroArt.coin, scale: 2),
                          SizedBox(width: grid.px(1)),
                          Text('Saved', style: PixelType.title(context)),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        '$savedSpots Places ›',
                        style: PixelType.small(context, color: PixelPalette.slate),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _postedDestinations(
    BuildContext context,
    PixelGrid grid,
    bool isMine,
    String targetHandle,
    AsyncValue<List<SpotModel>> userSpotsAsync,
  ) {
    final countSuffix = userSpotsAsync.maybeWhen(
      data: (spots) => ' (${spots.length})',
      orElse: () => '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Posted Destinations$countSuffix',
                style: PixelType.title(context),
              ),
            ),
            if (isMine)
              PixelButton(
                key: const ValueKey('profile_post_spot'),
                label: '+ Post Spot',
                onPressed: () => context.push('/map/add-spot'),
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        userSpotsAsync.when(
          loading: () => PixelPanel(
            key: const ValueKey('profile_spots_loading'),
            style: PixelBoxStyle.parchment,
            padding: 2,
            child: Center(
              child: Text(
                'Loading destinations...',
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
            ),
          ),
          error: (_, __) => PixelPanel(
            key: const ValueKey('profile_spots_error'),
            style: PixelBoxStyle.parchment,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Unable to load destinations.',
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  key: const ValueKey('profile_spots_retry'),
                  label: 'RETRY',
                  variant: PixelButtonVariant.secondary,
                  onPressed: () => ref.invalidate(userSpotsProvider(targetHandle)),
                ),
              ],
            ),
          ),
          data: (userSpots) {
            if (userSpots.isEmpty) {
              return PixelPanel(
                key: const ValueKey('profile_no_spots'),
                style: PixelBoxStyle.parchment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      isMine
                          ? 'No destinations posted yet. Share a hidden spot in Pangasinan!'
                          : 'No destinations posted yet by this explorer.',
                      style: PixelType.body(context, color: PixelPalette.slate),
                    ),
                    if (isMine) ...[
                      SizedBox(height: grid.px(2)),
                      PixelButton(
                        key: const ValueKey('profile_post_spot_empty'),
                        label: '+ Post a Destination',
                        onPressed: () => context.push('/map/add-spot'),
                      ),
                    ],
                  ],
                ),
              );
            }
            return Column(
              children: [
                for (final spot in userSpots) ...[
                  _spotCard(context, grid, spot),
                  SizedBox(height: grid.px(2)),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _spotCard(BuildContext context, PixelGrid grid, SpotModel spot) {
    final photo = spot.imageUrl;
    final hasPhoto = photo != null && photo.trim().isNotEmpty;

    return Semantics(
      button: true,
      label: '${spot.name}, ${spot.municipality}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.push('/explore/${spot.slug}', extra: spot),
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          padding: 2,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: grid.px(16),
                height: grid.px(16),
                child: ClipRect(
                  child: hasPhoto
                      ? Image.network(
                          photo,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _spotFallback(context),
                        )
                      : _spotFallback(context),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      spot.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.title(context),
                    ),
                    SizedBox(height: grid.px(0.5)),
                    Text(
                      '${spot.municipality} · ${spot.category.toUpperCase()}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(context, color: PixelPalette.greenDark),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(1)),
              PixelButton(
                label: 'View ›',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/explore/${spot.slug}', extra: spot),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _spotFallback(BuildContext context) {
    return const DitherBackground(
      top: PixelPalette.greenMid,
      bottom: PixelPalette.greenDeep,
    );
  }
}
