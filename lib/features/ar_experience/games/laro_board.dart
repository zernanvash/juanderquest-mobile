import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../core/ar_task.dart';
import 'ar_game_factory.dart';

/// Plan 77 WP-4: the "Laro ng Lahi" boards, for fun only (owner: no badges,
/// no rewards). Pangasinan this week per game, and the top at one place.
class LaroBoard {
  final List<ArBoardEntry> entries;
  final ArBoardEntry? me;
  final bool lowerIsBetter;
  const LaroBoard({this.entries = const [], this.me, this.lowerIsBetter = false});

  factory LaroBoard.fromJson(Map<String, dynamic> j) => LaroBoard(
        entries: [
          for (final e in (j['entries'] as List? ?? const []))
            if (e is Map) ArBoardEntry.fromJson(Map<String, dynamic>.from(e)),
        ],
        me: j['me'] is Map ? ArBoardEntry.fromJson(Map<String, dynamic>.from(j['me'] as Map)) : null,
        lowerIsBetter: j['lower_is_better'] == true,
      );

  /// Palayok is a time (lower is better); the rest are points or kicks.
  String show(int score) => lowerIsBetter ? '${(score / 1000).toStringAsFixed(1)} s' : '$score';
}

/// Key: `week:<game>` or `place:<questId>:<taskKey>`.
final laroBoardProvider = FutureProvider.autoDispose.family<LaroBoard, String>((ref, key) async {
  final api = ref.watch(apiClientProvider);
  final parts = key.split(':');
  final query = parts.first == 'place' && parts.length >= 3
      ? {'quest_id': parts[1], 'task_key': parts.sublist(2).join(':'), 'limit': 5}
      : {'game': parts.length > 1 ? parts[1] : 'tumbang_preso', 'scope': 'week', 'limit': 20};
  final res = await api.dio.get('/ar-games/leaderboard', queryParameters: query);
  final data = res.data is Map ? res.data['data'] : null;
  return data is Map ? LaroBoard.fromJson(Map<String, dynamic>.from(data)) : const LaroBoard();
});

/// Pangasinan this week, one board per game.
class LaroBoardScreen extends ConsumerStatefulWidget {
  const LaroBoardScreen({super.key, this.initialGame = 'tumbang_preso'});
  final String initialGame;

  @override
  ConsumerState<LaroBoardScreen> createState() => _LaroBoardScreenState();
}

class _LaroBoardScreenState extends ConsumerState<LaroBoardScreen> {
  late String _game = ArTaskSpec.games.contains(widget.initialGame) ? widget.initialGame : ArTaskSpec.games.first;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(builder: (context) {
        final grid = PixelGrid.of(context);
        final board = ref.watch(laroBoardProvider('week:$_game'));
        return Scaffold(
          backgroundColor: PixelPalette.paper,
          body: DitherBackground(
            top: PixelPalette.paper,
            bottom: PixelPalette.parchment,
            child: Column(children: [
              PixelAppBar(
                title: 'Laro boards',
                onBack: Navigator.of(context).canPop() ? () => Navigator.of(context).maybePop() : null,
              ),
              Expanded(
                child: ListView(
                  key: const ValueKey('laro_board_list'),
                  padding: EdgeInsets.fromLTRB(
                      grid.px(4), grid.px(3), grid.px(4), grid.px(8) + MediaQuery.paddingOf(context).bottom),
                  children: [
                    Text('This week in Pangasinan. Just for fun.',
                        style: PixelType.body(context, color: PixelPalette.slate)),
                    SizedBox(height: grid.px(2)),
                    Wrap(spacing: grid.px(1), runSpacing: grid.px(1), children: [
                      for (final g in ArTaskSpec.games)
                        PixelChip(
                          arGameInfo[g]!.name,
                          key: ValueKey('laro_game_$g'),
                          style: g == _game ? PixelBoxStyle.gold : PixelBoxStyle.parchment,
                          textColor: g == _game ? PixelPalette.ink : PixelPalette.slate,
                          onTap: () => setState(() => _game = g),
                        ),
                    ]),
                    SizedBox(height: grid.px(3)),
                    board.when(
                      loading: () => const Center(child: PixelLoader(label: 'Loading board')),
                      error: (_, __) => PixelPanel(
                        style: PixelBoxStyle.red,
                        child: Text('The board could not load. Try again later.',
                            style: PixelType.body(context, color: PixelPalette.white)),
                      ),
                      data: (b) => LaroBoardRows(board: b, grid: grid),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        );
      }),
    );
  }
}

/// The ranked rows, plus "you" when you are below the top.
class LaroBoardRows extends StatelessWidget {
  const LaroBoardRows({super.key, required this.board, required this.grid});
  final LaroBoard board;
  final PixelGrid grid;

  @override
  Widget build(BuildContext context) {
    if (board.entries.isEmpty) {
      return PixelPanel(
        child: Text('No games yet this week. Play one at a quest to start the board.',
            style: PixelType.body(context, color: PixelPalette.slate)),
      );
    }
    final me = board.me;
    final meShown = me != null && board.entries.any((e) => e.isSelf);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final e in board.entries) ...[_row(context, e), SizedBox(height: grid.px(1))],
      if (me != null && !meShown) ...[SizedBox(height: grid.px(1)), _row(context, me)],
    ]);
  }

  Widget _row(BuildContext context, ArBoardEntry e) => PixelPanel(
        style: e.isSelf ? PixelBoxStyle.green : PixelBoxStyle.parchment,
        child: Row(children: [
          PixelChip('#${e.rank}', style: e.rank <= 3 ? PixelBoxStyle.gold : PixelBoxStyle.slot),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Text(e.isSelf ? '${e.name} (you)' : e.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: PixelType.title(context, color: e.isSelf ? PixelPalette.white : PixelPalette.ink)),
          ),
          SizedBox(width: grid.px(2)),
          Text(board.show(e.score),
              style: PixelType.numbers(context, color: e.isSelf ? PixelPalette.white : PixelPalette.greenDark)),
        ]),
      );
}

/// "TOP AT THIS PLACE" on a game task (top 5, all-time); hidden until someone plays.
class LaroPlaceBoard extends ConsumerWidget {
  const LaroPlaceBoard({super.key, required this.questId, required this.taskKey});
  final String questId;
  final String taskKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final board = ref.watch(laroBoardProvider('place:$questId:$taskKey')).valueOrNull;
    if (board == null || board.entries.isEmpty) return const SizedBox.shrink();
    final small = PixelType.small(context, color: PixelPalette.slate);
    return Column(key: const ValueKey('laro_place_board'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 6),
      Text('TOP AT THIS PLACE', style: small.copyWith(fontWeight: FontWeight.w800)),
      for (final e in board.entries.take(5))
        Text('${e.rank}. ${e.name}  ${board.show(e.score)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: PixelType.small(context, color: e.isSelf ? PixelPalette.greenDeep : PixelPalette.ink)),
    ]);
  }
}
