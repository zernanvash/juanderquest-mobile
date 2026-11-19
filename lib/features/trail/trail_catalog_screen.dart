import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import '../auth/providers/auth_provider.dart';
import '../trail_vlog/models/vlog_manifest.dart';
import '../trail_vlog/services/trail_vlog_vault.dart';
import '../trail_vlog/widgets/trail_vlog_studio_sheet.dart';
import 'models/trail_models.dart';
import 'services/trails_api.dart';

/// Plan 83c: the `/trail` catalog — Discover, My Trails and Create.
class TrailCatalogScreen extends ConsumerStatefulWidget {
  const TrailCatalogScreen({super.key});

  @override
  ConsumerState<TrailCatalogScreen> createState() => _TrailCatalogScreenState();
}

/// Spot categories the trail generator matches themes against.
const _themeOptions = [
  ('eat_drink', 'Food'),
  ('nature_outdoors', 'Nature'),
  ('culture_heritage', 'Heritage'),
  ('activities_wellness', 'Outdoor'),
  ('shopping_local', 'Crafts'),
];
const _paces = ['relaxed', 'balanced', 'packed'];
const _lengths = [120, 240, 360];

class _TrailCatalogScreenState extends ConsumerState<TrailCatalogScreen> {
  int _tab = 0;
  TrailCatalog? _catalog;
  String? _loadError;
  bool _loading = true;
  String? _busyTrailId;

  final _text = TextEditingController();
  final Set<String> _themes = {};
  int _pace = 1;
  int _length = 1;
  String _createKey = TrailsApi.newIdempotencyKey();
  bool _creating = false;
  String? _createError;
  List<TrailVlogManifest> _savedVlogs = const [];
  int _loadedVlogRev = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _loadSavedVlogs() async {
    try {
      final list = await ref.read(trailVlogVaultProvider).listAllVlogs();
      if (mounted) {
        setState(() => _savedVlogs = list);
      }
    } catch (_) {
      // Ignore in widget tests without platform path_provider.
    }
  }

