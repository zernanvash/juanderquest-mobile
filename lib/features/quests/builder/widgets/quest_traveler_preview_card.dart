import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../builder_models.dart';

class QuestTravelerPreviewCard extends StatelessWidget {
  final QuestBuilderState state;
  final String locationName;

  const QuestTravelerPreviewCard({
    super.key,
    required this.state,
    required this.locationName,
  });

  IconData _typeIcon(String type) {
    switch (type) {
      case 'qr':
        return Icons.qr_code_2_rounded;
      case 'photo':
        return Icons.camera_alt_rounded;
      case 'ar':
        return Icons.view_in_ar_rounded;
      case 'action':
        return Icons.touch_app_rounded;
      case 'location':
      default:
        return Icons.location_on_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'TRAVELER VIEW PREVIEW',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.stars_rounded, size: 12, color: Color(0xFFB45309)),
                    const SizedBox(width: 4),
                    Text(
                      '+${state.rewardPoints} pts',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            state.title.isEmpty ? 'Untitled Quest' : state.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: AppColors.woodBrown,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            locationName,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            state.description.isEmpty
                ? 'No description provided yet.'
                : state.description,
            style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF57534E)),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFF5F5F4)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TASKS (${state.tasks.length})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                  color: AppColors.textMuted,
                ),
              ),
              Text(
                state.stepOrderMode == 'sequential' ? 'Must complete in order' : 'Any order',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (state.tasks.isEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'No tasks added yet. Add tasks below.',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                ),
              ),
            ),
          ] else ...[
            ...state.tasks.map((task) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F4),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE7E5E4)),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${task.stepOrder}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.woodBrown,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(_typeIcon(task.checkpointType), size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        task.title.isEmpty ? 'Task ${task.stepOrder}' : task.title,
                        style: const TextStyle(fontSize: 12, color: AppColors.woodBrown),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (task.required)
                      const Text(
                        '*',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}
