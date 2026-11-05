import 'package:flutter/material.dart';
import '../../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../../core/pixel/pixel_art.dart';
import '../../../../core/pixel/pixel_input.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../map/pixel/map_marker_art.dart';
import '../builder_models.dart';
import 'location_fence_map_picker.dart';

class TaskSettingsPanel extends StatelessWidget {
  final BuilderTask task;
  final GeoFence destinationDefaultFence;
  final String destinationSpotId;
  final ValueChanged<BuilderTask> onChanged;

  const TaskSettingsPanel({
    super.key,
    required this.task,
    required this.destinationDefaultFence,
    required this.destinationSpotId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    switch (task.checkpointType) {
      case 'location':
        return _buildLocationSettings();
      case 'qr':
        return _buildQrSettings();
      case 'photo':
        return _buildPhotoSettings();
      case 'ar':
        return _buildArSettings();
      case 'action':
        return _buildActionSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildLocationSettings() {
    final ver = task.verification is LocationVerification
        ? task.verification as LocationVerification
        : LocationVerification(fence: destinationDefaultFence);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Row(
                children: [
                  PixelSprite(MapMarkerArt.spotPin, scale: 1),
                  SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Check-in Location & Radius',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.woodBrown,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                onChanged(task.copyWith(
                  verification:
                      LocationVerification(fence: destinationDefaultFence),
                ));
              },
              icon: const PixelSprite(MapMarkerArt.iconRefresh, scale: 1),
              label: const Text('Reset', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LocationFenceMapPicker(
          fence: ver.fence,
          pinLabel: 'Check-in target pin',
          onChanged: (newFence) {
            onChanged(task.copyWith(
              verification: LocationVerification(fence: newFence),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildQrSettings() {
    final ver = task.verification is QrVerification
        ? task.verification as QrVerification
        : QrVerification(
            fence: destinationDefaultFence.copyWith(radiusMeters: 80));

    final isHostScan = ver.scanMode == 'host_scans_traveler';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Who scans?',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: InkWell(
                key: const Key('qr_mode_host_scans'),
                onTap: () {
                  onChanged(task.copyWith(
                    verification: QrVerification(
                      fence: ver.fence,
                      markerCode: ver.markerCode,
                      scanMode: 'traveler_scans',
                    ),
                  ));
                },
                borderRadius: BorderRadius.zero,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: !isHostScan
                        ? PixelPalette.blueLight
                        : PixelPalette.white,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: !isHostScan
                          ? PixelPalette.blueBright
                          : PixelPalette.mist,
                      width: !isHostScan ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.qr_code_scanner_rounded,
                              size: 16,
                              color: !isHostScan
                                  ? PixelPalette.blue
                                  : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Traveler scans',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: !isHostScan
                                    ? PixelPalette.blueDeep
                                    : AppColors.woodBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'You print a placard; traveler scans it on site.',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                key: const Key('qr_mode_host_scans'),
                onTap: () {
                  onChanged(task.copyWith(
                    verification: QrVerification(
                      fence: ver.fence,
                      markerCode: ver.markerCode,
                      scanMode: 'host_scans_traveler',
                    ),
                  ));
                },
                borderRadius: BorderRadius.zero,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isHostScan
                        ? PixelPalette.blueLight
                        : PixelPalette.white,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(
                      color: isHostScan
                          ? PixelPalette.blueBright
                          : PixelPalette.mist,
                      width: isHostScan ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.person_pin_circle_rounded,
                              size: 16,
                              color: isHostScan
                                  ? PixelPalette.blue
                                  : AppColors.textMuted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'I scan traveler',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isHostScan
                                    ? PixelPalette.blueDeep
                                    : AppColors.woodBrown,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Traveler shows pass; you scan it on site.',
                        style: TextStyle(
                            fontSize: 10, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PixelPalette.blueLight,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: PixelPalette.blueMid),
          ),
          child: Text(
            isHostScan
                ? 'Host scan: Each traveler generates a personal quest pass in the app (valid 10 minutes). Open the quest in the app and use "Scan traveler pass" while inside this area. Nothing needs printing.'
                : 'Secret QR Code: A cryptographically secure, unpredictable code is assigned by the server upon saving. You can print the ready-to-display placard from the QR Sheet screen anytime.',
            style: const TextStyle(
                fontSize: 11, height: 1.4, color: PixelPalette.blueDeep),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          isHostScan
              ? 'Where you scan travelers'
              : 'On-site QR Verification Fence',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        LocationFenceMapPicker(
          fence: ver.fence,
          pinLabel:
              isHostScan ? 'Host check-in location' : 'QR placard location',
          onChanged: (newFence) {
            onChanged(task.copyWith(
              verification: QrVerification(
                fence: newFence,
                markerCode: ver.markerCode,
                scanMode: ver.scanMode,
              ),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildPhotoSettings() {
    final ver = task.verification is PhotoVerification
        ? task.verification as PhotoVerification
        : PhotoVerification(
            prompt: '',
            fence: destinationDefaultFence,
            requireGps: true,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Photo Prompt Instructions',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 6),
        PixelTextField(
          initialValue: ver.prompt,
          hint: 'e.g., Take a photo of the heritage marker plaque or main pavilion.',
          maxLines: 2,
          onChanged: (val) {
            onChanged(task.copyWith(
              verification: PhotoVerification(
                prompt: val,
                fence: ver.fence,
                requireGps: ver.requireGps,
              ),
            ));
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PixelPalette.sunLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.zero,
            border: Border.all(color: PixelPalette.sun),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Checkbox(
                    value: ver.requireGps,
                    activeColor: AppColors.primary,
                    onChanged: (val) {
                      final enabled = val ?? false;
                      onChanged(task.copyWith(
                        verification: PhotoVerification(
                          prompt: ver.prompt,
                          requireGps: enabled,
                          fence: enabled
                              ? (ver.fence ?? destinationDefaultFence)
                              : null,
                        ),
                      ));
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'Must be taken on-site (GPS Fence Enforcement)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: PixelPalette.woodDeep,
                      ),
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.only(left: 12, right: 12, bottom: 4),
                child: Text(
                  'When checked, traveler uploads require valid camera GPS metadata within the perimeter. All submitted photos are moderated by administrators before reward settlement.',
                  style: TextStyle(fontSize: 11, color: PixelPalette.goldDeep),
                ),
              ),
            ],
          ),
        ),
        if (ver.requireGps && ver.fence != null) ...[
          const SizedBox(height: 12),
          const Text(
            'Photo Capture Area Pin',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.woodBrown,
            ),
          ),
          const SizedBox(height: 8),
          LocationFenceMapPicker(
            fence: ver.fence!,
            pinLabel: 'Photo geofence target',
            onChanged: (newFence) {
              onChanged(task.copyWith(
                verification: PhotoVerification(
                  prompt: ver.prompt,
                  requireGps: ver.requireGps,
                  fence: newFence,
                ),
              ));
            },
          ),
        ],
      ],
    );
  }

  Widget _buildArSettings() {
    final ver = task.verification is ArVerification
        ? task.verification as ArVerification
        : ArVerification(
            fence: destinationDefaultFence.copyWith(radiusMeters: 50));

    final arObjects = [
      {'id': 'token', 'label': 'Gold Token', 'emoji': '🪙'},
      {'id': 'gem', 'label': 'Emerald Gem', 'emoji': '💎'},
      {'id': 'beacon', 'label': 'Signal Beacon', 'emoji': '🏮'},
      {'id': 'box', 'label': 'Treasure Box', 'emoji': '📦'},
    ];

    final arColors = [
      {'hex': '#FFB703', 'name': 'Gold', 'color': PixelPalette.sun},
      {'hex': '#2D6A4F', 'name': 'Emerald', 'color': PixelPalette.greenBright},
      {'hex': '#3B82F6', 'name': 'Azure', 'color': PixelPalette.blueBright},
      {'hex': '#E11D48', 'name': 'Ruby', 'color': PixelPalette.red},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: PixelPalette.parchment,
            borderRadius: BorderRadius.zero,
            border: Border.all(color: PixelPalette.mist),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.view_in_ar_rounded,
                  size: 18, color: PixelPalette.blueBright),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Mobile-Exclusive AR Experience: Travelers use their smartphone camera in the JuanDerQuest Android app to find and collect the 3D model on-site.',
                  style: TextStyle(
                      fontSize: 11, height: 1.4, color: PixelPalette.blueDeep),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          '3D Virtual Object',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: arObjects.map((obj) {
            final isSelected = ver.object == obj['id'];
            return InkWell(
              onTap: () {
                onChanged(task.copyWith(
                  verification: ArVerification(
                    fence: ver.fence,
                    object: obj['id'] as String,
                    color: ver.color,
                  ),
                ));
              },
              borderRadius: BorderRadius.zero,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color:
                      isSelected ? PixelPalette.parchment : PixelPalette.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: isSelected
                        ? PixelPalette.blueBright
                        : PixelPalette.mist,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(obj['emoji'] as String,
                        style: const TextStyle(fontSize: 16)),
                    const SizedBox(width: 6),
                    Text(
                      obj['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? PixelPalette.blueDeep
                            : AppColors.woodBrown,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'Illumination Hue',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: arColors.map((col) {
            final isSelected = ver.color == col['hex'];
            return InkWell(
              onTap: () {
                onChanged(task.copyWith(
                  verification: ArVerification(
                    fence: ver.fence,
                    object: ver.object,
                    color: col['hex'] as String,
                  ),
                ));
              },
              borderRadius: BorderRadius.zero,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isSelected ? PixelPalette.parchment : PixelPalette.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: isSelected
                        ? PixelPalette.blueBright
                        : PixelPalette.mist,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: col['color'] as Color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      col['name'] as String,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? PixelPalette.blueDeep
                            : AppColors.woodBrown,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        const Text(
          'AR Viewfinder Activation Fence',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        LocationFenceMapPicker(
          fence: ver.fence,
          pinLabel: 'AR object placement pin',
          onChanged: (newFence) {
            onChanged(task.copyWith(
              verification: ArVerification(
                fence: newFence,
                object: ver.object,
                color: ver.color,
              ),
            ));
          },
        ),
      ],
    );
  }

  Widget _buildActionSettings() {
    final ver = task.verification is ActionVerification
        ? task.verification as ActionVerification
        : ActionVerification(
            task: {'kind': 'save_spot', 'spot_id': destinationSpotId});

    final kind = ver.task['kind'] as String? ?? 'save_spot';

    final actionKinds = [
      {
        'kind': 'save_spot',
        'label': 'Bookmark Destination',
        'desc': 'Traveler saves this spot.'
      },
      {
        'kind': 'like_spot',
        'label': 'Like Destination',
        'desc': 'Traveler likes on explore feed.'
      },
      {
        'kind': 'complete_quiz',
        'label': 'Cultural Quiz',
        'desc': 'Complete a cultural quiz.'
      },
      {
        'kind': 'vote_juanchoice',
        'label': 'Governance Vote',
        'desc': 'Vote in community campaign.'
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Digital In-App Action',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: AppColors.woodBrown,
          ),
        ),
        const SizedBox(height: 8),
        ...actionKinds.map((a) {
          final isSelected = kind == a['kind'];
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                final Map<String, dynamic> newTask = {'kind': a['kind']};
                if (a['kind'] == 'save_spot' || a['kind'] == 'like_spot') {
                  newTask['spot_id'] = destinationSpotId;
                } else if (a['kind'] == 'complete_quiz') {
                  newTask['quiz_id'] = '';
                }
                onChanged(task.copyWith(
                  verification: ActionVerification(task: newTask),
                ));
              },
              borderRadius: BorderRadius.zero,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : PixelPalette.white,
                  borderRadius: BorderRadius.zero,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : PixelPalette.mist,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio<String>(
                      value: a['kind'] as String,
                      groupValue: kind,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        final Map<String, dynamic> newTask = {'kind': val};
                        if (val == 'save_spot' || val == 'like_spot') {
                          newTask['spot_id'] = destinationSpotId;
                        } else if (val == 'complete_quiz') {
                          newTask['quiz_id'] = '';
                        }
                        onChanged(task.copyWith(
                          verification: ActionVerification(task: newTask),
                        ));
                      },
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            a['label'] as String,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.woodBrown,
                            ),
                          ),
                          Text(
                            a['desc'] as String,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (kind == 'complete_quiz') ...[
          const SizedBox(height: 8),
          PixelTextField(
            initialValue: ver.task['quiz_id'] as String? ?? '',
            label: 'Cultural Quiz ID',
            hint: 'e.g. quiz_lingayen_history_01',
            onChanged: (val) {
              onChanged(task.copyWith(
                verification: ActionVerification(
                  task: {'kind': 'complete_quiz', 'quiz_id': val.trim()},
                ),
              ));
            },
          ),
        ],
        if (kind == 'save_spot' || kind == 'like_spot') ...[
          const SizedBox(height: 8),
          PixelTextField(
            initialValue: ver.task['spot_id'] as String? ?? destinationSpotId,
            label: 'Target Spot ID',
            onChanged: (val) {
              onChanged(task.copyWith(
                verification: ActionVerification(
                  task: {'kind': kind, 'spot_id': val.trim()},
                ),
              ));
            },
          ),
        ],
      ],
    );
  }
}
