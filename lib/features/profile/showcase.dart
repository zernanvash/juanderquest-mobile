import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_art.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_text.dart';
import '../auth/providers/auth_provider.dart';
import '../spots/providers/spot_discovery_provider.dart';

/// Profile showcase (owner 2026-11-08: "add bio, 3 badges equipped" + home
/// town, Pasaporte, explorer stats, latest journey and a favourite spot).

class ShowcaseBadge {
  final String id, title, description;
  const ShowcaseBadge({required this.id, required this.title, this.description = ''});
  factory ShowcaseBadge.fromJson(Map<String, dynamic> j) => ShowcaseBadge(
        id: '${j['id']}',
        title: '${j['title'] ?? j['id']}',
        description: '${j['description'] ?? ''}',
      );
}

class JourneyStop {
  final String title;
  final String? municipality;
  final DateTime? at;
  const JourneyStop({required this.title, this.municipality, this.at});
  factory JourneyStop.fromJson(Map<String, dynamic> j) => JourneyStop(
        title: '${j['title'] ?? 'Quest'}',
        municipality: j['municipality'] as String?,
        at: DateTime.tryParse('${j['at']}'),
      );
}

class FavoriteSpot {
  final String id, slug, name, municipality;
  const FavoriteSpot({required this.id, required this.slug, required this.name, required this.municipality});
  factory FavoriteSpot.fromJson(Map<String, dynamic> j) => FavoriteSpot(
        id: '${j['id']}',
        slug: '${j['slug'] ?? j['id']}',
        name: '${j['name'] ?? ''}',
        municipality: '${j['municipality'] ?? ''}',
      );
}

class ProfileShowcase {
  final String? bio;
  final String? homeTown;
  final List<ShowcaseBadge> badges;
  final FavoriteSpot? favorite;
  final int quests, spotsPosted, trails, badgesEarned;
  final int? bestWeeklyRank;
  final List<String> townsVisited;
  final int townsTotal;
  final List<JourneyStop> journey;

  const ProfileShowcase({
    this.bio,
    this.homeTown,
    this.badges = const [],
    this.favorite,
    this.quests = 0,
    this.spotsPosted = 0,
    this.trails = 0,
    this.badgesEarned = 0,
    this.bestWeeklyRank,
    this.townsVisited = const [],
    this.townsTotal = 48,
    this.journey = const [],
  });

  factory ProfileShowcase.fromJson(Map<String, dynamic> j) {
    final stats = j['stats'] is Map ? Map<String, dynamic>.from(j['stats'] as Map) : const <String, dynamic>{};
    final pas = j['pasaporte'] is Map ? Map<String, dynamic>.from(j['pasaporte'] as Map) : const <String, dynamic>{};
    int n(Object? v) => v is num ? v.toInt() : 0;
    return ProfileShowcase(
      bio: (j['bio'] as String?)?.trim().isEmpty == true ? null : j['bio'] as String?,
      homeTown: j['home_municipality'] as String?,
      badges: [
        for (final b in (j['featured_badges'] as List? ?? const []))
          if (b is Map) ShowcaseBadge.fromJson(Map<String, dynamic>.from(b)),
      ],
      favorite: j['favorite_spot'] is Map
          ? FavoriteSpot.fromJson(Map<String, dynamic>.from(j['favorite_spot'] as Map))
          : null,
      quests: n(stats['quests_completed']),
      spotsPosted: n(stats['spots_posted']),
      trails: n(stats['trails_completed']),
      badgesEarned: n(stats['badges_earned']),
      bestWeeklyRank: (stats['best_weekly_rank'] as num?)?.toInt(),
      townsVisited: [for (final t in (pas['visited'] as List? ?? const [])) '$t'],
      townsTotal: n(pas['total']) == 0 ? 48 : n(pas['total']),
      journey: [
        for (final s in (j['latest_journey'] as List? ?? const []))
          if (s is Map) JourneyStop.fromJson(Map<String, dynamic>.from(s)),
      ],
    );
  }
}

/// Key: '' for your own profile, else the handle.
final showcaseProvider = FutureProvider.autoDispose.family<ProfileShowcase?, String>((ref, handle) async {
  final dio = ref.watch(apiClientProvider).dio;
  final res = await dio.get(handle.isEmpty ? '/me/showcase' : '/users/${Uri.encodeComponent(handle)}/showcase');
  final data = res.data is Map ? res.data['data'] : null;
  return data is Map ? ProfileShowcase.fromJson(Map<String, dynamic>.from(data)) : null;
});

