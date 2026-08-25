import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jdq_scaffold.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  int _activeTab = 0; // 0 = Sprint, 1 = All-Time

  final List<Map<String, dynamic>> _sprintScouts = const [
    {'rank': 1, 'name': 'Zernan Vash', 'points': 4850, 'quests': 18, 'tier': 'Master Scout', 'avatar': 'Z'},
    {'rank': 2, 'name': 'Ana Victoria', 'points': 4200, 'quests': 15, 'tier': 'Pioneer Scout', 'avatar': 'A'},
    {'rank': 3, 'name': 'Clarissa Angel', 'points': 3900, 'quests': 14, 'tier': 'Pioneer Scout', 'avatar': 'C'},
    {'rank': 4, 'name': 'Carl Jacob', 'points': 3450, 'quests': 12, 'tier': 'Trailblazer', 'avatar': 'C'},
    {'rank': 5, 'name': 'Alyana S.', 'points': 3100, 'quests': 11, 'tier': 'Trailblazer', 'avatar': 'A'},
    {'rank': 6, 'name': 'Juan Dela Cruz (You)', 'points': 1250, 'quests': 4, 'tier': 'Pathfinder', 'avatar': 'J', 'isUser': true},
    {'rank': 7, 'name': 'Maria Santos', 'points': 980, 'quests': 3, 'tier': 'Pathfinder', 'avatar': 'M'},
  ];

  final List<Map<String, dynamic>> _allTimeScouts = const [
    {'rank': 1, 'name': 'Zernan Vash', 'points': 28500, 'quests': 84, 'tier': 'Grand Legend', 'avatar': 'Z'},
    {'rank': 2, 'name': 'Ana Victoria', 'points': 24200, 'quests': 72, 'tier': 'Grand Legend', 'avatar': 'A'},
    {'rank': 3, 'name': 'Clarissa Angel', 'points': 21900, 'quests': 65, 'tier': 'Master Scout', 'avatar': 'C'},
    {'rank': 4, 'name': 'Carl Jacob', 'points': 19450, 'quests': 58, 'tier': 'Master Scout', 'avatar': 'C'},
    {'rank': 5, 'name': 'Alyana S.', 'points': 17100, 'quests': 51, 'tier': 'Pioneer Scout', 'avatar': 'A'},
    {'rank': 14, 'name': 'Juan Dela Cruz (You)', 'points': 5250, 'quests': 16, 'tier': 'Trailblazer', 'avatar': 'J', 'isUser': true},
  ];

  final List<Map<String, dynamic>> _municipalActivity = const [
    {'name': 'Alaminos City (Hundred Islands)', 'completions': 1420, 'badge': '🏖️ Top Eco Spot'},
    {'name': 'Bolinao (Cape & Falls)', 'completions': 1180, 'badge': '🌅 Sunset Trail'},
    {'name': 'Dagupan City (Culinary Hub)', 'completions': 980, 'badge': '🐟 Bangus Capital'},
    {'name': 'Manaoag (Minor Basilica)', 'completions': 890, 'badge': '🏛️ Heritage Trail'},
    {'name': 'Lingayen (Capitol & Gulf)', 'completions': 740, 'badge': '🏛️ Provincial Seat'},
  ];

  @override
  Widget build(BuildContext context) {
    final scouts = _activeTab == 0 ? _sprintScouts : _allTimeScouts;

    return JdqScaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => context.pop(),
          tooltip: 'Back',
        ),
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Scout Hall of Fame',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.woodBrown,
            ),
          ),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Header Hero Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF2D6A4F), Color(0xFF1B4332)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppSpacing.roundedXl,
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: AppColors.sunGold,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.military_tech_rounded, size: 28, color: AppColors.woodBrown),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pangasinan Leaderboard',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Top explorers unlocking eco & cultural bounties across Pangasinan.',
                        style: TextStyle(fontSize: 11, color: Color(0xFFE2F0E8), height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tab Switcher (Sprint vs All-Time)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedXl,
              border: Border.all(color: AppColors.borderLowContrast),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 0 ? AppColors.primary : Colors.transparent,
                        borderRadius: AppSpacing.roundedLg,
                      ),
                      child: Center(
                        child: Text(
                          '⚡ 30-Day Sprint',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 0 ? Colors.white : AppColors.woodBrown,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = 1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: _activeTab == 1 ? AppColors.primary : Colors.transparent,
                        borderRadius: AppSpacing.roundedLg,
                      ),
                      child: Center(
                        child: Text(
                          '👑 All-Time Legends',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _activeTab == 1 ? Colors.white : AppColors.woodBrown,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Top 3 Podium Cards
          if (scouts.length >= 3)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedXl,
                border: Border.all(color: AppColors.borderLowContrast),
                boxShadow: AppSpacing.cardShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // #2 Silver
                  _buildPodiumItem(scouts[1], '#2', const Color(0xFFC0C0C0), 75),
                  // #1 Gold
                  _buildPodiumItem(scouts[0], '👑 #1', AppColors.sunGold, 95),
                  // #3 Bronze
                  _buildPodiumItem(scouts[2], '#3', const Color(0xFFCD7F32), 65),
                ],
              ),
            ),

          const SizedBox(height: 14),

          // Scout Rankings List
          const Text(
            'Scout Rankings',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
          ),
          const SizedBox(height: 8),

          ...scouts.map((s) => _buildScoutRow(s)),

          const SizedBox(height: 16),

          // Top Municipal Activity Section
          const Text(
            'Top Municipalities by Check-in Volume',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
          ),
          const SizedBox(height: 8),

          ..._municipalActivity.map((muni) => _buildMunicipalCard(muni)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildPodiumItem(Map<String, dynamic> scout, String rankLabel, Color color, double height) {
    return Column(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.2),
          child: Text(
            scout['avatar'],
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.woodBrown, fontSize: 14),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          scout['name'].toString().split(' ')[0],
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
        ),
        Text(
          '${scout['points']} pts',
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primary),
        ),
        const SizedBox(height: 6),
        Container(
          width: 70,
          height: height,
          decoration: BoxDecoration(
            color: color.withOpacity(0.25),
            borderRadius: AppSpacing.roundedMd,
            border: Border.all(color: color),
          ),
          child: Center(
            child: Text(
              rankLabel,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.woodBrown),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScoutRow(Map<String, dynamic> scout) {
    final isUser = scout['isUser'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isUser ? const Color(0xFFE2F0E8) : AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: isUser ? AppColors.primary : AppColors.borderLowContrast),
      ),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: scout['rank'] <= 3 ? AppColors.sunGold.withOpacity(0.25) : AppColors.surfaceContainerLow,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${scout['rank']}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: scout['rank'] <= 3 ? AppColors.woodBrown : AppColors.textMuted,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scout['name'],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isUser ? FontWeight.w900 : FontWeight.bold,
                    color: AppColors.woodBrown,
                  ),
                ),
                Text(
                  '${scout['tier']} • ${scout['quests']} Quests Completed',
                  style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Text(
            '${scout['points']} mJDQ',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
        ],
      ),
    );
  }

  Widget _buildMunicipalCard(Map<String, dynamic> muni) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                muni['name'],
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
              ),
              Text(
                muni['badge'],
                style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: AppSpacing.roundedPill,
            ),
            child: Text(
              '${muni['completions']} visits',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