  Future<void> _deleteVlog(TrailVlogManifest manifest) async {
    await ref.read(trailVlogVaultProvider).deleteTrailVlog(manifest.trailId);
    ref.read(trailVlogRevisionProvider.notifier).state++;
    _snack('Deleted local vlog for ${manifest.trailTitle}.');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final catalog = await ref.read(trailsApiProvider).fetchTrails();
      if (mounted) setState(() => _catalog = catalog);
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = TrailsApi.extractErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // A changed form is a new request, so it needs a new idempotency key.
  void _formChanged(VoidCallback change) {
    setState(() {
      change();
      _createKey = TrailsApi.newIdempotencyKey();
      _createError = null;
    });
  }

  Future<void> _openTrail(NearbyTrail trail) async {
    if (_busyTrailId != null) return;
    final api = ref.read(trailsApiProvider);
    if (!trail.isUnlocked) {
      if (!ref.read(authProvider).isAuthenticated) {
        _snack('Log in to start a trail');
        return;
      }
      final price = trail.unlockRule.pricePoints ?? 0;
      if (trail.unlockRule.type != 'free' && price > 0) {
        final ok = await showPixelDialog<bool>(
          context: context,
          title: 'Unlock ${trail.title}?',
          content: Text(
            'This trail costs $price points. You keep it after unlocking.',
            style: PixelType.body(context),
          ),
          actions: [
            PixelButton(
              label: 'Cancel',
              variant: PixelButtonVariant.secondary,
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(false),
            ),
            PixelButton(
              key: const ValueKey('trail_unlock_confirm'),
              label: 'Unlock',
              onPressed: () =>
                  Navigator.of(context, rootNavigator: true).pop(true),
            ),
          ],
        );
        if (ok != true || !mounted) return;
      }
    }
    setState(() => _busyTrailId = trail.id);
    try {
      if (!trail.isUnlocked) {
        await api.unlockTrail(trail.id);
        ref.read(authRefreshProvider).notify();
      }
      final detail = await api.fetchTrail(trail.id);
      if (!mounted) return;
      final query = <String, String>{'trail_id': detail.id};
      if (detail.stops.isNotEmpty) {
        final end = detail.stops.last;
        query['name'] = end.name;
        query['lat'] = end.lat.toString();
        query['lng'] = end.lng.toString();
      }
      context.push(Uri(path: '/navigate', queryParameters: query).toString());
      if (!trail.isUnlocked) _load();
    } catch (e) {
      _snack(TrailsApi.extractErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busyTrailId = null);
    }
  }

  Future<void> _create() async {
    if (_text.text.trim().isEmpty && _themes.isEmpty) {
      setState(() => _createError = 'Describe the trip or pick a theme.');
      return;
    }
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      await ref.read(trailsApiProvider).createPersonalTrail(
            idempotencyKey: _createKey,
            text: _text.text,
            themes: _themes.toList(),
            budgetMin: _lengths[_length],
            pace: _paces[_pace],
          );
      if (!mounted) return;
      ref.read(authRefreshProvider).notify();
      _text.clear();
      setState(() {
        _themes.clear();
        _createKey = TrailsApi.newIdempotencyKey();
        _tab = 1;
      });
      _snack('Trail created. Find it in My Trails.');
      await _load();
    } catch (e) {
      if (mounted) {
        setState(() => _createError = TrailsApi.extractErrorMessage(e));
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    showPixelToast(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final vlogRev = ref.watch(trailVlogRevisionProvider);
    if (_loadedVlogRev != vlogRev) {
      _loadedVlogRev = vlogRev;
      unawaited(_loadSavedVlogs());
    }
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
                    title: 'Trails',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      grid.px(4),
                      grid.px(2),
                      grid.px(4),
                      0,
                    ),
                    child: PixelSegmented(
                      key: const ValueKey('trail_tabs'),
                      items: const ['Discover', 'My Trails', 'Create'],
                      selectedIndex: _tab,
                      onChanged: (i) => setState(() => _tab = i),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: _tab == 2
                          ? _createChildren(context, grid)
                          : _listChildren(context, grid),
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

  List<Widget> _listChildren(BuildContext context, PixelGrid grid) {
    if (_loading && _catalog == null) {
      return const [
        Center(
          key: ValueKey('trail_loading'),
          child: PixelLoader(label: 'Loading trails'),
        ),
      ];
    }
    if (_loadError != null && _catalog == null) {
      return [
        Text(_loadError!, style: PixelType.body(context)),
        SizedBox(height: grid.px(2)),
        PixelButton(
          key: const ValueKey('trail_retry'),
          label: 'Try again',
          expand: true,
          onPressed: _load,
        ),
      ];
    }
    final items = _catalog?.items ?? const <NearbyTrail>[];
    final shown = _tab == 0
        ? items.where((t) => t.tier != TrailTier.personal).toList()
        : items
            .where((t) => t.tier == TrailTier.personal || t.isUnlocked)
            .toList();
    final vlogWidgets = <Widget>[
      if (_tab == 1 && _savedVlogs.isNotEmpty) ...[
        Text(
          'SAVED TRAIL VLOGS',
          key: const ValueKey('trail_saved_vlogs_section'),
          style: PixelType.title(context, color: PixelPalette.ink),
        ),
        SizedBox(height: grid.px(1.5)),
        for (final vlog in _savedVlogs) ...[
          _SavedVlogCard(
            manifest: vlog,
            onOpen: () => TrailVlogStudioSheet.show(
              context,
              manifest: vlog,
            ),
            onDelete: () => unawaited(_deleteVlog(vlog)),
          ),
          SizedBox(height: grid.px(1.5)),
        ],
        SizedBox(height: grid.px(1.5)),
      ],
    ];
    if (shown.isEmpty) {
      return [
        ...vlogWidgets,
        PixelPanel(
          key: const ValueKey('trail_empty'),
          style: PixelBoxStyle.parchment,
          child: Text(
            _tab == 0
                ? 'No trails are published yet.'
                : 'Trails you unlock or create show up here.',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ),
      ];
    }
    return [
      ...vlogWidgets,
      for (final trail in shown) ...[
        _TrailCard(
          trail: trail,
          busy: _busyTrailId == trail.id,
          onTap: () => _openTrail(trail),
        ),
        SizedBox(height: grid.px(2)),
      ],
    ];
  }

  List<Widget> _createChildren(BuildContext context, PixelGrid grid) {
    if (!ref.watch(authProvider).isAuthenticated) {
      return [
        PixelPanel(
          key: const ValueKey('trail_create_login'),
          style: PixelBoxStyle.parchment,
          child: Text(
            'Log in to create your own trail.',
            style: PixelType.body(context),
          ),
        ),
      ];
    }
    final gen = _catalog?.personalGeneration;
    if (gen == null) {
      return [
        PixelPanel(
          key: const ValueKey('trail_create_off'),
          style: PixelBoxStyle.parchment,
          child: Text(
            _loading
                ? 'Loading…'
                : 'Creating trails is not available right now.',
            style: PixelType.body(context),
          ),
        ),
      ];
    }
    final cost = gen.freeRemaining > 0
        ? 'Free this week: ${gen.freeRemaining} left'
        : 'Costs ${gen.pricePoints} points';
    return [
      Text('Describe your trip', style: PixelType.title(context)),
      SizedBox(height: grid.px(1)),
      TextField(
        key: const ValueKey('trail_create_text'),
        controller: _text,
        maxLength: 300,
        maxLines: 3,
        minLines: 2,
        onChanged: (_) => _formChanged(() {}),
        decoration: const InputDecoration(
          hintText: 'e.g. A slow beach day near Alaminos',
        ),
      ),
      SizedBox(height: grid.px(2)),
      Text('Themes', style: PixelType.title(context)),
      SizedBox(height: grid.px(1)),
      Wrap(
        spacing: grid.px(1),
        runSpacing: grid.px(1),
        children: [
          for (final (id, label) in _themeOptions)
            PixelChip(
              label,
              key: ValueKey('trail_theme_$id'),
              style: _themes.contains(id)
                  ? PixelBoxStyle.gold
                  : PixelBoxStyle.parchment,
              onTap: () => _formChanged(() {
                if (!_themes.remove(id)) _themes.add(id);
              }),
            ),
        ],
      ),
      SizedBox(height: grid.px(2)),
      Text('Pace', style: PixelType.title(context)),
      SizedBox(height: grid.px(1)),
      PixelSegmented(
        key: const ValueKey('trail_create_pace'),
        items: const ['Relaxed', 'Balanced', 'Packed'],
        selectedIndex: _pace,
        onChanged: (i) => _formChanged(() => _pace = i),
      ),
      SizedBox(height: grid.px(2)),
      Text('Length', style: PixelType.title(context)),
      SizedBox(height: grid.px(1)),
      PixelSegmented(
        key: const ValueKey('trail_create_length'),
        items: const ['2 hours', '4 hours', '6 hours'],
        selectedIndex: _length,
        onChanged: (i) => _formChanged(() => _length = i),
      ),
      SizedBox(height: grid.px(2)),
      Text(
        cost,
        key: const ValueKey('trail_create_cost'),
        style: PixelType.small(context, color: PixelPalette.slate),
      ),
      if (_createError != null) ...[
        SizedBox(height: grid.px(1)),
        Text(
          _createError!,
          key: const ValueKey('trail_create_error'),
          style: PixelType.body(context, color: PixelPalette.red),
        ),
      ],
      SizedBox(height: grid.px(2)),
      PixelButton(
        key: const ValueKey('trail_create_submit'),
        label: 'Create trail',
        expand: true,
        loading: _creating,
        onPressed: _creating ? null : _create,
      ),
    ];
  }
}

class _TrailCard extends StatelessWidget {
  const _TrailCard({
    required this.trail,
    required this.busy,
    required this.onTap,
  });

  final NearbyTrail trail;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final price = trail.unlockRule.pricePoints ?? 0;
    final status = trail.isUnlocked
        ? 'START'
        : (trail.unlockRule.type == 'free' || price == 0)
            ? 'FREE'
            : '$price PTS';
    final hours = (trail.totalMinutes / 60).toStringAsFixed(1);
    return Semantics(
      button: true,
      label: '${trail.title}, $status',
      child: GestureDetector(
        key: ValueKey('trail_card_${trail.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : onTap,
        child: PixelPanel(
          style:
              trail.tier.isHiyas ? PixelBoxStyle.wood : PixelBoxStyle.parchment,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      trail.tier.label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(
                        context,
                        color: trail.tier.isHiyas
                            ? PixelPalette.cream
                            : PixelPalette.slate,
                      ),
                    ),
                    Text(
                      trail.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.title(
                        context,
                        color: trail.tier.isHiyas
                            ? PixelPalette.paper
                            : PixelPalette.ink,
                      ),
                    ),
                    if (trail.tagline.isNotEmpty)
                      Text(
                        trail.tagline,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(
                          context,
                          color: trail.tier.isHiyas
                              ? PixelPalette.cream
                              : PixelPalette.slate,
                        ),
                      ),
                    SizedBox(height: grid.px(1)),
                    Text(
                      '${trail.stopCount} stops · $hours h · '
                      '${trail.totalKm.toStringAsFixed(1)} km',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.small(
                        context,
                        color: trail.tier.isHiyas
                            ? PixelPalette.cream
                            : PixelPalette.slate,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: grid.px(2)),
              busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: PixelLoader(),
                    )
                  : PixelChip(
                      status,
                      style: trail.isUnlocked
                          ? PixelBoxStyle.green
                          : PixelBoxStyle.gold,
                      textColor: trail.isUnlocked
                          ? PixelPalette.paper
                          : PixelPalette.ink,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SavedVlogCard extends StatelessWidget {
  const _SavedVlogCard({
    required this.manifest,
    required this.onOpen,
    required this.onDelete,
  });

  final TrailVlogManifest manifest;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final mb = manifest.compiledSizeBytes != null
        ? ' · ${(manifest.compiledSizeBytes! / (1024 * 1024)).toStringAsFixed(1)} MB'
        : '';
    return PixelPanel(
      key: ValueKey('trail_vlog_card_${manifest.trailId}'),
      style: PixelBoxStyle.parchment,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  manifest.trailTitle.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.body(context, color: PixelPalette.ink)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${manifest.totalClips} CLIPS · ${manifest.totalStops} STOPS$mb',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          SizedBox(width: grid.px(1)),
          PixelChip(
            'OPEN',
            key: ValueKey('trail_vlog_open_${manifest.trailId}'),
            style: PixelBoxStyle.gold,
            onTap: onOpen,
          ),
          SizedBox(width: grid.px(1)),
          PixelChip(
            'DEL',
            key: ValueKey('trail_vlog_del_${manifest.trailId}'),
            style: PixelBoxStyle.red,
            textColor: PixelPalette.paper,
            onTap: onDelete,
          ),
        ],
      ),
    );
  }
}
