import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/error_dialog.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../ar_experience/controllers/calibration_controller.dart';
import '../models/quest_model.dart';
import '../../../core/widgets/designer_guide.dart';

class QuestDetailScreen extends ConsumerWidget {
  final QuestModel? quest;
  final String? questId;

  const QuestDetailScreen({super.key, this.quest, this.questId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quest != null) return _DetailContent(quest: quest!);
    if (questId == null) return const _NotFound();
    return _QuestDetailById(questId: questId!);
  }
}

class _QuestDetailById extends ConsumerStatefulWidget {
  final String questId;
  const _QuestDetailById({required this.questId});

  @override
  ConsumerState<_QuestDetailById> createState() => _QuestDetailByIdState();
}

class _QuestDetailByIdState extends ConsumerState<_QuestDetailById> {
  Future<QuestModel?>? _fetchFuture;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _fetchQuest();
  }

  Future<QuestModel?> _fetchQuest() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/quests/${widget.questId}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return QuestModel.fromJson(response.data['data']);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuestModel?>(
      future: _fetchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const JdqScaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.data == null) return const _NotFound();
        return _DetailContent(quest: snapshot.data!);
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return JdqScaffold(
      appBar: AppBar(
        title: const Text('Quest Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_off_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Quest Not Found',
              style: AppTypography.headlineSmall
                  .copyWith(color: AppColors.woodBrown),
            ),
            const SizedBox(height: 6),
            Text(
              'This quest details could not be retrieved.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 160,
              child: SecondaryButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerWidget {
  final QuestModel quest;
  const _DetailContent({required this.quest});

  Future<void> _launchAR(BuildContext context, WidgetRef ref) async {
    final isCalibrated = ref.read(calibrationProvider).isCalibrated;
    if (!isCalibrated) {
      if (context.mounted) {
        context.push('/ar-calibration?returnTo=/quests/${quest.id}/ar');
      }
      return;
    }

    final cameraStatus = await Permission.camera.request();
    final locationStatus = await Permission.locationWhenInUse.request();

    if (cameraStatus.isGranted && locationStatus.isGranted) {
      if (context.mounted) {
        context.push('/quests/${quest.id}/ar', extra: quest);
      }
    } else {
      if (context.mounted) {
        GlobalErrorDialog.show(
          context,
          title: 'Permissions Required',
          message:
              'JuanderQuest uses camera to recognize destination markers and location services to verify quest completion radius.',
          icon: Icons.security_rounded,
          iconColor: AppColors.danger,
          buttonText: 'Open Device Settings',
          onPressed: () => openAppSettings(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCalibrated = ref.watch(calibrationProvider).isCalibrated;
    final hasImage = quest.imageUrl != null &&
        quest.imageUrl!.isNotEmpty &&
        (quest.imageUrl!.startsWith('http://') ||
            quest.imageUrl!.startsWith('https://'));

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text(quest.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            UiSpecContainer(
              spec: const UiSpec(
                title: 'Quest Hero Photography & Bounty Pills',
                figmaLayer: '#Quest_Detail_Hero_Image',
                dimensions:
                    'Full width, AspectRatio: 16/9 (1080x608), Radius: 0dp',
                dataBinding:
                    'quest.imageUrl / quest.categoryDisplay / quest.rewardPoints',
                stateNotes:
                    'Network image with fallback asset placeholder + Gold Bounty Pill',
                uxNotes:
                    'High-resolution Pangasinan destination photography with dark overlay gradient.',
              ),
              child: Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: hasImage
                        ? Image.network(
                            quest.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                _buildHeaderPlaceholder(),
                          )
                        : _buildHeaderPlaceholder(),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    left: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.primaryDark,
                        borderRadius: AppSpacing.roundedPill,
                      ),
                      child: Text(
                        quest.categoryDisplay.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppSpacing.roundedPill,
                        boxShadow: AppSpacing.cardShadow,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.stars_rounded,
                              color: AppColors.sunGold, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            '+${quest.rewardPoints} PTS',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: AppColors.woodBrown,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          quest.locationName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (quest.crowdStatus == 'estimated_busy') ...[
                    const SizedBox(height: AppSpacing.md),
                    UiSpecContainer(
                      spec: const UiSpec(
                        title: 'Live Overcrowding Diversion Card',
                        figmaLayer: '#Quest_Crowd_Pressure_Alert',
                        dimensions: 'Full width, Padding: 16dp, Radius: 16dp',
                        dataBinding:
                            'quest.crowdStatus (estimated_busy / tranquil / moderate)',
                        stateNotes:
                            'Displays warning alert when tourist congestion is high to redirect visitors',
                        uxNotes:
                            'Amber/Coral alert container with warning icon and link to tranquil gems.',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.crowdBusyBg,
                          borderRadius: AppSpacing.roundedLg,
                          border: Border.all(
                              color: AppColors.crowdBusy.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.crowdBusy, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'High Tourist Activity Detected',
                                    style: TextStyle(
                                      color: AppColors.crowdBusy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This destination is currently experiencing high foot traffic. Explore quieter hidden gems in the Explore tab for bonus rewards!',
                                    style: AppTypography.bodySmall.copyWith(
                                      color:
                                          AppColors.crowdBusy.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (quest.campaignId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withOpacity(0.15),
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.sunGold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded,
                              color: AppColors.woodBrown, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Sponsored Campaign: ${quest.remainingSlots ?? "Open"} reward slots available',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.woodBrown),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Quest Parameters Card
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'Quest Reward & GPS Guard Parameters Card',
                      figmaLayer: '#Quest_Specs_Metrics_Card',
                      dimensions:
                          'Full width split card, Height: ~84dp, Radius: 16dp',
                      dataBinding:
                          'quest.rewardPoints / quest.allowedRadiusMeters',
                      stateNotes:
                          'Points pill + Radar icon with server-enforced radius constraint',
                      uxNotes:
                          'Prominently clarifies physical verification constraints before travel.',
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppSpacing.roundedLg,
                        border: Border.all(color: AppColors.borderLowContrast),
                        boxShadow: AppSpacing.cardShadow,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'QUEST REWARD',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textMuted,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.stars_rounded,
                                        color: AppColors.sunGold, size: 20),
                                    const SizedBox(width: 6),
                                    Text(
                                      '${quest.rewardPoints} Points',
                                      style: AppTypography.labelLarge.copyWith(
                                        color: AppColors.woodBrown,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                              width: 1,
                              height: 40,
                              color: AppColors.borderLowContrast),
                          Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.only(left: AppSpacing.md),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GPS RADIUS GUARD',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textMuted,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.radar_rounded,
                                          color: AppColors.primary, size: 20),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Within ${quest.allowedRadiusMeters}m',
                                        style:
                                            AppTypography.labelLarge.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Overview
                  const JdqSectionHeader(
                    title: 'Quest Overview',
                  ),
                  Text(
                    quest.description,
                    style: AppTypography.bodyLarge,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Objective Steps
                  const JdqSectionHeader(
                    title: 'Quest Objectives',
                    subtitle: 'Follow these steps at the physical destination.',
                  ),

                  _buildObjectiveStep(
                    stepNumber: '1',
                    title: 'Travel to Location',
                    subtitle:
                        'Arrive within ${quest.allowedRadiusMeters}m of ${quest.locationName}.',
                    icon: Icons.directions_walk_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildObjectiveStep(
                    stepNumber: '2',
                    title: 'Locate Quest Marker',
                    subtitle:
                        'Find the official heritage marker or destination landmark.',
                    icon: Icons.qr_code_scanner_rounded,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _buildObjectiveStep(
                    stepNumber: '3',
                    title: 'Capture Evidence (Simulated AR)',
                    subtitle:
                        'Use camera experience to submit GPS-verified photo proof.',
                    icon: Icons.camera_alt_rounded,
                  ),

                  const SizedBox(height: AppSpacing.sectionGap),

                  if (!isCalibrated) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withOpacity(0.12),
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(
                            color: AppColors.sunGold.withOpacity(0.5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.explore_rounded,
                              color: AppColors.woodBrown, size: 22),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Compass Calibration Recommended',
                                  style: AppTypography.labelMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.woodBrown),
                                ),
                                Text(
                                  'Calibrate sensors for accurate 3D AR positioning.',
                                  style: AppTypography.bodySmall
                                      .copyWith(color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push(
                                '/ar-calibration?returnTo=/quests/${quest.id}/ar'),
                            child: const Text('Calibrate',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // Launch Simulated AR Action & Navigate Action
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'Start Quest Experience CTA',
                      figmaLayer: '#Quest_Start_Action_Button',
                      dimensions:
                          'Full width button, Height: 52dp, Radius: 12dp',
                      dataBinding:
                          'Launches /quests/:id/ar with camera & GPS permission check',
                      stateNotes:
                          'Active emerald green -> Disabled if quest already completed',
                      uxNotes:
                          'Prominent primary CTA to begin interactive verification with in-app navigation shortcut.',
                      deferred: true,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: PrimaryButton(
                            label: 'Start Quest (Simulated AR)',
                            onPressed: () => _launchAR(context, ref),
                            icon: Icons.play_arrow_rounded,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        InkWell(
                          onTap: () {
                            context.push(
                              '/navigate?lat=${quest.gpsLat}&lng=${quest.gpsLng}&name=${Uri.encodeComponent(quest.title)}&address=${Uri.encodeComponent(quest.locationName)}',
                            );
                          },
                          borderRadius: AppSpacing.roundedMd,
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(
                                  color: AppColors.borderLowContrast),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.navigation_rounded,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Route',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.woodBrown),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sectionGap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildObjectiveStep({
    required String stepNumber,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: AppColors.crowdModerateBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.woodBrown, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Step $stepNumber: $title',
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, size: 64, color: AppColors.sunGold),
            const SizedBox(height: AppSpacing.sm),
            Text(
              quest.locationName,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}
