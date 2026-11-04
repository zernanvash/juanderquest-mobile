import 'package:flutter/material.dart';
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

/// Plan 75j step 1: three Home layouts to choose from, with the same realistic
/// sample data so the owner can compare what the traveler sees.
enum HomeOptionLayout { characterSheet, questLog, hud }

enum HomeGroup {
  identity,
  wallet,
  travel,
  quests,
  proof,
  collection,
  community
}

class HomeQuestItem {
  const HomeQuestItem({
    required this.title,
    required this.done,
    required this.total,
  });

  final String title;
  final int done;
  final int total;
}

class HomeOptionData {
  const HomeOptionData({
    required this.name,
    required this.handle,
    required this.avatarInitial,
    required this.title,
    required this.points,
    required this.level,
    required this.xpDone,
    required this.xpGoal,
    required this.mjdq,
    required this.jdq,
    required this.scoutReputation,
    required this.streakDays,
    required this.verifiedVisits,
    required this.destinations,
    required this.municipalities,
    required this.inProgress,
    required this.completedQuests,
    this.dailyMissionTitle,
    this.dailyMissionDone = 0,
    this.dailyMissionGoal = 1,
    required this.pendingProofs,
    required this.approvedProofs,
    required this.rejectedProofs,
    this.latestProofTitle,
    this.latestProofStatus,
    required this.stamps,
    required this.badges,
    required this.savedSpots,
    required this.votedThisWeek,
    required this.voteDaysLeft,
    this.leaderboardRank,
  });

  final String name;
  final String handle;
  final String avatarInitial;
  final String title;
  final int points;
  final int level;
  final int xpDone;
  final int xpGoal;
  final int mjdq;
  final int jdq;
  final int scoutReputation;
  final int streakDays;
  final int verifiedVisits;
  final int destinations;
  final int municipalities;
  final List<HomeQuestItem> inProgress;
  final int completedQuests;
  final String? dailyMissionTitle;
  final int dailyMissionDone;
  final int dailyMissionGoal;
  final int pendingProofs;
  final int approvedProofs;
  final int rejectedProofs;
  final String? latestProofTitle;
  final String? latestProofStatus;
  final int stamps;
  final int badges;
  final int savedSpots;
  final bool votedThisWeek;
  final int voteDaysLeft;
  final int? leaderboardRank;

  bool get isEmpty =>
      points == 0 &&
      mjdq == 0 &&
      jdq == 0 &&
      scoutReputation == 0 &&
      streakDays == 0 &&
      verifiedVisits == 0 &&
      destinations == 0 &&
      municipalities == 0 &&
      inProgress.isEmpty &&
      completedQuests == 0 &&
      dailyMissionTitle == null &&
      pendingProofs == 0 &&
      approvedProofs == 0 &&
      rejectedProofs == 0 &&
      stamps == 0 &&
      badges == 0 &&
      savedSpots == 0 &&
      leaderboardRank == null;
}

const sampleHomeOptionData = HomeOptionData(
  name: 'Juan Dela Cruz',
  handle: '@juan_demo',
  avatarInitial: 'J',
  title: 'Heritage Keeper',
  points: 1254,
  level: 26,
  xpDone: 4,
  xpGoal: 50,
  mjdq: 125400,
  jdq: 12,
  scoutReputation: 350,
  streakDays: 4,
  verifiedVisits: 18,
  destinations: 7,
  municipalities: 5,
  inProgress: [
    HomeQuestItem(title: 'Hundred Islands Eco Trek', done: 2, total: 3),
    HomeQuestItem(title: 'Manaoag Heritage Walk', done: 1, total: 2),
  ],
  completedQuests: 14,
  dailyMissionTitle: 'Check in at Patar Beach',
  dailyMissionDone: 0,
  dailyMissionGoal: 1,
  pendingProofs: 1,
  approvedProofs: 17,
  rejectedProofs: 1,
  latestProofTitle: 'Patar Beach Cleanup',
  latestProofStatus: 'approved',
  stamps: 12,
  badges: 5,
  savedSpots: 9,
  votedThisWeek: true,
  voteDaysLeft: 2,
  leaderboardRank: 7,
);

