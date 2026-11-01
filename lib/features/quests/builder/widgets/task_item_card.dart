import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../builder_models.dart';

class TaskItemCard extends StatelessWidget {
  final BuilderTask task;
  final int index;
  final int totalTasks;
  final bool isExpanded;
  final VoidCallback onToggleExpand;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onDelete;
  final ValueChanged<BuilderTask> onChanged;
  final Widget? settingsPanel;
  /// The destination's location and id: a task whose type changes starts here
  /// (a 0,0 fence fails the server's Philippines bounds check).
  final GeoFence destinationDefaultFence;
  final String destinationSpotId;

  const TaskItemCard({
    super.key,
    required this.task,
    required this.index,
    required this.totalTasks,
    required this.isExpanded,
    required this.onToggleExpand,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onDelete,
    required this.onChanged,
    required this.destinationDefaultFence,
    required this.destinationSpotId,
    this.settingsPanel,
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

  String _typeLabel(String type) {
    switch (type) {
      case 'qr':
        return 'QR Code';
      case 'photo':
        return 'Photo';
      case 'ar':
        return 'AR Finder';
      case 'action':
        return 'In-app Action';
      case 'location':
      default:
        return 'Location';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpanded ? AppColors.primary : const Color(0xFFE7E5E4),
          width: isExpanded ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header / Summary Row
          InkWell(
            onTap: onToggleExpand,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Step Order Circle
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${task.stepOrder}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title + Type
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title.isEmpty ? 'Untitled Task' : task.title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.woodBrown,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(_typeIcon(task.checkpointType),
                                size: 12, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              _typeLabel(task.checkpointType),
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (task.required) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'REQUIRED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Reorder buttons & Expand
                  if (index > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                      onPressed: onMoveUp,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  if (index < totalTasks - 1)
                    IconButton(
                      icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                      onPressed: onMoveDown,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  Icon(
                    isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          // Expanded Content
          if (isExpanded) ...[
            const Divider(height: 1, color: Color(0xFFF5F5F4)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title Input
                  const Text(
                    'Task Title',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: task.title,
                    onChanged: (val) => onChanged(task.copyWith(title: val)),
                    decoration: InputDecoration(
                      hintText: 'e.g. Check in at the park entrance',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Description Input
                  const Text(
                    'Task Instructions',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.woodBrown,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextFormField(
                    initialValue: task.description,
                    onChanged: (val) => onChanged(task.copyWith(description: val)),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: 'e.g. Walk towards the main pavilion and verify your location.',
                      hintStyle: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                      contentPadding: const EdgeInsets.all(10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Checkpoint Type Picker & Required Switch
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Verification Method',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.woodBrown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            DropdownButtonFormField<String>(
                              key: Key('task_type_dropdown_$index'),
                              value: task.checkpointType,
                              isExpanded: true,
                              onChanged: (val) {
                                if (val != null) {
                                  TaskVerification newVer;
                                  switch (val) {
                                    case 'qr':
                                      newVer = QrVerification(
                                        fence: destinationDefaultFence.copyWith(radiusMeters: 80),
                                        scanMode: 'traveler_scans',
                                      );
                                      break;
                                    case 'photo':
                                      newVer = const PhotoVerification(
                                        prompt: 'Take a clear photo of the landmark or site.',
                                        requireGps: true,
                                      );
                                      break;
                                    case 'ar':
                                      newVer = ArVerification(
                                        fence: destinationDefaultFence.copyWith(radiusMeters: 50),
                                      );
                                      break;
                                    case 'action':
                                      newVer = ActionVerification(
                                        task: {'kind': 'save_spot', 'spot_id': destinationSpotId},
                                      );
                                      break;
                                    case 'location':
                                    default:
                                      newVer = LocationVerification(
                                        fence: destinationDefaultFence.copyWith(radiusMeters: 100),
                                      );
                                      break;
                                  }
                                  onChanged(task.copyWith(
                                    checkpointType: val,
                                    verification: newVer,
                                  ));
                                }
                              },
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'location', child: Text('Location Geofence', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'qr', child: Text('QR Code Verification', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'photo', child: Text('Photo Submission', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'ar', child: Text('Augmented Reality (AR)', style: TextStyle(fontSize: 12))),
                                DropdownMenuItem(value: 'action', child: Text('In-App Digital Action', style: TextStyle(fontSize: 12))),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text(
                            'Required',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.woodBrown,
                            ),
                          ),
                          Switch(
                            value: task.required,
                            activeColor: AppColors.primary,
                            onChanged: (val) => onChanged(task.copyWith(required: val)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Per-Type Settings Panel
                  if (settingsPanel != null) settingsPanel!,

                  const SizedBox(height: 12),
                  // Delete Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 36),
                        foregroundColor: Colors.red,
                      ),
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded, size: 16),
                      label: const Text('Delete Task', style: TextStyle(fontSize: 11)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