/// Server badges: what you earned and the whole catalog (Badges screen, picker).
class AchievementsData {
  final List<ShowcaseBadge> earned;
  final List<ShowcaseBadge> catalog;
  const AchievementsData({this.earned = const [], this.catalog = const []});
  bool has(String id) => earned.any((b) => b.id == id);
}

final achievementsProvider = FutureProvider.autoDispose<AchievementsData>((ref) async {
  final dio = ref.watch(apiClientProvider).dio;
  final res = await dio.get('/me/achievements');
  final data = res.data is Map ? res.data['data'] : null;
  if (data is! Map) return const AchievementsData();
  List<ShowcaseBadge> list(Object? raw, {bool award = false}) => [
        for (final e in (raw as List? ?? const []))
          if (e is Map)
            ShowcaseBadge.fromJson(award
                ? {
                    'id': e['achievement_id'] ?? e['id'],
                    'title': e['title'] ?? e['achievement_title'] ?? e['achievement_id'],
                    'description': e['description'] ?? '',
                  }
                : Map<String, dynamic>.from(e)),
      ];
  final catalog = list(data['catalog']);
  final earnedIds = list(data['earned'], award: true).map((b) => b.id).toSet();
  return AchievementsData(
    catalog: catalog,
    earned: [
      for (final b in catalog)
        if (earnedIds.contains(b.id)) b
    ],
  );
});

/// A pixel medal (server badge icons can be emoji; the pixel UI never shows those).
const showcaseMedal = PixelArt('showcaseMedal', [
  '..yy....yy..',
  '...yy..yy...',
  '....yyyy....',
  '...ssssss...',
  '..ssuuuuss..',
  '.ssuu66uuss.',
  '.ssuu66uuss.',
  '..ssuuuuss..',
  '...ssssss...',
  '............',
]);

