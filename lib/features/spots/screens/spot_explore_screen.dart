import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';
import '../providers/spot_discovery_provider.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});
  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen> {
  final search = TextEditingController();
  Timer? _debounce;
  String category = '';
  String intent = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => ref.read(spotDiscoveryProvider.notifier).initialize());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) =>
      ref.read(spotDiscoveryProvider.notifier).load(
          query: search.text,
          category: category,
          intent: intent,
          refresh: refresh);

  void _searchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final categories = state.categories.isEmpty
        ? const [
            'eat_drink',
            'nature_outdoors',
            'culture_heritage',
            'activities_wellness'
          ]
        : state.categories;
    final intents = state.intents.isEmpty
        ? const [
            'coffee',
            'local_food',
            'family',
            'quiet',
            'running',
            'hidden_gem'
          ]
        : state.intents.take(8).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Explore Pangasinan'), actions: [
        IconButton(
            icon: const Icon(Icons.add_a_photo),
            tooltip: 'Add destination',
            onPressed: () async {
              final added = await context.push<bool>('/spots/new');
              if (added == true) _load(refresh: true);
            })
      ]),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
                controller: search,
                onChanged: _searchChanged,
                onSubmitted: (_) => _load(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    hintText: 'Coffee, beaches, running...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: search.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            tooltip: 'Clear search',
                            onPressed: () {
                              search.clear();
                              _load();
                            }),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16)))),
            const SizedBox(height: 14),
            _FilterRow(
                values: ['', ...categories],
                selected: category,
                allLabel: 'All',
                onSelected: (value) {
                  setState(() => category = value);
                  _load();
                }),
            const SizedBox(height: 10),
            _FilterRow(
                values: intents,
                selected: intent,
                onSelected: (value) {
                  setState(() => intent = intent == value ? '' : value);
                  _load();
                }),
            if (state.isRefreshing)
              const Padding(
                  padding: EdgeInsets.only(top: 12),
                  child: LinearProgressIndicator(minHeight: 2)),
            const SizedBox(height: 16),
            if (state.failure != null && state.spots.isNotEmpty)
              _InlineNotice(
                  message: state.failure!.message,
                  onRetry: () => _load(refresh: true)),
            if (state.isInitialLoading)
              const _DestinationSkeleton()
            else if (state.failure != null && state.spots.isEmpty)
              _FullFailure(
                  message: state.failure!.message,
                  onRetry: () => _load(refresh: true))
            else if (state.spots.isEmpty)
              const _EmptyDiscovery()
            else ...[
              Row(children: [
                Expanded(
                    child: Text('${state.count} destinations',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold))),
                if (state.trending.isNotEmpty)
                  const Chip(
                      avatar: Icon(Icons.trending_up, size: 16),
                      label: Text('Trending updated'))
              ]),
              const SizedBox(height: 8),
              ...state.spots.map((spot) => Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: CircleAvatar(
                          child: Icon(spot.category == 'eat_drink'
                              ? Icons.restaurant
                              : Icons.place)),
                      title: Row(children: [
                        Expanded(
                            child: Text(spot.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        _CrowdBadge(spot: spot)
                      ]),
                      subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                              '${spot.municipality}${spot.distanceKm == null ? '' : ' · ${spot.distanceKm!.toStringAsFixed(1)} km'}\n${spot.reasons.take(2).join(' · ')}')),
                      trailing: IconButton(
                          icon: state.savingIds.contains(spot.id)
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : Icon(spot.saved
                                  ? Icons.bookmark
                                  : Icons.bookmark_border),
                          tooltip: spot.saved
                              ? 'Remove saved destination'
                              : 'Save destination',
                          onPressed: state.savingIds.contains(spot.id)
                              ? null
                              : () async {
                                  final failure = await ref
                                      .read(spotDiscoveryProvider.notifier)
                                      .toggleSaved(spot);
                                  if (failure != null && context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                            content: Text(failure.message)));
                                  }
                                }),
                      onTap: () =>
                          context.push('/explore/${spot.slug}', extra: spot),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final List<String> values;
  final String selected;
  final String allLabel;
  final ValueChanged<String> onSelected;
  const _FilterRow(
      {required this.values,
      required this.selected,
      required this.onSelected,
      this.allLabel = ''});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
          children: values
              .map((value) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                      label: Text(value.isEmpty
                          ? allLabel
                          : value.replaceAll('_', ' ')),
                      selected: selected == value,
                      onSelected: (_) => onSelected(value))))
              .toList()));
}

class _CrowdBadge extends StatelessWidget {
  final SpotModel spot;
  const _CrowdBadge({required this.spot});
  @override
  Widget build(BuildContext context) => Chip(
      label: Text(spot.crowdStatus == 'estimated_busy'
          ? 'Estimated busy'
          : spot.crowdStatus == 'unknown'
              ? 'Crowd unknown'
              : spot.crowdStatus.replaceAll('_', ' ')),
      visualDensity: VisualDensity.compact);
}

class _InlineNotice extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineNotice({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: ListTile(
          leading: const Icon(Icons.cloud_off),
          title: Text(message),
          trailing:
              TextButton(onPressed: onRetry, child: const Text('Retry'))));
}

class _FullFailure extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _FullFailure({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 64),
      child: Column(children: [
        const Icon(Icons.travel_explore, size: 56),
        const SizedBox(height: 12),
        Text(message, textAlign: TextAlign.center),
        TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try again'))
      ]));
}

class _DestinationSkeleton extends StatelessWidget {
  const _DestinationSkeleton();
  @override
  Widget build(BuildContext context) => Column(
      children: List.generate(
          3,
          (_) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(children: [
                    Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: Column(children: [
                      LinearProgressIndicator(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest)
                    ]))
                  ])))));
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery();
  @override
  Widget build(BuildContext context) => const Padding(
      padding: EdgeInsets.symmetric(vertical: 64),
      child: Column(children: [
        Icon(Icons.map_outlined, size: 56),
        SizedBox(height: 12),
        Text('No destinations match these filters.',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SizedBox(height: 4),
        Text('Try a broader search or another travel mood.')
      ]));
}
