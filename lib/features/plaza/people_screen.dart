import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/app_language.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_input.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/pixel/pixel_text_3d.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../cosmetics/widgets/cosmetic_avatar.dart';
import 'plaza_provider.dart';

/// One traveler row in People (suggestion, search result, or follow list).
class PersonSummary {
  const PersonSummary({
    required this.id,
    required this.displayName,
    this.handle,
    this.avatarUrl,
    this.isFollowing = false,
  });

  final String id;
  final String displayName;
  final String? handle;
  final String? avatarUrl;
  final bool isFollowing;

  /// `/profile/:username` accepts a handle or a user id.
  String get profilePath => '/profile/${Uri.encodeComponent(handle ?? id)}';

  PersonSummary copyWith({bool? isFollowing}) => PersonSummary(
        id: id,
        displayName: displayName,
        handle: handle,
        avatarUrl: avatarUrl,
        isFollowing: isFollowing ?? this.isFollowing,
      );

  factory PersonSummary.fromJson(Map<String, dynamic> json) => PersonSummary(
        id: '${json['id'] ?? json['user_id'] ?? ''}',
        displayName: json['display_name'] as String? ?? 'Explorer',
        handle: json['handle'] as String?,
        avatarUrl: json['avatar_url'] as String?,
        isFollowing: json['is_following'] as bool? ?? false,
      );
}

List<PersonSummary> _people(dynamic data) =>
    ((data is Map ? data['items'] : null) as List? ?? const [])
        .whereType<Map>()
        .map((e) => PersonSummary.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.id.isNotEmpty)
        .toList();

/// Shared optimistic follow-state overlay so Follow/Following stays in sync
/// across Suggestions, Search, Following, and Followers without flicker.
final followOverridesProvider =
    StateProvider.autoDispose<Map<String, bool>>((ref) => const {});

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
      queryParameters: {'q': query, 'type': 'people', 'mode': 'results'});
  return _people(res.data?['data']);
});