/// Everything under the name: bio, home town, equipped badges, stats,
/// Pasaporte, favourite spot and latest journey.
class ProfileShowcaseSection extends ConsumerWidget {
  const ProfileShowcaseSection({super.key, required this.showcase, required this.isMine});
  final ProfileShowcase showcase;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grid = PixelGrid.of(context);
    final s = showcase;
    final gap = SizedBox(height: grid.px(3));
    return Column(key: const ValueKey('profile_showcase'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _bio(context, ref, grid),
      gap,
      _badges(context, ref, grid),
      gap,
      _stats(context, grid),
      gap,
      _pasaporte(context, grid),
      if (s.favorite != null || isMine) ...[gap, _favorite(context, ref, grid)],
      if (s.journey.isNotEmpty) ...[gap, _journey(context, grid)],
    ]);
  }

  Widget _header(BuildContext context, String title, {VoidCallback? onEdit, Key? editKey}) => Row(children: [
        Expanded(child: Text(title, style: PixelType.title(context))),
        if (onEdit != null) PixelChip('EDIT', key: editKey, style: PixelBoxStyle.parchment, onTap: onEdit),
      ]);

  Widget _bio(BuildContext context, WidgetRef ref, PixelGrid grid) {
    final bio = showcase.bio;
    final town = showcase.homeTown;
    return PixelPanel(
      key: const ValueKey('profile_bio'),
      style: PixelBoxStyle.parchment,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(context, 'About',
            editKey: const ValueKey('profile_edit_bio'),
            onEdit: isMine ? () => showBioEditor(context, ref, bio) : null),
        SizedBox(height: grid.px(1)),
        Text(
          bio ??
              (isMine
                  ? 'Tell other explorers about you: your favourite food, places, or why you travel.'
                  : 'No bio yet.'),
          style: PixelType.body(context, color: bio == null ? PixelPalette.slate : PixelPalette.ink),
        ),
        if (town != null) ...[
          SizedBox(height: grid.px(1)),
          Text('Taga-$town',
              key: const ValueKey('profile_home_town'), style: PixelType.small(context, color: PixelPalette.greenDark)),
        ],
      ]),
    );
  }

  Widget _badges(BuildContext context, WidgetRef ref, PixelGrid grid) {
    final b = showcase.badges;
    Widget slot(int i) {
      final badge = i < b.length ? b[i] : null;
      return Expanded(
        child: PixelPanel(
          key: ValueKey('profile_badge_slot_$i'),
          style: badge == null ? PixelBoxStyle.slot : PixelBoxStyle.gold,
          padding: 1,
          child: SizedBox(
            height: grid.px(22),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (badge != null) const PixelSprite(showcaseMedal, scale: 2),
              SizedBox(height: grid.px(1)),
              Flexible(
                child: Text(
                  badge?.title ?? (isMine ? '+ Equip' : '—'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: PixelType.small(context, color: badge == null ? PixelPalette.slate : PixelPalette.ink),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(context, 'Equipped badges',
          editKey: const ValueKey('profile_edit_badges'),
          onEdit: isMine ? () => showBadgePicker(context, ref, [for (final x in b) x.id]) : null),
      SizedBox(height: grid.px(1)),
      Row(children: [slot(0), SizedBox(width: grid.px(1)), slot(1), SizedBox(width: grid.px(1)), slot(2)]),
    ]);
  }

  Widget _stats(BuildContext context, PixelGrid grid) {
    final s = showcase;
    Widget stat(String value, String label) => Expanded(
          child: Column(children: [
            FittedBox(child: Text(value, style: PixelType.numbers(context, color: PixelPalette.greenDark))),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.small(context, color: PixelPalette.slate)),
          ]),
        );
    return PixelPanel(
      key: const ValueKey('profile_stats'),
      style: PixelBoxStyle.parchment,
      child: Row(children: [
        stat('${s.quests}', 'Quests'),
        stat('${s.spotsPosted}', 'Spots'),
        stat('${s.trails}', 'Trails'),
        stat(s.bestWeeklyRank == null ? '—' : '#${s.bestWeeklyRank}', 'Best week'),
      ]),
    );
  }

  Widget _pasaporte(BuildContext context, PixelGrid grid) {
    final s = showcase;
    final frac = s.townsTotal == 0 ? 0.0 : s.townsVisited.length / s.townsTotal;
    return PixelPanel(
      key: const ValueKey('profile_pasaporte'),
      style: PixelBoxStyle.parchment,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text('Pasaporte', style: PixelType.title(context))),
          PixelChip('${s.townsVisited.length} / ${s.townsTotal}', style: PixelBoxStyle.gold),
        ]),
        SizedBox(height: grid.px(1)),
        Text('Pangasinan towns stamped', style: PixelType.small(context, color: PixelPalette.slate)),
        SizedBox(height: grid.px(1)),
        SizedBox(
          height: grid.px(3),
          child: LayoutBuilder(
            builder: (context, box) => Stack(children: [
              Container(color: PixelPalette.paperDim),
              Container(width: box.maxWidth * frac, color: PixelPalette.greenBright),
            ]),
          ),
        ),
        if (s.townsVisited.isNotEmpty) ...[
          SizedBox(height: grid.px(2)),
          Wrap(spacing: grid.px(1), runSpacing: grid.px(1), children: [
            for (final t in s.townsVisited) PixelChip(t, style: PixelBoxStyle.green, textColor: PixelPalette.white),
          ]),
        ],
      ]),
    );
  }

  Widget _favorite(BuildContext context, WidgetRef ref, PixelGrid grid) {
    final f = showcase.favorite;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _header(context, 'Paborito ko',
          editKey: const ValueKey('profile_edit_favorite'),
          onEdit: isMine ? () => showFavoritePicker(context, ref) : null),
      SizedBox(height: grid.px(1)),
      PixelPanel(
        key: const ValueKey('profile_favorite'),
        style: f == null ? PixelBoxStyle.slot : PixelBoxStyle.parchment,
        child: InkWell(
          onTap: f == null ? () => showFavoritePicker(context, ref) : () => context.push('/explore/${f.slug}'),
          child: Text(
            f == null ? 'Pick a destination you love from your saved places.' : '${f.name} · ${f.municipality}',
            style: PixelType.body(context, color: f == null ? PixelPalette.slate : PixelPalette.ink),
          ),
        ),
      ),
    ]);
  }

  Widget _journey(BuildContext context, PixelGrid grid) {
    String when(DateTime? d) {
      if (d == null) return '';
      final days = DateTime.now().difference(d).inDays;
      return days <= 0
          ? 'today'
          : days == 1
              ? 'yesterday'
              : '$days days ago';
    }

    return Column(key: const ValueKey('profile_journey'), crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Latest journey', style: PixelType.title(context)),
      SizedBox(height: grid.px(1)),
      for (final j in showcase.journey) ...[
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Row(children: [
            const PixelSprite(showcaseMedal, scale: 1),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: PixelType.body(context)),
                Text([if (j.municipality != null) j.municipality!, when(j.at)].where((x) => x.isNotEmpty).join(' · '),
                    style: PixelType.small(context, color: PixelPalette.slate)),
              ]),
            ),
          ]),
        ),
        SizedBox(height: grid.px(1)),
      ],
    ]);
  }
}

