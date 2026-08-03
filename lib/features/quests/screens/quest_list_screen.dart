import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/providers/auth_provider.dart';
import '../../submissions/providers/submission_provider.dart';
import '../providers/quest_provider.dart';
import '../models/quest_model.dart';

class QuestListScreen extends ConsumerStatefulWidget {
  const QuestListScreen({super.key});

  @override
  ConsumerState<QuestListScreen> createState() => _QuestListScreenState();
}

class _QuestListScreenState extends ConsumerState<QuestListScreen> {
  String? _selectedCategory;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(questProvider.notifier).fetchQuests();
      ref.read(submissionProvider.notifier).fetchSubmissions();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildAvatarWidget(String? avatarUrl) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 25,
        backgroundColor: const Color(0xFFEFEEEA),
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 25,
      backgroundColor: Color(0xFFFFB703),
      child: Icon(Icons.person_rounded, size: 28, color: Color(0xFF582F0E)),
    );
  }

  String _getQuestStatus(QuestModel quest) {
    final submissions = ref.read(submissionProvider).submissions;
    final userSub = submissions.where((s) => s.questTitle == quest.title || s.id == quest.id).toList();

    if (userSub.any((s) => s.status == 'approved')) return 'COMPLETED';
    if (userSub.any((s) => s.status == 'pending')) return 'PENDING REVIEW';
    if (userSub.any((s) => s.status == 'rejected')) return 'REJECTED';
    return 'AVAILABLE';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'COMPLETED':
        return const Color(0xFF2D6A4F);
      case 'PENDING REVIEW':
        return const Color(0xFFFFB703);
      case 'REJECTED':
        return const Color(0xFFBC4749);
      default:
        return const Color(0xFF2D6A4F);
    }
  }

  @override
  Widget build(BuildContext context) {
    final questState = ref.watch(questProvider);
    final user = ref.watch(authProvider).user;

    final filteredQuests = questState.quests.where((q) {
      if (_searchQuery.trim().isEmpty) return true;
      final query = _searchQuery.toLowerCase().trim();
      return q.title.toLowerCase().contains(query) ||
          q.locationName.toLowerCase().contains(query) ||
          q.categoryDisplay.toLowerCase().contains(query);
    }).toList();

    final QuestModel? featuredQuest = filteredQuests.isNotEmpty ? filteredQuests.first : null;

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF9F5),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            children: [
              const Icon(Icons.explore, color: Color(0xFF7D5800), size: 24),
              const SizedBox(width: 8),
              Text(
                'JuanderQuest',
                style: GoogleFonts.epilogue(
                  color: const Color(0xFF7D5800),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF7D5800)),
            tooltip: 'Submissions History',
            onPressed: () => context.push('/history'),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFEFEEEA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  Image.asset(
                    'assets/images/jdq-token.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFFFB703), size: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${user?.demoPoints ?? 0} PTS',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF6B4B00),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hello, Explorer!',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF514532),
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.displayName ?? 'Juan Dela Cruz',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.epilogue(
                                color: const Color(0xFF582F0E),
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFFB703), width: 2),
                        ),
                        child: _buildAvatarWidget(user?.avatarUrl),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search quests in Pangasinan...',
                      hintStyle: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF837560)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, color: Color(0xFF837560)),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: const Color(0xFFD5C4AC).withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Filter Chips
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildCategoryChip('All Quests', null, Icons.apps),
                        _buildCategoryChip('Eco-Tourism', 'eco', Icons.eco),
                        _buildCategoryChip('Cultural Heritage', 'cultural', Icons.museum),
                        _buildCategoryChip('Food & Culinary', 'food_trade', Icons.restaurant),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Featured Discovery Card
                  if (featuredQuest != null && questState.error == null) ...[
                    Text(
                      'Featured Discovery',
                      style: GoogleFonts.epilogue(
                        color: const Color(0xFF1B1C1A),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildFeaturedQuestCard(context, featuredQuest),
                    const SizedBox(height: 24),
                  ],

                  // Nearby Adventures Header
                  Text(
                    'Nearby Adventures',
                    style: GoogleFonts.epilogue(
                      color: const Color(0xFF1B1C1A),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Quests List Feed
                  if (questState.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(color: Color(0xFFFFB703)),
                      ),
                    )
                  else if (questState.error != null && questState.quests.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFD5C4AC)),
                      ),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(Icons.cloud_off_rounded, size: 48, color: Color(0xFFBC4749)),
                            const SizedBox(height: 12),
                            Text(
                              questState.error!,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(color: const Color(0xFF582F0E), fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed: () => ref.read(questProvider.notifier).fetchQuests(category: _selectedCategory),
                              icon: const Icon(Icons.refresh),
                              label: Text('Retry', style: GoogleFonts.epilogue(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB703),
                                foregroundColor: const Color(0xFF6B4B00),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (filteredQuests.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No quests found matching your criteria.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(color: const Color(0xFF837560)),
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filteredQuests.length,
                      itemBuilder: (context, index) {
                        final quest = filteredQuests[index];
                        return _buildQuestItemCard(context, quest);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, String? category, IconData icon) {
    final isSelected = _selectedCategory == category;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isSelected ? const Color(0xFF6B4B00) : const Color(0xFF514532),
        ),
        label: Text(label),
        selected: isSelected,
        selectedColor: const Color(0xFFFFB703),
        backgroundColor: const Color(0xFFE9E8E4),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: isSelected ? const Color(0xFF6B4B00) : const Color(0xFF514532),
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          fontSize: 12,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        onSelected: (selected) {
          setState(() {
            _selectedCategory = selected ? category : null;
          });
          ref.read(questProvider.notifier).fetchQuests(category: _selectedCategory);
        },
      ),
    );
  }

  Widget _buildFeaturedQuestCard(BuildContext context, QuestModel featuredQuest) {
    return GestureDetector(
      onTap: () => context.push('/quests/${featuredQuest.id}', extra: featuredQuest),
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          image: const DecorationImage(
            image: AssetImage('assets/images/pangasinan_banner.png'),
            fit: BoxFit.cover,
          ),
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF2D6A4F),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FEATURED QUEST',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          featuredQuest.title,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.epilogue(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            const Icon(Icons.location_on, color: Colors.white70, size: 14),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                featuredQuest.locationName,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFB703),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '+${featuredQuest.rewardPoints}',
                          style: GoogleFonts.epilogue(
                            color: const Color(0xFF6B4B00),
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'PTS',
                          style: GoogleFonts.plusJakartaSans(
                            color: const Color(0xFF6B4B00),
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
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
  }

  Widget _buildQuestItemCard(BuildContext context, QuestModel quest) {
    final status = _getQuestStatus(quest);
    final statusColor = _getStatusColor(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD5C4AC).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push('/quests/${quest.id}', extra: quest),
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFFBEEAD1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.place_rounded, color: Color(0xFF3F6653), size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              quest.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.epilogue(
                                color: const Color(0xFF582F0E),
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3F6653).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                quest.categoryDisplay.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  color: const Color(0xFF3F6653),
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, color: Color(0xFF837560), size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              quest.locationName,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF837560),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/jdq-token.png',
                                  width: 16,
                                  height: 16,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.stars, color: Color(0xFFFFB703), size: 14),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${quest.rewardPoints} PTS',
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: const Color(0xFF7D5800),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              status,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
