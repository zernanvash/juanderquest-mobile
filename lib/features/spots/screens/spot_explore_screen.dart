import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/spot_model.dart';

class SpotExploreScreen extends ConsumerStatefulWidget {
  const SpotExploreScreen({super.key});
  @override
  ConsumerState<SpotExploreScreen> createState() => _SpotExploreScreenState();
}

class _SpotExploreScreenState extends ConsumerState<SpotExploreScreen> {
  List<SpotModel> spots = [];
  bool loading = true;
  String? error;
  String category = '';
  String intent = '';
  final search = TextEditingController();

  @override
  void initState() { super.initState(); Future.microtask(load); }
  @override
  void dispose() { search.dispose(); super.dispose(); }

  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final response = await ref.read(apiClientProvider).dio.get('/spots', queryParameters: {
        if (category.isNotEmpty) 'categories': category,
        if (intent.isNotEmpty) 'intent': intent,
        if (search.text.isNotEmpty) 'q': search.text,
      });
      setState(() => spots = (response.data['data'] as List).map((item) => SpotModel.fromJson(item)).toList());
    } catch (_) {
      setState(() => error = 'Could not load destination spots.');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Explore Pangasinan'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add_a_photo),
          tooltip: 'Add Spot',
          onPressed: () async {
            final added = await context.push<bool>('/spots/new');
            if (added == true) load();
          },
        ),
      ],
    ),
    body: RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: search, onSubmitted: (_) => load(), decoration: InputDecoration(hintText: 'Coffee, beaches, running...', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(icon: const Icon(Icons.tune), onPressed: load), border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)))),
          const SizedBox(height: 14),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['', 'eat_drink', 'nature_outdoors', 'culture_heritage', 'activities_wellness'].map((value) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(value.isEmpty ? 'All' : value.replaceAll('_', ' ')), selected: category == value, onSelected: (_) { setState(() => category = value); load(); }))).toList())),
          const SizedBox(height: 10),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: ['coffee', 'local_food', 'family', 'quiet', 'running', 'hidden_gem'].map((value) => Padding(padding: const EdgeInsets.only(right: 8), child: FilterChip(label: Text(value.replaceAll('_', ' ')), selected: intent == value, onSelected: (_) { setState(() => intent = intent == value ? '' : value); load(); }))).toList())),
          const SizedBox(height: 18),
          if (loading) const Center(child: Padding(padding: EdgeInsets.all(50), child: CircularProgressIndicator()))
          else if (error != null) Center(child: Text(error!))
          else ...spots.map((spot) => Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Icon(spot.category == 'eat_drink' ? Icons.restaurant : Icons.place)),
              title: Text(spot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Padding(padding: const EdgeInsets.only(top: 6), child: Text('${spot.municipality}${spot.distanceKm == null ? '' : ' - ${spot.distanceKm!.toStringAsFixed(1)} km'}\n${spot.reasons.take(2).join(' - ')}')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/explore/${spot.slug}', extra: spot),
            ),
          )),
        ],
      ),
    ),
  );
}

class SpotDetailScreen extends StatelessWidget {
  final SpotModel spot;
  const SpotDetailScreen({super.key, required this.spot});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(spot.name)),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Icon(Icons.location_on, size: 90, color: Theme.of(context).colorScheme.primary),
      Text(spot.name, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
      Text(spot.address), const SizedBox(height: 18), Text(spot.description), const SizedBox(height: 18),
      Wrap(spacing: 8, children: spot.tags.map((tag) => Chip(label: Text(tag.replaceAll('_', ' ')))).toList()),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: () => launchDirections(spot), icon: const Icon(Icons.directions), label: const Text('Open directions')),
      if (spot.questId != null) Padding(padding: const EdgeInsets.only(top: 10), child: FilledButton.tonalIcon(onPressed: () => context.push('/quests/${spot.questId}'), icon: const Icon(Icons.emoji_events), label: const Text('Play this quest'))),
      const SizedBox(height: 16), Text('Source: ${spot.sourceName}', style: Theme.of(context).textTheme.bodySmall),
    ]),
  );
}

Future<void> launchDirections(SpotModel spot) => launchUrl(Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${spot.gpsLat},${spot.gpsLng}'), mode: LaunchMode.externalApplication);
