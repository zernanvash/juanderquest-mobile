import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/l10n/app_language.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_background.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_nav.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import 'recap_provider.dart';

/// Plan 62 Juander Recap (owner: "a baked dynamic ... summary of what they did
/// this ... season"): a swipeable story of the season or year, and a share
/// button that sends the current slide as an image.
class RecapScreen extends ConsumerStatefulWidget {
  const RecapScreen({super.key});

  @override
  ConsumerState<RecapScreen> createState() => _RecapScreenState();
}

class _RecapScreenState extends ConsumerState<RecapScreen> {
  /// null = this season.
  String? _period;
  final _pages = PageController();
  final _slideKey = GlobalKey();
  int _page = 0;
  bool _sharing = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _choose(String? period) {
    if (period == _period) return;
    setState(() {
      _period = period;
      _page = 0;
    });
    if (_pages.hasClients) _pages.jumpToPage(0);
  }

  Future<void> _share(Recap recap) async {
    final boundary =
        _slideKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || _sharing) return;
    setState(() => _sharing = true);
    try {
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/juander-recap-${_page + 1}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        text: 'My Juander Recap - ${recap.periodLabel} #JuanderQuest',
      ));
    } catch (_) {
      if (mounted) {
        showPixelToast(
            context,
            tr(context,
                en: 'Could not share this slide.',
                tl: 'Hindi maibahagi ang slide na ito.'));
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(recapProvider(_period));
    final yearPeriod = 'year:${DateTime.now().year}';
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(
              children: [
                PixelAppBar(
                  title: 'Juander Recap',
                  onBack: () => Navigator.of(context).canPop()
                      ? Navigator.of(context).maybePop()
                      : context.go('/profile'),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: grid.px(4), vertical: grid.px(2)),
                  child: Wrap(
                    spacing: grid.px(2),
                    runSpacing: grid.px(1),
                    children: [
                      PixelChip(
                        tr(context, en: 'This season', tl: 'Ngayong season'),
                        key: const ValueKey('recap_period_season'),
                        style: _period == null
                            ? PixelBoxStyle.gold
                            : PixelBoxStyle.parchment,
                        onTap: () => _choose(null),
                      ),
                      PixelChip(
                        tr(context, en: 'This year', tl: 'Ngayong taon'),
                        key: const ValueKey('recap_period_year'),
                        style: _period == yearPeriod
                            ? PixelBoxStyle.gold
                            : PixelBoxStyle.parchment,
                        onTap: () => _choose(yearPeriod),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: async.when(
                    loading: () => const Center(
                        child: PixelLoader(label: 'Making your recap')),
                    error: (_, __) => _centered(
                      grid,
                      PixelEmptyState(
                        key: const ValueKey('recap_error'),
                        title: tr(context,
                            en: 'Recap unavailable',
                            tl: 'Hindi makuha ang recap'),
                        message: tr(context,
                            en: 'Check your connection and try again.',
                            tl: 'Suriin ang koneksyon at subukang muli.'),
                        action: PixelButton(
                          key: const ValueKey('recap_retry'),
                          label: tr(context, en: 'Retry', tl: 'Subukan muli'),
                          onPressed: () =>
                              ref.invalidate(recapProvider(_period)),
                        ),
                      ),
                    ),
                    data: (recap) => recap.isEmpty
                        ? _centered(
                            grid,
                            PixelEmptyState(
                              key: const ValueKey('recap_empty'),
                              title: recap.periodLabel,
                              message: tr(context,
                                  en: 'Your story starts with your first quest.',
                                  tl: 'Nagsisimula ang kuwento mo sa unang quest.'),
                              action: PixelButton(
                                label: tr(context,
                                    en: 'Find a quest',
                                    tl: 'Maghanap ng quest'),
                                onPressed: () => context.go('/quests'),
                              ),
                            ),
                          )
                        : _story(context, grid, recap),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _centered(PixelGrid grid, Widget child) => Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(grid.px(4)),
          child: child,
        ),
      );

  Widget _story(BuildContext context, PixelGrid grid, Recap recap) {
    final slides = recapSlides(context, recap);
    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: const ValueKey('recap_pages'),
            controller: _pages,
            itemCount: slides.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: grid.px(4)),
                child: i == _page
                    ? RepaintBoundary(key: _slideKey, child: slides[i])
                    : slides[i],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(grid.px(4), grid.px(2), grid.px(4),
              grid.px(4) + MediaQuery.paddingOf(context).bottom),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '${_page + 1} / ${slides.length}',
                  style: PixelType.small(context, color: PixelPalette.slate),
                ),
              ),
              PixelButton(
                key: const ValueKey('recap_share'),
                label: tr(context, en: 'Share', tl: 'Ibahagi'),
                loading: _sharing,
                onPressed: _sharing ? null : () => _share(recap),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The story slides. Towns only: nothing here reveals a route, a time or a
/// place more exact than a town.
List<Widget> recapSlides(BuildContext context, Recap r) {
  Widget slide(
    String key,
    String kicker,
    String big,
    String caption, {
    PixelBoxStyle style = PixelBoxStyle.parchment,
    Color ink = PixelPalette.ink,
  }) =>
      Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        return PixelPanel(
          key: ValueKey('recap_slide_$key'),
          style: style,
          child: Padding(
            padding: EdgeInsets.all(grid.px(2)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(kicker.toUpperCase(),
                    style: PixelType.small(context, color: ink)),
                SizedBox(height: grid.px(3)),
                Text(big, style: PixelType.display(context, color: ink)),
                SizedBox(height: grid.px(2)),
                Text(caption, style: PixelType.body(context, color: ink)),
                SizedBox(height: grid.px(3)),
                Text('JuanderQuest - ${r.periodLabel}',
                    style: PixelType.small(context, color: ink)),
              ],
            ),
          ),
        );
      });

  final towns = r.towns.take(6).join(', ') +
      (r.towns.length > 6 ? ' +${r.towns.length - 6}' : '');
  return [
    slide(
      'intro',
      tr(context, en: 'Your Juander Recap', tl: 'Ang Juander Recap mo'),
      r.persona ?? tr(context, en: 'Explorer', tl: 'Manlalakbay'),
      tr(context,
          en: 'Here is how you travelled Pangasinan.',
          tl: 'Ganito mo nilakbay ang Pangasinan.'),
      style: PixelBoxStyle.green,
      ink: PixelPalette.white,
    ),
    slide(
      'quests',
      tr(context, en: 'Quests finished', tl: 'Natapos na quest'),
      '${r.questsCompleted}',
      tr(context,
          en: 'Every one of them a story.', tl: 'Bawat isa, may kuwento.'),
    ),
    slide(
      'towns',
      tr(context, en: 'Towns stamped', tl: 'Bayang natatakan'),
      '${r.towns.length} / ${r.townsTotal}',
      r.towns.isEmpty
          ? tr(context,
              en: 'Your passport is waiting.',
              tl: 'Naghihintay ang pasaporte mo.')
          : towns,
    ),
    slide(
      'community',
      tr(context, en: 'You gave back', tl: 'Nag-ambag ka'),
      '${r.spotsPosted + r.quizzesPassed}',
      tr(context,
          en: '${r.spotsPosted} places posted, ${r.quizzesPassed} quizzes passed',
          tl: '${r.spotsPosted} lugar na naipost, ${r.quizzesPassed} quiz na naipasa'),
    ),
    slide(
      'stamps',
      tr(context, en: 'Stamps earned', tl: 'Nakuhang tatak'),
      '${r.stampsEarned}',
      tr(context,
          en: 'Best streak: ${r.bestStreak} days',
          tl: 'Pinakamahabang streak: ${r.bestStreak} araw'),
      style: PixelBoxStyle.gold,
    ),
    slide(
      'next',
      tr(context, en: 'Where next?', tl: 'Saan susunod?'),
      r.whereNext ?? 'Pangasinan',
      tr(context,
          en: 'A town you have not stamped yet.',
          tl: 'Isang bayang hindi mo pa natatatakan.'),
    ),
  ];
}