const emptyHomeOptionData = HomeOptionData(
  name: 'New Traveler',
  handle: '@new_traveler',
  avatarInitial: 'N',
  title: 'New Explorer',
  points: 0,
  level: 1,
  xpDone: 0,
  xpGoal: 50,
  mjdq: 0,
  jdq: 0,
  scoutReputation: 0,
  streakDays: 0,
  verifiedVisits: 0,
  destinations: 0,
  municipalities: 0,
  inProgress: [],
  completedQuests: 0,
  pendingProofs: 0,
  approvedProofs: 0,
  rejectedProofs: 0,
  stamps: 0,
  badges: 0,
  savedSpots: 0,
  votedThisWeek: false,
  voteDaysLeft: 0,
);

/// The Pixel lab section: three cards, each opening a full-screen preview.
class HomeOptionsSection extends StatelessWidget {
  const HomeOptionsSection({super.key, this.data = sampleHomeOptionData});

  final HomeOptionData data;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    Widget card(
        HomeOptionLayout layout, String letter, String title, String body) {
      return GestureDetector(
        key: ValueKey('home_option_${letter.toLowerCase()}'),
        onTap: () => Navigator.of(context).push(
          pixelRoute(
            HomeOptionPreview(
              layout: layout,
              data: data,
              onRetry: () {},
            ),
          ),
        ),
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PixelChip(letter),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: Text(title, style: PixelType.title(context)),
                  ),
                ],
              ),
              SizedBox(height: grid.px(1)),
              Text(
                body,
                style: PixelType.body(context, color: PixelPalette.slate),
              ),
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: ValueKey('home_option_${letter.toLowerCase()}_open'),
                label: 'Open full screen',
                expand: true,
                onPressed: () => Navigator.of(context).push(
                  pixelRoute(
                    HomeOptionPreview(
                      layout: layout,
                      data: data,
                      onRetry: () {},
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Tap A, B or C to open a full-screen preview with sample data for every group below.',
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(2)),
        card(
          HomeOptionLayout.characterSheet,
          'A',
          'Character sheet (RPG)',
          'Avatar, level, XP and wallet beside a Hypixel-style scoreboard grid, then in-progress quests and the latest proof.',
        ),
        SizedBox(height: grid.px(2)),
        card(
          HomeOptionLayout.questLog,
          'B',
          'Quest log (3 wood tabs)',
          'Compact hero, then Progress / Quests / Collection as wood tabs with a short list in each.',
        ),
        SizedBox(height: grid.px(2)),
        card(
          HomeOptionLayout.hud,
          'C',
          'HUD',
          'A single scroll of small panels: icon stat strip, today’s mission, quests, proof and community.',
        ),
      ],
    );
  }
}

/// A complete full-screen Home layout preview.
class HomeOptionPreview extends StatelessWidget {
  const HomeOptionPreview({
    super.key,
    required this.layout,
    this.data = sampleHomeOptionData,
    this.failed = const {},
    this.onRetry,
  });