void _refresh(WidgetRef ref) {
  ref.invalidate(showcaseProvider(''));
  ref.invalidate(achievementsProvider);
}

/// Edit the bio (300 characters, as the server allows).
Future<void> showBioEditor(BuildContext context, WidgetRef ref, String? current) async {
  final controller = TextEditingController(text: current ?? '');
  final saved = await showPixelDialog<bool>(
    context: context,
    title: 'About you',
    content: TextField(
      key: const ValueKey('bio_field'),
      controller: controller,
      maxLength: 300,
      maxLines: 4,
      decoration: const InputDecoration(hintText: 'e.g. Bangus lover from Dagupan. Chasing every sunset in Bolinao.'),
    ),
    actions: [
      PixelButton(
          label: 'Cancel',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(false)),
      PixelButton(
          key: const ValueKey('bio_save'),
          label: 'Save',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true)),
    ],
  );
  if (saved != true) return;
  final text = controller.text.trim();
  try {
    await ref.read(apiClientProvider).dio.patch('/users/me/profile', data: {'bio': text.isEmpty ? null : text});
    _refresh(ref);
  } catch (_) {
    if (context.mounted) showPixelToast(context, 'Could not save your bio. Try again.');
  }
}

/// Choose up to 3 earned badges to equip, in tap order.
Future<void> showBadgePicker(BuildContext context, WidgetRef ref, List<String> current) async {
  AchievementsData data;
  try {
    data = await ref.read(achievementsProvider.future);
  } catch (_) {
    if (context.mounted) showPixelToast(context, 'Could not load your badges. Try again.');
    return;
  }
  if (!context.mounted) return;
  final picked = [...current.where(data.has)];
  final result = await showPixelDialog<List<String>>(
    context: context,
    title: 'Equip badges',
    message: data.earned.isEmpty
        ? 'Earn badges by visiting places and finishing quests.'
        : 'Pick up to 3. Tap again to remove.',
    content: StatefulBuilder(
      builder: (context, setState) =>
          Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (final b in data.earned)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: PixelButton(
              key: ValueKey('equip_${b.id}'),
              label: picked.contains(b.id) ? '${picked.indexOf(b.id) + 1}. ${b.title}' : b.title,
              variant: picked.contains(b.id) ? PixelButtonVariant.primary : PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => setState(() {
                if (picked.contains(b.id)) {
                  picked.remove(b.id);
                } else if (picked.length < 3) {
                  picked.add(b.id);
                }
              }),
            ),
          ),
      ]),
    ),
    actions: [
      PixelButton(
          label: 'Cancel',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
      PixelButton(
          key: const ValueKey('equip_save'),
          label: 'Save',
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(picked)),
    ],
  );
  if (result == null) return;
  try {
    await ref.read(apiClientProvider).dio.put('/me/featured-badges', data: {'badge_ids': result});
    _refresh(ref);
  } catch (_) {
    if (context.mounted) showPixelToast(context, 'Could not equip those badges. Try again.');
  }
}

/// Pick the favourite destination from your saved places.
Future<void> showFavoritePicker(BuildContext context, WidgetRef ref) async {
  final saved = ref.read(spotDiscoveryProvider).spots.where((s) => s.saved).toList();
  // '' = no favourite.
  final picked = await showPixelDialog<String>(
    context: context,
    title: 'Paborito ko',
    message: saved.isEmpty
        ? 'Save a destination first (the heart on a spot), then pick it here.'
        : 'Your favourite destination.',
    content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final s in saved.take(20))
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: PixelButton(
            key: ValueKey('favorite_${s.id}'),
            label: '${s.name} · ${s.municipality}',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => Navigator.of(context, rootNavigator: true).pop(s.id),
          ),
        ),
    ]),
    actions: [
      PixelButton(
          label: 'Remove',
          variant: PixelButtonVariant.secondary,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop('')),
      PixelButton(label: 'Close', onPressed: () => Navigator.of(context, rootNavigator: true).pop()),
    ],
  );
  if (picked == null) return;
  try {
    await ref.read(apiClientProvider).dio.put('/me/favorite-spot', data: {'spot_id': picked.isEmpty ? null : picked});
    _refresh(ref);
  } catch (_) {
    if (context.mounted) showPixelToast(context, 'Could not save your favourite. Try again.');
  }
}
