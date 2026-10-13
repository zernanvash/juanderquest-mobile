import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../providers/spot_discovery_provider.dart';

class SavedSpotsScreen extends ConsumerStatefulWidget {
  const SavedSpotsScreen({super.key});

  @override
  ConsumerState<SavedSpotsScreen> createState() => _SavedSpotsScreenState();
}

class _SavedSpotsScreenState extends ConsumerState<SavedSpotsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(spotDiscoveryProvider.notifier).load());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotDiscoveryProvider);
    final saved = state.spots.where((spot) => spot.saved).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Destinations')),
      body: state.isInitialLoading && saved.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : saved.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.bookmark_border_rounded,
                          size: 44, color: AppColors.primary),
                      const SizedBox(height: 12),
                      Text('No saved destinations yet',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      const Text(
                          'Save a place while exploring and it will appear here.',
                          textAlign: TextAlign.center),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                          onPressed: () => context.go('/explore'),
                          icon: const Icon(Icons.explore_rounded),
                          label: const Text('Explore places')),
                    ]),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => ref
                      .read(spotDiscoveryProvider.notifier)
                      .load(refresh: true),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: saved.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final spot = saved[index];
                      return Card(
                        child: ListTile(
                          title: Text(spot.name,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(spot.municipality,
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                          leading: const Icon(Icons.place_outlined,
                              color: AppColors.primary),
                          trailing: IconButton(
                            tooltip: 'Remove saved destination',
                            icon: const Icon(Icons.bookmark_rounded,
                                color: AppColors.sunGold),
                            onPressed: () async => ref
                                .read(spotDiscoveryProvider.notifier)
                                .toggleSaved(spot),
                          ),
                          onTap: () => context.push(
                              '/explore/${Uri.encodeComponent(spot.slug)}',
                              extra: spot),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