  final HomeOptionLayout layout;
  final HomeOptionData data;
  final Set<HomeGroup> failed;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Home · ${_label(layout)}',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: switch (layout) {
                        HomeOptionLayout.characterSheet =>
                          _characterSheet(context, grid),
                        HomeOptionLayout.questLog => _questLog(context, grid),
                        HomeOptionLayout.hud => _hud(context, grid),
                      },
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

  static String _label(HomeOptionLayout layout) => switch (layout) {
        HomeOptionLayout.characterSheet => 'A Character Sheet',
        HomeOptionLayout.questLog => 'B Quest Log',
        HomeOptionLayout.hud => 'C HUD',
      };

  // ---------------------------------------------------------------- A
  List<Widget> _characterSheet(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.identity,
        _avatarHeader(context, grid, dense: false),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.wallet,
        _walletPanel(context, grid, 'A'),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.travel,
        _scoreGrid(context, grid, 'A', [
          ('Streak', '${data.streakDays} days', '/profile', 'streak'),
          ('Verified visits', '${data.verifiedVisits}', '/profile', 'visits'),
          ('Destinations', '${data.destinations}', '/profile', 'destinations'),
          (
            'Municipalities',
            '${data.municipalities}',
            '/profile',
            'municipalities'
          ),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.quests,
        _scoreGrid(context, grid, 'A', [
          (
            'In progress',
            '${data.inProgress.length}',
            '/quests',
            'in_progress'
          ),
          ('Completed', '${data.completedQuests}', '/quests', 'completed'),
          (
            'Daily mission',
            data.dailyMissionTitle == null
                ? 'None today'
                : '${data.dailyMissionDone}/${data.dailyMissionGoal}',
            '/quests',
            'daily',
          ),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.proof,
        _scoreGrid(context, grid, 'A', [
          ('Pending', '${data.pendingProofs}', '/history', 'pending'),
          ('Approved', '${data.approvedProofs}', '/history', 'approved'),
          ('Rejected', '${data.rejectedProofs}', '/history', 'rejected'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.collection,
        _scoreGrid(context, grid, 'A', [
          ('Stamps', '${data.stamps}', '/profile', 'stamps'),
          ('Badges', '${data.badges}', '/profile', 'badges'),
          ('Saved spots', '${data.savedSpots}', '/saved', 'saved'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.community,
        _communityPanel(context, grid),
      ),
      SizedBox(height: grid.px(3)),
      _questList(context, grid),
      SizedBox(height: grid.px(2)),
      _latestProof(context, grid),
      SizedBox(height: grid.px(3)),
      _nextStop(context, grid),
    ];
  }

  // ---------------------------------------------------------------- B
  List<Widget> _questLog(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.identity,
        _avatarHeader(context, grid, dense: true),
      ),
      SizedBox(height: grid.px(2)),
      _QuestLogTabs(
        progress: (c, g) => _progressTab(c, g),
        quests: (c, g) => _questsTab(c, g),
        collection: (c, g) => _collectionTab(c, g),
      ),
    ];
  }

  List<Widget> _progressTab(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.wallet,
        _walletPanel(context, grid, 'B'),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.travel,
        _listRows(context, 'B', [
          ('Visit streak', '${data.streakDays} days', '/profile', 'streak'),
          ('Verified visits', '${data.verifiedVisits}', '/profile', 'visits'),
          ('Destinations', '${data.destinations}', '/profile', 'destinations'),
          (
            'Municipalities',
            '${data.municipalities}',
            '/profile',
            'municipalities',
          ),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.proof,
        _listRows(context, 'B', [
          ('Pending proofs', '${data.pendingProofs}', '/history', 'pending'),
          ('Approved', '${data.approvedProofs}', '/history', 'approved'),
          ('Rejected', '${data.rejectedProofs}', '/history', 'rejected'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.community,
        _communityPanel(context, grid),
      ),
      SizedBox(height: grid.px(2)),
      _nextStop(context, grid),
    ];
  }

  List<Widget> _questsTab(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.quests,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.dailyMissionTitle != null)
              PixelPanel(
                style: PixelBoxStyle.gold,
                child: Text(
                  'Today · ${data.dailyMissionTitle}',
                  style: PixelType.body(context),
                ),
              ),
            if (data.dailyMissionTitle != null) SizedBox(height: grid.px(2)),
            _listRows(context, 'B', [
              (
                'In progress',
                '${data.inProgress.length}',
                '/quests',
                'in_progress'
              ),
              ('Completed', '${data.completedQuests}', '/quests', 'completed'),
            ]),
            SizedBox(height: grid.px(2)),
            if (data.inProgress.isEmpty)
              _empty(context, 'No quests in progress yet.')
            else
              for (final quest in data.inProgress) ...[
                _questRow(context, grid, quest),
                SizedBox(height: grid.px(1)),
              ],
          ],
        ),
      ),
    ];
  }

  List<Widget> _collectionTab(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.collection,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _listRows(context, 'B', [
              ('Passport stamps', '${data.stamps}', '/profile', 'stamps'),
              ('Badges', '${data.badges}', '/profile', 'badges'),
              ('Saved spots', '${data.savedSpots}', '/saved', 'saved'),
            ]),
            if (data.stamps == 0 &&
                data.badges == 0 &&
                data.savedSpots == 0) ...[
              SizedBox(height: grid.px(2)),
              _empty(context, 'Your passport is waiting for its first stamp.'),
            ],
          ],
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------- C
  List<Widget> _hud(BuildContext context, PixelGrid grid) {
    return [
      _group(
        context,
        grid,
        HomeGroup.identity,
        _avatarHeader(context, grid, dense: true),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.wallet,
        _hudStrip(context, grid, 'C', [
          ('mJDQ', '${data.mjdq}', '/profile', 'mjdq'),
          ('JDQ', '${data.jdq}', '/profile', 'jdq'),
          ('REP', '${data.scoutReputation}', '/profile', 'rep'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.travel,
        _hudStrip(context, grid, 'C', [
          ('Streak', '${data.streakDays}', '/profile', 'streak'),
          ('Visits', '${data.verifiedVisits}', '/profile', 'visits'),
          ('Places', '${data.destinations}', '/profile', 'destinations'),
          ('Towns', '${data.municipalities}', '/profile', 'municipalities'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.quests,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (data.dailyMissionTitle != null)
              PixelPanel(
                style: PixelBoxStyle.gold,
                child: Text(
                  'Today · ${data.dailyMissionTitle}',
                  style: PixelType.body(context),
                ),
              ),
            if (data.dailyMissionTitle != null) SizedBox(height: grid.px(2)),
            for (final quest in data.inProgress) ...[
              _questRow(context, grid, quest),
              SizedBox(height: grid.px(1)),
            ],
            if (data.inProgress.isEmpty)
              _empty(context, 'No quests in progress yet.'),
          ],
        ),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.proof,
        _hudStrip(context, grid, 'C', [
          ('Pending', '${data.pendingProofs}', '/history', 'pending'),
          ('Approved', '${data.approvedProofs}', '/history', 'approved'),
          ('Rejected', '${data.rejectedProofs}', '/history', 'rejected'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.collection,
        _hudStrip(context, grid, 'C', [
          ('Stamps', '${data.stamps}', '/profile', 'stamps'),
          ('Badges', '${data.badges}', '/profile', 'badges'),
          ('Saved', '${data.savedSpots}', '/saved', 'saved'),
        ]),
      ),
      SizedBox(height: grid.px(2)),
      _group(
        context,
        grid,
        HomeGroup.community,
        _communityPanel(context, grid),
      ),
      SizedBox(height: grid.px(3)),
      _nextStop(context, grid),
    ];
  }

  // ---------------------------------------------------------------- shared
  Widget _avatarHeader(BuildContext context, PixelGrid grid,
      {required bool dense}) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PixelPanel(
                style: PixelBoxStyle.gold,
                padding: 1,
                child: SizedBox(
                  width: grid.px(dense ? 14 : 21),
                  height: grid.px(dense ? 14 : 21),
                  child: DitherBackground(
                    top: PixelPalette.greenMid,
                    bottom: PixelPalette.greenDeep,
                    child: Center(
                      child: Text(
                        data.avatarInitial,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      key: ValueKey('home_${_letter(context)}_identity'),
                      onTap: () => context.push('/profile'),
                      child: Text(
                        data.name,
                        maxLines: 2,
                        style: PixelType.title(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                    Text(
                      data.handle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: PixelType.body(context, color: PixelPalette.cream),
                    ),
                    SizedBox(height: grid.px(1)),
                    Wrap(
                      spacing: grid.px(1),
                      runSpacing: grid.px(1),
                      children: [
                        PixelChip('Level ${data.level}',
                            style: PixelBoxStyle.gold),
                        PixelChip(data.title,
                            style: PixelBoxStyle.green,
                            textColor: PixelPalette.white),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          GestureDetector(
            key: ValueKey('home_${_letter(context)}_xp'),
            onTap: () => context.push('/profile'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PixelProgressBar(value: data.xpDone / data.xpGoal),
                Text(
                  '${data.xpDone} / ${data.xpGoal} XP to next level · ${data.points} mJDQ earned',
                  style: PixelType.small(context, color: PixelPalette.cream),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletPanel(BuildContext context, PixelGrid grid, String letter) {
    return _listRows(context, letter, [
      ('mJDQ balance', '${data.mjdq}', '/profile', 'mjdq'),
      ('JDQ governance', '${data.jdq}', '/profile', 'jdq'),
      ('Scout reputation', '${data.scoutReputation}', '/profile', 'rep'),
    ]);
  }

  Widget _scoreGrid(
    BuildContext context,
    PixelGrid grid,
    String letter,
    List<(String, String, String, String)> rows,
  ) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) SizedBox(height: grid.px(1)),
            _row(
              context,
              grid,
              letter,
              rows[i].$1,
              rows[i].$2,
              rows[i].$3,
              rows[i].$4,
            ),
          ],
        ],
      ),
    );
  }

  Widget _listRows(
    BuildContext context,
    String letter,
    List<(String, String, String, String)> rows,
  ) {
    final grid = PixelGrid.of(context);
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) SizedBox(height: grid.px(1)),
          _row(
            context,
            grid,
            letter,
            rows[i].$1,
            rows[i].$2,
            rows[i].$3,
            rows[i].$4,
          ),
        ],
      ],
    );
  }

  Widget _row(
    BuildContext context,
    PixelGrid grid,
    String letter,
    String label,
    String value,
    String route,
    String field,
  ) {
    return GestureDetector(
      key: ValueKey('home_${letter.toLowerCase()}_$field'),
      behavior: HitTestBehavior.opaque,
      onTap: () => context.push(route),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        padding: 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(label, style: PixelType.body(context)),
            ),
            SizedBox(width: grid.px(2)),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: PixelType.numbers(
                  context,
                  color: PixelPalette.greenDark,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hudStrip(
    BuildContext context,
    PixelGrid grid,
    String letter,
    List<(String, String, String, String)> items,
  ) {
    return Wrap(
      spacing: grid.px(2),
      runSpacing: grid.px(2),
      children: [
        for (final item in items)
          GestureDetector(
            key: ValueKey('home_${letter.toLowerCase()}_${item.$4}'),
            onTap: () => context.push(item.$3),
            child: PixelPanel(
              style: PixelBoxStyle.slot,
              child: Column(
                children: [
                  Text(item.$1,
                      style: PixelType.small(
                        context,
                        color: PixelPalette.slate,
                      )),
                  Text(item.$2, style: PixelType.numbers(context)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _communityPanel(BuildContext context, PixelGrid grid) {
    return GestureDetector(
      key: ValueKey('home_${_letter(context)}_community'),
      onTap: () => context.push('/choice'),
      child: PixelPanel(
        style: PixelBoxStyle.green,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'JuanChoice',
              style: PixelType.title(context, color: PixelPalette.white),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              data.votedThisWeek
                  ? 'Vote cast this week · ${data.voteDaysLeft} days left'
                  : 'Voting is open · ${data.voteDaysLeft} days left',
              style: PixelType.body(context, color: PixelPalette.cream),
            ),
            Text(
              data.leaderboardRank == null
                  ? 'Leaderboard rank: not ranked yet'
                  : 'Leaderboard rank: #${data.leaderboardRank}',
              style: PixelType.body(context, color: PixelPalette.cream),
            ),
          ],
        ),
      ),
    );
  }

  Widget _questList(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('In progress', style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          if (data.inProgress.isEmpty)
            _empty(context, 'No quests in progress yet.')
          else
            for (final quest in data.inProgress) ...[
              _questRow(context, grid, quest),
              SizedBox(height: grid.px(1)),
            ],
          SizedBox(height: grid.px(1)),
          GestureDetector(
            key: ValueKey('home_${_letter(context)}_completed'),
            onTap: () => context.push('/quests'),
            child: Text(
              '${data.completedQuests} completed quests',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
          ),
        ],
      ),
    );
  }

  Widget _questRow(BuildContext context, PixelGrid grid, HomeQuestItem quest) {
    return GestureDetector(
      key: ValueKey('home_${_letter(context)}_quest_${quest.title}'),
      onTap: () => context.push('/quests'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quest.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: PixelType.body(context),
          ),
          Text(
            '${quest.done} / ${quest.total} tasks done',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }

  Widget _latestProof(BuildContext context, PixelGrid grid) {
    return GestureDetector(
      key: ValueKey('home_${_letter(context)}_latest_proof'),
      onTap: () => context.push('/history'),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest proof', style: PixelType.title(context)),
            SizedBox(height: grid.px(1)),
            if (data.latestProofTitle == null)
              _empty(context, 'No proof submitted yet.')
            else ...[
              Text(data.latestProofTitle!,
                  maxLines: 2, style: PixelType.body(context)),
              PixelChip(
                (data.latestProofStatus ?? 'pending').toUpperCase(),
                style: data.latestProofStatus == 'approved'
                    ? PixelBoxStyle.green
                    : PixelBoxStyle.gold,
                textColor: data.latestProofStatus == 'approved'
                    ? PixelPalette.white
                    : PixelPalette.ink,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nextStop(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pick your next stop',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                key: ValueKey('home_${_letter(context)}_explore'),
                label: 'Explore',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/explore'),
              ),
              PixelButton(
                key: ValueKey('home_${_letter(context)}_map'),
                label: 'Map',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/map'),
              ),
              PixelButton(
                key: ValueKey('home_${_letter(context)}_quests'),
                label: 'Quests',
                variant: PixelButtonVariant.secondary,
                onPressed: () => context.push('/quests'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String message) {
    return Text(
      message,
      style: PixelType.body(context, color: PixelPalette.slate),
    );
  }

  Widget _group(
    BuildContext context,
    PixelGrid grid,
    HomeGroup group,
    Widget child,
  ) {
    if (!failed.contains(group)) return child;
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'This section could not be loaded.',
            style: PixelType.body(context, color: PixelPalette.white),
          ),
          SizedBox(height: grid.px(2)),
          Align(
            alignment: Alignment.centerRight,
            child: PixelButton(
              key: ValueKey('home_${_letter(context)}_retry_${group.name}'),
              label: 'Retry',
              variant: PixelButtonVariant.secondary,
              onPressed: onRetry,
            ),
          ),
        ],
      ),
    );
  }

  String _letter(BuildContext context) => switch (layout) {
        HomeOptionLayout.characterSheet => 'a',
        HomeOptionLayout.questLog => 'b',
        HomeOptionLayout.hud => 'c',
      };
}

class _QuestLogTabs extends StatefulWidget {
  const _QuestLogTabs({
    required this.progress,
    required this.quests,
    required this.collection,
  });

  final List<Widget> Function(BuildContext context, PixelGrid grid) progress;
  final List<Widget> Function(BuildContext context, PixelGrid grid) quests;
  final List<Widget> Function(BuildContext context, PixelGrid grid) collection;

  @override
  State<_QuestLogTabs> createState() => _QuestLogTabsState();
}

class _QuestLogTabsState extends State<_QuestLogTabs> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    const tabs = ['Progress', 'Quests', 'Collection'];
    final content = switch (_tab) {
      0 => widget.progress(context, grid),
      1 => widget.quests(context, grid),
      _ => widget.collection(context, grid),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (var i = 0; i < tabs.length; i++) ...[
              if (i > 0) SizedBox(width: grid.px(1)),
              Expanded(
                child: GestureDetector(
                  key: ValueKey('home_b_tab_${tabs[i].toLowerCase()}'),
                  onTap: () => setState(() => _tab = i),
                  child: PixelPanel(
                    style: i == _tab
                        ? PixelBoxStyle.wood
                        : PixelBoxStyle.wood.copyWith(
                            fill: PixelPalette.woodDeep,
                            highlight: PixelPalette.wood,
                            shade: PixelPalette.woodNight,
                          ),
                    padding: 1,
                    child: Center(
                      child: Text(
                        tabs[i].toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.paper,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: grid.px(1)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: content,
          ),
        ),
      ],
    );
  }
}
