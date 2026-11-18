import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_language.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_input.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import '../cosmetics/widgets/cosmetic_avatar.dart';

/// One traveler row in People (search result or follow list).
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.displayName,
    this.handle,
    this.avatarUrl,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;

  /// `/profile/:username` accepts a handle or a user id.
  String get profilePath => '/profile/${Uri.encodeComponent(handle ?? id)}';

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
        id: '${json['id'] ?? json['user_id'] ?? ''}',
        displayName: json['display_name'] as String? ?? 'Explorer',
        handle: json['handle'] as String?,
        avatarUrl: json['avatar_url'] as String?,
      );
}

List<PersonSummary> _people(dynamic data) =>
    ((data is Map ? data['items'] : null) as List? ?? const [])
        .whereType<Map>()
        .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();

/// `following` or `followers` of the signed-in traveler.
final myFollowListProvider = FutureProvider.autoDispose
    .family<List<PersonSummary>, String>((ref, which) async {
  final res = await ref
      .watch(apiClientProvider)
      .dio
      .get('/users/me/$which', queryParameters: {'limit': 50});
  return _people(res.data?['data']);
});

final peopleSearchProvider = FutureProvider.autoDispose
    .family<List<PersonSummary>, String>((ref, query) async {
  final res = await ref.watch(apiClientProvider).dio.get('/search',
      queryParameters: {'q': query, 'type': 'people', 'mode': 'full'});
  return _people(res.data?['data']);
});

/// Owner 2026-11-18 (Plaza "Find people + lists"): search travelers and see
/// who you follow and who follows you.
class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key, this.initialTab = 0});

  /// 0 = Find, 1 = Following, 2 = Followers.
  final int initialTab;

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  late int _tab = widget.initialTab;
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final tabs = [
          tr(context, en: 'Find', tl: 'Hanapin'),
          tr(context, en: 'Following', tl: 'Sinusundan'),
          tr(context, en: 'Followers', tl: 'Tagasunod'),
        ];
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: tr(context, en: 'People', tl: 'Mga tao'),
                  onBack: () => Navigator.of(context).maybePop(),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(
                        grid.gutter, grid.px(3), grid.gutter, grid.px(8)),
                    children: [
                      PixelSegmented(
                        key: const ValueKey('people_tabs'),
                        items: tabs,
                        selectedIndex: _tab,
                        onChanged: (i) => setState(() => _tab = i),
                      ),
                      SizedBox(height: grid.px(3)),
                      if (_tab == 0) ...[
                        PixelTextField(
                          key: const ValueKey('people_search'),
                          controller: _search,
                          hint: tr(context,
                              en: 'Name or @handle', tl: 'Pangalan o @handle'),
                          textInputAction: TextInputAction.search,
                          onChanged: _onQuery,
                        ),
                        SizedBox(height: grid.px(3)),
                        _searchResults(context),
                      ] else
                        _list(
                          context,
                          ref.watch(myFollowListProvider(
                              _tab == 1 ? 'following' : 'followers')),
                          empty: _tab == 1
                              ? tr(context,
                                  en:
                                      "You don't follow anyone yet. Find people to see their quests on the Plaza.",
                                  tl:
                                      'Wala ka pang sinusundan. Maghanap ng tao para makita ang quest nila sa Plaza.')
                              : tr(context,
                                  en: 'No followers yet.',
                                  tl: 'Wala pang tagasunod.'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _searchResults(BuildContext context) {
    if (RegExp(r'[A-Za-z0-9]').allMatches(_query).length < 2) {
      return Text(
        tr(context,
            en: 'Type at least 2 letters to search travelers.',
            tl: 'Mag-type ng 2 letra para maghanap.'),
        style: PixelType.body(context, color: PixelPalette.slate),
      );
    }
    return _list(context, ref.watch(peopleSearchProvider(_query)),
        empty: tr(context,
            en: 'No public travelers match "$_query".',
            tl: 'Walang tugma sa "$_query".'));
  }

  Widget _list(BuildContext context, AsyncValue<List<PersonSummary>> value,
      {required String empty}) {
    final grid = PixelGrid.of(context);
    return value.when(
      loading: () => const Center(child: PixelLoader(label: 'Loading')),
      error: (_, __) => PixelPanel(
        style: PixelBoxStyle.red,
        child: Text(
          tr(context,
              en: 'Could not load people. Try again in a moment.',
              tl: 'Hindi ma-load. Subukang muli.'),
          style: PixelType.body(context, color: PixelPalette.white),
        ),
      ),
      data: (people) => people.isEmpty
          ? PixelEmptyState(
              key: const ValueKey('people_empty'),
              title: tr(context, en: 'Nobody here', tl: 'Wala pa'),
              message: empty,
            )
          : PixelPanel(
              style: PixelBoxStyle.parchment,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < people.length; i++) ...[
                    if (i > 0)
                      Container(
                          height: grid.unit, color: PixelPalette.paperDim),
                    PersonRow(person: people[i]),
                  ],
                ],
              ),
            ),
    );
  }
}

class PersonRow extends StatelessWidget {
  const PersonRow({super.key, required this.person});

  final PersonSummary person;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return GestureDetector(
      key: ValueKey('person_${person.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(person.profilePath),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: Row(
          children: [
            CosmeticAvatar(
              name: person.displayName,
              imageUrl: person.avatarUrl,
              size: grid.px(12),
            ),
            SizedBox(width: grid.px(2)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context, color: PixelPalette.ink)),
                  if (person.handle != null)
                    Text('@${person.handle}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(context,
                            color: PixelPalette.slate)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