class PeopleSuggestionsState {
  const PeopleSuggestionsState({
    this.items = const [],
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  final List<PersonSummary> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  PeopleSuggestionsState copyWith({
    List<PersonSummary>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) =>
      PeopleSuggestionsState(
        items: items ?? this.items,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class PeopleSuggestionsNotifier extends StateNotifier<PeopleSuggestionsState> {
  PeopleSuggestionsNotifier(this._ref) : super(const PeopleSuggestionsState()) {
    refresh();
  }

  final Ref _ref;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final res = await _ref.read(apiClientProvider).dio.get(
        '/users/suggestions',
        queryParameters: {'limit': 20},
      );
      if (_disposed) return;
      final data = res.data?['data'];
      final items = _people(data);
      final hasMore = data is Map && data['has_more'] == true;
      state = PeopleSuggestionsState(
        items: items,
        isLoading: false,
        hasMore: hasMore,
      );
    } catch (e) {
      if (_disposed) return;
      state = state.copyWith(isLoading: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final res = await _ref.read(apiClientProvider).dio.get(
        '/users/suggestions',
        queryParameters: {'limit': 20, 'offset': state.items.length},
      );
      if (_disposed) return;
      final data = res.data?['data'];
      final more = _people(data);
      final existingIds = state.items.map((e) => e.id).toSet();
      final merged = [
        ...state.items,
        ...more.where((e) => !existingIds.contains(e.id)),
      ];
      final hasMore = data is Map && data['has_more'] == true;
      state = state.copyWith(
        items: merged,
        isLoadingMore: false,
        hasMore: hasMore,
      );
    } catch (_) {
      if (_disposed) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<bool> dismiss(String userId) async {
    final previous = state.items;
    state = state.copyWith(
      items: previous.where((p) => p.id != userId).toList(),
    );
    try {
      await _ref
          .read(apiClientProvider)
          .dio
          .post('/users/suggestions/$userId/dismiss');
      return true;
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(items: previous);
      }
      return false;
    }
  }
}

final peopleSuggestionsProvider = StateNotifierProvider.autoDispose<
    PeopleSuggestionsNotifier, PeopleSuggestionsState>(
  (ref) => PeopleSuggestionsNotifier(ref),
);

String _extractFollowErrorMessage(Object error, BuildContext context) {
  if (error is DioException) {
    final data = error.response?.data;
    final err = data is Map ? data['error'] : null;
    final msg = err is Map ? err['message'] as String? : null;
    if (msg != null && msg.trim().isNotEmpty) return msg;
    if (error.response?.statusCode == 403) {
      return tr(
        context,
        en: 'Make your profile public in Settings to follow travelers.',
        tl: 'Gawing pampubliko ang profile mo sa Settings para makasunod.',
      );
    }
  }
  return tr(
    context,
    en: 'Could not update follow status. Try again.',
    tl: 'Hindi ma-update ang pagsunod. Subukang muli.',
  );
}

/// Owner 2026-11-18 (Plaza "Find people + lists"): search travelers, discover
/// unified follow suggestions, and manage who you follow and who follows you.
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
  bool _hasSearchText = false;
  final Set<String> _pendingFollows = {};

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onQuery(String value) {
    final hasText = value.isNotEmpty;
    if (hasText != _hasSearchText) {
      setState(() => _hasSearchText = hasText);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _search.clear();
    setState(() {
      _hasSearchText = false;
      _query = '';
    });
  }

  Future<void> _toggleFollow(PersonSummary person, bool isFollowing) async {
    if (_pendingFollows.contains(person.id)) return;
    final nextFollowing = !isFollowing;

    setState(() => _pendingFollows.add(person.id));
    ref.read(followOverridesProvider.notifier).update((prev) => {
          ...prev,
          person.id: nextFollowing,
        });

    try {
      final dio = ref.read(apiClientProvider).dio;
      if (nextFollowing) {
        await dio.put('/users/${person.id}/follow');
      } else {
        await dio.delete('/users/${person.id}/follow');
      }
      if (!mounted) return;
      ref.invalidate(myFollowListProvider('following'));
      ref.invalidate(plazaFeedProvider);
    } catch (e) {
      if (!mounted) return;
      ref.read(followOverridesProvider.notifier).update((prev) => {
            ...prev,
            person.id: isFollowing,
          });
      showPixelToast(context, _extractFollowErrorMessage(e, context));
    } finally {
      if (mounted) {
        setState(() => _pendingFollows.remove(person.id));
      }
    }
  }

  Future<void> _dismissSuggestion(PersonSummary person) async {
    final ok = await ref
        .read(peopleSuggestionsProvider.notifier)
        .dismiss(person.id);
    if (!ok && mounted) {
      showPixelToast(
        context,
        tr(
          context,
          en: 'Could not dismiss suggestion. Try again.',
          tl: 'Hindi maalis ang mungkahi. Subukang muli.',
        ),
      );
    }
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
        final isQueryActive =
            RegExp(r'[A-Za-z0-9]').allMatches(_query).length >= 2;

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
                  child: RefreshIndicator(
                    onRefresh: () async {
                      if (_tab == 0 && !isQueryActive) {
                        await ref
                            .read(peopleSuggestionsProvider.notifier)
                            .refresh();
                      } else if (_tab == 1) {
                        ref.invalidate(myFollowListProvider('following'));
                      } else if (_tab == 2) {
                        ref.invalidate(myFollowListProvider('followers'));
                      }
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
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
                                en: 'Name or @handle',
                                tl: 'Pangalan o @handle'),
                            textInputAction: TextInputAction.search,
                            onChanged: _onQuery,
                            suffix: _hasSearchText
                                ? IconButton(
                                    key: const ValueKey('people_search_clear'),
                                    tooltip:
                                        tr(context, en: 'Clear', tl: 'Burahin'),
                                    icon: const Icon(Icons.close, size: 18),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                          SizedBox(height: grid.px(3)),
                          if (isQueryActive)
                            _searchResults(context)
                          else
                            _suggestionsSection(context),
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
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _suggestionsSection(BuildContext context) {
    final grid = PixelGrid.of(context);
    final sug = ref.watch(peopleSuggestionsProvider);
    final overrides = ref.watch(followOverridesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelSectionTitle(
          tr(context, en: 'Suggested for you', tl: 'Inirerekomenda para sa iyo'),
        ),
        SizedBox(height: grid.px(2)),
        if (sug.isLoading && sug.items.isEmpty)
          const Center(child: PixelLoader(label: 'Loading'))
        else if (sug.error != null && sug.items.isEmpty)
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context,
                      en: 'Could not load suggestions. Try again in a moment.',
                      tl: 'Hindi ma-load ang mga mungkahi. Subukang muli.'),
                  style: PixelType.body(context, color: PixelPalette.white),
                ),
                SizedBox(height: grid.px(2)),
                PixelButton(
                  label: tr(context, en: 'Retry', tl: 'Subukan muli'),
                  variant: PixelButtonVariant.ghost,
                  onPressed: () =>
                      ref.read(peopleSuggestionsProvider.notifier).refresh(),
                ),
              ],
            ),
          )
        else if (sug.items.isEmpty)
          PixelEmptyState(
            key: const ValueKey('people_suggestions_empty'),
            title: tr(context, en: 'All caught up', tl: 'Walang bago'),
            message: tr(
              context,
              en:
                  'No more suggestions right now. Search by @handle to find friends.',
              tl:
                  'Wala nang mungkahi sa ngayon. Maghanap gamit ang @handle para makita ang mga kaibigan.',
            ),
          )
        else ...[
          PixelPanel(
            style: PixelBoxStyle.parchment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < sug.items.length; i++) ...[
                  if (i > 0)
                    Container(
                        height: grid.unit, color: PixelPalette.paperDim),
                  PersonRow(
                    person: sug.items[i],
                    isFollowing:
                        overrides[sug.items[i].id] ?? sug.items[i].isFollowing,
                    isFollowBusy: _pendingFollows.contains(sug.items[i].id),
                    onToggleFollow: () => _toggleFollow(
                      sug.items[i],
                      overrides[sug.items[i].id] ?? sug.items[i].isFollowing,
                    ),
                    onDismiss: () => _dismissSuggestion(sug.items[i]),
                  ),
                ],
              ],
            ),
          ),
          if (sug.hasMore) ...[
            SizedBox(height: grid.px(2)),
            Center(
              child: PixelButton(
                key: const ValueKey('people_suggestions_load_more'),
                label: tr(context, en: 'Load more', tl: 'Mag-load pa'),
                variant: PixelButtonVariant.ghost,
                loading: sug.isLoadingMore,
                onPressed: sug.isLoadingMore
                    ? null
                    : () =>
                        ref.read(peopleSuggestionsProvider.notifier).loadMore(),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _searchResults(BuildContext context) {
    return _list(
      context,
      ref.watch(peopleSearchProvider(_query)),
      empty: tr(context,
          en: 'No public travelers match "$_query".',
          tl: 'Walang tugma sa "$_query".'),
    );
  }

  Widget _list(BuildContext context, AsyncValue<List<PersonSummary>> value,
      {required String empty}) {
    final grid = PixelGrid.of(context);
    final overrides = ref.watch(followOverridesProvider);
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
                    PersonRow(
                      person: people[i],
                      isFollowing:
                          overrides[people[i].id] ?? people[i].isFollowing,
                      isFollowBusy: _pendingFollows.contains(people[i].id),
                      onToggleFollow: () => _toggleFollow(
                        people[i],
                        overrides[people[i].id] ?? people[i].isFollowing,
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class PersonRow extends StatelessWidget {
  const PersonRow({
    super.key,
    required this.person,
    this.isFollowing = false,
    this.isFollowBusy = false,
    this.onToggleFollow,
    this.onDismiss,
  });

  final PersonSummary person;
  final bool isFollowing;
  final bool isFollowBusy;
  final VoidCallback? onToggleFollow;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    final identity = Row(
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
                    style: PixelType.small(context, color: PixelPalette.slate)),
            ],
          ),
        ),
      ],
    );

    final actions = <Widget>[
      if (onToggleFollow != null)
        PixelButton(
          key: ValueKey('person_follow_${person.id}'),
          label: isFollowing
              ? tr(context, en: 'Following', tl: 'Sinusundan')
              : tr(context, en: 'Follow', tl: 'Sundan'),
          variant: isFollowing
              ? PixelButtonVariant.ghost
              : PixelButtonVariant.primary,
          loading: isFollowBusy,
          onPressed: isFollowBusy ? null : onToggleFollow,
        ),
      if (onDismiss != null)
        Tooltip(
          message: tr(context, en: 'Not interested', tl: 'Hindi interesado'),
          child: IconButton(
            key: ValueKey('person_dismiss_${person.id}'),
            icon: const Icon(Icons.close, size: 18, color: PixelPalette.slate),
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            padding: EdgeInsets.zero,
            onPressed: onDismiss,
          ),
        ),
    ];

    return GestureDetector(
      key: ValueKey('person_${person.id}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(person.profilePath),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(2)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stackActions =
                actions.isNotEmpty && (constraints.maxWidth < 360 && textScale >= 1.5);
            if (stackActions) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  SizedBox(height: grid.px(1)),
                  Wrap(
                    alignment: WrapAlignment.end,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: grid.px(1),
                    runSpacing: grid.px(1),
                    children: actions,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: identity),
                if (actions.isNotEmpty) ...[
                  SizedBox(width: grid.px(2)),
                  ...actions,
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
