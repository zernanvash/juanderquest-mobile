import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../builder/quest_builder_repository.dart';

class QrSheetScreen extends ConsumerStatefulWidget {
  final String questId;

  const QrSheetScreen({super.key, required this.questId});

  @override
  ConsumerState<QrSheetScreen> createState() => _QrSheetScreenState();
}

class _QrSheetScreenState extends ConsumerState<QrSheetScreen> {
  late Future<QrSheetData> _future;

  @override
  void initState() {
    super.initState();
    _future = ref.read(questBuilderRepositoryProvider).getQrSheet(widget.questId);
  }

  void _showFullScreenQr(BuildContext context, QrSheetTask task, String locationName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close_rounded, color: AppColors.woodBrown),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              'Step ${task.stepOrder}: ${task.title}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.woodBrown,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Text(
                        'JUANDERQUEST CHALLENGE PLACARD',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${task.stepOrder}. ${task.title}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: AppColors.woodBrown,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      locationName,
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFD6D3D1), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: task.qrPayload,
                        version: QrVersions.auto,
                        size: 260.0,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Code: ${task.markerCode}',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.woodBrown,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Display this on your phone or print it for travelers to scan on site.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _shareCode(BuildContext context, QrSheetTask task) {
    Clipboard.setData(ClipboardData(text: task.markerCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Marker code copied to clipboard: ${task.markerCode}'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'QR Sheet & Placards',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.woodBrown,
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<QrSheetData>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                      const SizedBox(height: 12),
                      Text(
                        'Failed to load QR sheet: ${snapshot.error}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 14, color: AppColors.woodBrown),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          backgroundColor: AppColors.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _future = ref
                                .read(questBuilderRepositoryProvider)
                                .getQrSheet(widget.questId);
                          });
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final data = snapshot.data!;
            final printableTasks =
                data.qrTasks.where((t) => t.scanMode != 'host_scans_traveler').toList();
            final hostScanTasks =
                data.qrTasks.where((t) => t.scanMode == 'host_scans_traveler').toList();

            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                // Quest Summary Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE7E5E4)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.questTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppColors.woodBrown,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.locationName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Host Scan Note
                if (hostScanTasks.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF1D4ED8)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No placard needed for: ${hostScanTasks.map((t) => "${t.stepOrder}. ${t.title}").join(", ")}. Hosts scan the traveler\'s pass in the app — nothing to print.',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFF1E3A8A),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (printableTasks.isEmpty && hostScanTasks.isEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        'This quest does not contain any QR verification tasks.',
                        style: TextStyle(fontSize: 14, color: AppColors.textMuted),
                      ),
                    ),
                  ),
                ],

                // Placards List
                ...printableTasks.map((task) => _buildPlacardCard(context, task, data.locationName)),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildPlacardCard(BuildContext context, QrSheetTask task, String locationName) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E5E4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'ON-SITE PLACARD',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${task.stepOrder}. ${task.title}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.woodBrown,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            locationName,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE7E5E4)),
            ),
            child: QrImageView(
              data: task.qrPayload,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Code: ${task.markerCode}',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.woodBrown,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    foregroundColor: AppColors.woodBrown,
                    side: const BorderSide(color: Color(0xFFD6D3D1)),
                  ),
                  onPressed: () => _shareCode(context, task),
                  icon: const Icon(Icons.copy_rounded, size: 16),
                  label: const Text('Copy code'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () => _showFullScreenQr(context, task, locationName),
                  icon: const Icon(Icons.fullscreen_rounded, size: 18),
                  label: const Text('Full screen'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
