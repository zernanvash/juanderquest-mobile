import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';

/// Owner 2026-11-16 (endpoints without a screen): the push queue already obeys
/// `/me/notification-preferences`; this lets travelers change them.
class SettingsNotificationsScreen extends ConsumerStatefulWidget {
  const SettingsNotificationsScreen({super.key});

  @override
  ConsumerState<SettingsNotificationsScreen> createState() =>
      _SettingsNotificationsScreenState();
}

class _Pref {
  const _Pref(this.key, this.en, this.tl, this.hintEn, this.hintTl);
  final String key;
  final String en;
  final String tl;
  final String hintEn;
  final String hintTl;
}

const _prefs = [
  _Pref(
    'push_overtaken',
    'Passed on the ranks',
    'Nalampasan sa ranggo',
    'When someone passes you on the weekly ranks',
    'Kapag may lumampas sa iyo sa lingguhang ranggo',
  ),
  _Pref(
    'push_friend_activity',
    'Friend activity',
    'Gawain ng kaibigan',
    'When people you follow finish quests',
    'Kapag may natapos na quest ang sinusundan mo',
  ),
  _Pref(
    'push_social',
    'Cheers and comments',
    'Cheers at komento',
    'Reactions, comments and new followers',
    'Reaksiyon, komento at bagong tagasunod',
  ),
  _Pref(
    'push_weekly_recap',
    'Weekly recap',
    'Lingguhang buod',
    'A short summary every Monday',
    'Maikling buod tuwing Lunes',
  ),
  _Pref(
    'quiet_hours',
    'Quiet hours',
    'Tahimik na oras',
    'Hold pushes from 9 PM until 8 AM',
    'Ipunin ang push mula 9 PM hanggang 8 AM',
  ),
];

class _SettingsNotificationsScreenState
    extends ConsumerState<SettingsNotificationsScreen> {
  Map<String, bool>? _values;
  String? _error;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .get('/me/notification-preferences');
      final data = res.data is Map ? res.data['data'] : null;
      if (data is! Map) throw const FormatException('bad response');
      if (!mounted) return;
      setState(
        () => _values = {for (final p in _prefs) p.key: data[p.key] != false},
      );
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    }
  }

  String _message(Object e) => e is FormatException
      ? "Couldn't load your notification settings."
      : ApiFailure.from(e).message;

  Future<void> _set(String key, bool value) async {
    final before = _values![key]!;
    setState(() {
      _values = {..._values!, key: value};
      _saving.add(key);
    });
    try {
      await ref
          .read(apiClientProvider)
          .dio
          .put('/me/notification-preferences', data: {key: value});
    } catch (e) {
      if (!mounted) return;
      setState(() => _values = {..._values!, key: before});
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text("Couldn't save. ${_message(e)}")));
    } finally {
      if (mounted) setState(() => _saving.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final values = _values;
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: tr(context, en: 'Notifications', tl: 'Mga Abiso'),
                    onBack: Navigator.of(context).canPop()
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.gutter,
                        grid.px(3),
                        grid.gutter,
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (values == null && _error == null)
                          const Center(
                            key: ValueKey('notif_loading'),
                            child: CircularProgressIndicator(),
                          ),
                        if (_error != null) ...[
                          Text(_error!, style: PixelType.body(context)),
                          SizedBox(height: grid.px(2)),
                          PixelButton(
                            key: const ValueKey('notif_retry'),
                            label: tr(
                              context,
                              en: 'Try again',
                              tl: 'Subukang muli',
                            ),
                            expand: true,
                            onPressed: _load,
                          ),
                        ],
                        if (values != null)
                          PixelPanel(
                            style: PixelBoxStyle.parchment,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                PixelSectionTitle(
                                  tr(
                                    context,
                                    en: 'Notification alerts',
                                    tl: 'Mga abiso',
                                  ),
                                  icon: DesignerArt.notifBell,
                                  value:
                                      '${values.values.where((v) => v).length}/${_prefs.length}',
                                  valueColor: PixelPalette.greenDark,
                                ),
                                SizedBox(height: grid.px(1)),
                                for (var i = 0; i < _prefs.length; i++) ...[
                                  if (i > 0)
                                    Container(
                                      height: grid.unit,
                                      color: PixelPalette.paperDim,
                                    ),
                                  KeyedSubtree(
                                    key: ValueKey('notif_${_prefs[i].key}'),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: grid.px(2)),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  tr(
                                                    context,
                                                    en: _prefs[i].en,
                                                    tl: _prefs[i].tl,
                                                  ),
                                                  style:
                                                      PixelType.title(context),
                                                ),
                                                Text(
                                                  tr(
                                                    context,
                                                    en: _prefs[i].hintEn,
                                                    tl: _prefs[i].hintTl,
                                                  ),
                                                  style: PixelType.small(
                                                    context,
                                                    color: PixelPalette.slate,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: grid.px(2)),
                                          PixelSwitch(
                                            key: ValueKey(
                                                'notif_switch_${_prefs[i].key}'),
                                            value: values[_prefs[i].key]!,
                                            semanticLabel: _prefs[i].en,
                                            onChanged: (v) {
                                              if (!_saving
                                                  .contains(_prefs[i].key)) {
                                                _set(_prefs[i].key, v);
                                              }
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
}
