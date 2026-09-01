import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/jdq_scaffold.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  final List<String> _authors = const [
    'Ana Victoria V. Alentajan',
    'Zernan Vash L. Arive',
    'Clarissa Angel A. Gutlay',
    'Carl Jacob Lavaro',
    'Alyana Soriano',
  ];

  @override
  Widget build(BuildContext context) {
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
            'About JuanDerQuest',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
          ),
        ),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        children: [
          // Hero Banner
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.sunGold,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.school_rounded, color: AppColors.woodBrown, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Universidad de Dagupan',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'JuanDerQuest: A Gamified Blockchain-based System for Promoting Tourist Destinations in Pangasinan',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.sunGold,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'School of Information Technology Education (SITE)\nCapstone Research Prototype 2026',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE2F0E8), height: 1.4),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tri-Party Flywheel Architecture Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tri-Party Tourism Flywheel',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                ),
                const SizedBox(height: 8),
                _buildFlywheelRow('🧭 Travelers & Explorers', 'Complete verified GPS quest trails, unlock Soulbound badges, and earn mJDQ reward bounties.'),
                const SizedBox(height: 6),
                _buildFlywheelRow('🏪 Local MSME Merchants', 'Fund discount vouchers with zero upfront costs; enjoy foot traffic diverted away from crowded hotspots.'),
                const SizedBox(height: 6),
                _buildFlywheelRow('🏛️ Municipal LGUs & Tourism Boards', 'Balance tourism distribution, prevent overcrowding, and sponsor event campaigns with locked escrow pools.'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Research Team
          const Text(
            'Research Authors & Development Team',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
          ),
          const SizedBox(height: 8),

          ..._authors.map((author) {
            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: AppSpacing.roundedMd,
                border: Border.all(color: AppColors.borderLowContrast),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primaryContainer,
                    child: Text(
                      author.substring(0, 1),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onPrimaryContainer),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      author,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.woodBrown),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildFlywheelRow(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: AppSpacing.roundedMd,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primaryDark)),
          const SizedBox(height: 2),
          Text(description, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, height: 1.3)),
        ],
      ),
    );
  }
}
