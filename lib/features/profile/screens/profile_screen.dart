import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_stats_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Widget _buildAvatarWidget(String? avatarUrl) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 40,
        backgroundColor: const Color(0xFFEFEEEA),
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 40,
      backgroundColor: Color(0xFFFFB703),
      child: Icon(Icons.person_rounded, size: 48, color: Color(0xFF582F0E)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final stats = ref.watch(profileStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Explorer Profile',
          style: GoogleFonts.epilogue(
            color: const Color(0xFF582F0E),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // User Identification Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFFFFB703), width: 3),
                    ),
                    child: _buildAvatarWidget(user?.avatarUrl),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    user?.displayName ?? 'Juan Dela Cruz',
                    style: GoogleFonts.epilogue(color: const Color(0xFF582F0E), fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? 'juan@juanderquest.ph',
                    style: GoogleFonts.plusJakartaSans(color: const Color(0xFF514532), fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F6653).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'PANGASINAN EXPLORER',
                      style: GoogleFonts.plusJakartaSans(color: const Color(0xFF3F6653), fontWeight: FontWeight.bold, fontSize: 10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Computed Traveler Statistics & Demo Points Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Expanded(child: _buildStatItem('Completed', '${stats.completedQuestsCount}', Icons.check_circle_outline, const Color(0xFF2D6A4F))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildStatItem('Pending', '${stats.pendingSubmissionsCount}', Icons.hourglass_top_rounded, const Color(0xFFFFB703))),
                      const SizedBox(width: 4),
                      Expanded(child: _buildStatItem('Total Earned', '${stats.totalPointsEarned} PTS', Icons.stars, const Color(0xFF7D5800))),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Row(
                          children: [
                            const Icon(Icons.stars_rounded, color: Color(0xFFFFB703), size: 20),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Demo Points Balance',
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.epilogue(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${user?.demoPoints ?? 0} PTS',
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.epilogue(color: const Color(0xFF7D5800), fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Achievements & Badges Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Impact Badges',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF582F0E),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Pangasinan Legacy',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF837560),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Explicit Badge Cards with State Chips
            _buildBadgeCard(
              title: 'Eco Pioneer',
              description: 'Verified eco-tourism proof submission in Pangasinan.',
              icon: Icons.eco_rounded,
              badgeState: stats.ecoPioneerState,
            ),
            const SizedBox(height: 12),
            _buildBadgeCard(
              title: 'Heritage Keeper',
              description: 'Verified cultural heritage landmark submission.',
              icon: Icons.museum_rounded,
              badgeState: stats.heritageKeeperState,
            ),
            const SizedBox(height: 12),
            _buildBadgeCard(
              title: 'Food Explorer',
              description: 'Verified culinary & local trade quest submission.',
              icon: Icons.restaurant_rounded,
              badgeState: stats.foodExplorerState,
            ),
            const SizedBox(height: 24),

            // Navigation Actions
            ElevatedButton.icon(
              onPressed: () => context.push('/history'),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text('View Quest Submissions History', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                backgroundColor: const Color(0xFF3F6653),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                ref.read(authProvider.notifier).logout();
              },
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: Text('Sign Out', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: const Color(0xFFBC4749),
                side: const BorderSide(color: Color(0xFFBC4749)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.epilogue(color: color, fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildBadgeCard({
    required String title,
    required String description,
    required IconData icon,
    required BadgeState badgeState,
  }) {
    Color iconBgColor;
    Color iconColor;
    String stateLabel;
    Color chipBgColor;
    Color chipTextColor;

    switch (badgeState) {
      case BadgeState.earned:
        iconBgColor = const Color(0xFFBEEAD1);
        iconColor = const Color(0xFF2D6A4F);
        stateLabel = 'EARNED';
        chipBgColor = const Color(0xFF2D6A4F);
        chipTextColor = Colors.white;
        break;
      case BadgeState.inProgress:
        iconBgColor = const Color(0xFFFFF3CD);
        iconColor = const Color(0xFF7D5800);
        stateLabel = 'IN PROGRESS';
        chipBgColor = const Color(0xFFFFB703);
        chipTextColor = const Color(0xFF6B4B00);
        break;
      case BadgeState.locked:
        iconBgColor = const Color(0xFFE9E8E4);
        iconColor = const Color(0xFF837560);
        stateLabel = 'LOCKED';
        chipBgColor = const Color(0xFFE9E8E4);
        chipTextColor = const Color(0xFF837560);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.epilogue(
                          color: const Color(0xFF582F0E),
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: chipBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stateLabel,
                        style: GoogleFonts.plusJakartaSans(
                          color: chipTextColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF837560),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
