import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

const List<String> _trailPreferences = [
  'Scenic route',
  'Local food stops',
  'Quieter alternatives',
];

class TrailPreviewCard extends StatefulWidget {
  const TrailPreviewCard({super.key});

  @override
  State<TrailPreviewCard> createState() => _TrailPreviewCardState();
}

class _TrailPreviewCardState extends State<TrailPreviewCard> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.explore_rounded, size: 14, color: AppColors.primary),
                  SizedBox(width: 5),
                  Text(
                    'THE TRAIL',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.6,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.sunGold.withOpacity(0.25),
                  borderRadius: AppSpacing.roundedPill,
                  border: Border.all(color: AppColors.sunGold),
                ),
                child: const Text(
                  'IN DEVELOPMENT',
                  style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                    color: AppColors.woodBrown,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'A personalized multi-stop Trail to this destination is not available yet. '
            'Tell us what you would prefer — nothing is routed or promised today.',
            style: TextStyle(fontSize: 10.5, height: 1.4, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _trailPreferences.map((preference) {
              final selected = _selected.contains(preference);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selected.remove(preference);
                    } else {
                      _selected.add(preference);
                    }
                  });
                },
                child: Semantics(
                  button: true,
                  selected: selected,
                  label: preference,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary.withOpacity(0.16) : Colors.white,
                      borderRadius: AppSpacing.roundedPill,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.borderLowContrast,
                      ),
                    ),
                    child: Text(
                      preference,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppColors.primaryDark : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Preferences stay on this screen only; they are not sent anywhere yet.',
            style: TextStyle(fontSize: 9, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
