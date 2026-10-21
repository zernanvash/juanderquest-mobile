import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/server_override.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../app_update/providers/app_update_provider.dart';
import '../../app_update/widgets/update_dialog.dart';
import '../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  Widget _buildAvatarWidget(String? avatarUrl) {
    final isValidUrl = avatarUrl != null &&
        avatarUrl.isNotEmpty &&
        !avatarUrl.endsWith('.svg') &&
        (avatarUrl.startsWith('http://') || avatarUrl.startsWith('https://'));

    if (isValidUrl) {
      return CircleAvatar(
        radius: 28,
        backgroundColor: AppColors.surfaceContainer,
        backgroundImage: NetworkImage(avatarUrl),
        onBackgroundImageError: (_, __) {},
      );
    }

    return const CircleAvatar(
      radius: 28,
      backgroundColor: AppColors.sunGold,
      child: Icon(Icons.person_rounded, size: 32, color: AppColors.woodBrown),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final updateState = ref.watch(appUpdateProvider);
    final isChecking = updateState.status == UpdateStatus.checking;
    final isGuideEnabled = ref.watch(designerGuideProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(
        title: const Text('Explorer Settings'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

          // User Identity Card
          UiSpecContainer(
            spec: const UiSpec(
              title: 'Explorer Identity & Account Card',
              figmaLayer: '#Settings_User_Card',
              dimensions: 'Full width, Padding: 16dp',
              dataBinding: 'authProvider.user (displayName, email, seedId)',
              stateNotes: 'Displays logged-in traveler credentials and profile link',
              uxNotes: 'Wood brown typography with warm stone accents.',
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
                  Container(
                    padding: const EdgeInsets.all(2.5),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.sunGold,
                    ),
                    child: _buildAvatarWidget(user?.avatarUrl),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.displayName ?? 'Juan Dela Cruz',
                          style: AppTypography.headlineSmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user?.email ?? 'juan@juanderquest.ph',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pangasinan Explorer #${user != null ? (user.id.length > 8 ? user.id.substring(0, 8) : user.id) : 'demo'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // App System & Updates
          const JdqSectionHeader(
            title: 'App System & Updates',
            subtitle: 'Over-the-air APK releases and build version management.',
          ),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(color: AppColors.borderLowContrast),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isChecking
                    ? null
                    : () async {
                        final hasUpdate = await ref
                            .read(appUpdateProvider.notifier)
                            .checkForUpdates(silent: false);
                        if (context.mounted) {
                          final current = ref.read(appUpdateProvider);
                          if (hasUpdate && current.latestVersion != null) {
                            UpdateDialog.show(context, current.latestVersion!);
                          } else if (current.status == UpdateStatus.upToDate) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'App is up to date (v${current.installedVersionName} · Build ${current.installedVersionCode}).',
                                ),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          } else if (current.status == UpdateStatus.readyToInstall && current.latestVersion != null) {
                            UpdateDialog.show(context, current.latestVersion!);
                          } else if (current.status == UpdateStatus.error) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  current.errorMessage ?? 'Unable to check for updates. Please try again.',
                                ),
                                backgroundColor: AppColors.danger,
                                action: SnackBarAction(
                                  label: 'Retry',
                                  textColor: Colors.white,
                                  onPressed: () {
                                    ref.read(appUpdateProvider.notifier).checkForUpdates(silent: false);
                                  },
                                ),
                              ),
                            );
                          }
                        }
                      },
                borderRadius: AppSpacing.roundedLg,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.sunGold.withOpacity(0.15),
                          borderRadius: AppSpacing.roundedMd,
                        ),
                        child: const Icon(
                          Icons.system_update_rounded,
                          color: AppColors.woodBrown,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                Text(
                                  'Check for updates',
                                  style: AppTypography.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: const BoxDecoration(
                                    color: AppColors.surfaceContainerHigh,
                                    borderRadius: AppSpacing.roundedPill,
                                  ),
                                  child: Text(
                                    'v${updateState.installedVersionName} (${updateState.installedVersionCode})',
                                    style: AppTypography.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isChecking
                                  ? 'Checking server for updates...'
                                  : updateState.hasUpdate
                                      ? 'New version available (v${updateState.latestVersion?.versionName})'
                                      : updateState.status == UpdateStatus.error
                                          ? (updateState.errorMessage ?? 'Update check failed. Tap to retry.')
                                          : updateState.lastCheckedAt != null
                                              ? 'Up to date · Checked today'
                                              : 'Tap to check for latest updates',
                              style: AppTypography.bodySmall.copyWith(
                                color: updateState.hasUpdate
                                    ? AppColors.primary
                                    : updateState.status == UpdateStatus.error
                                        ? AppColors.danger
                                        : AppColors.textSecondary,
                                fontWeight: updateState.hasUpdate
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isChecking)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (updateState.hasUpdate)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppSpacing.roundedPill,
                          ),
                          child: Text(
                            'UPDATE',
                            style: AppTypography.labelSmall.copyWith(
                              color: AppColors.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const Icon(Icons.refresh_rounded, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Developer & UI Designer Tools
          const JdqSectionHeader(
            title: 'Developer & UI Designer Mode',
            subtitle: 'Inspect Figma component boundaries and semantic spec overlays.',
          ),

          Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: AppSpacing.roundedLg,
              border: Border.all(
                color: isGuideEnabled ? const Color(0xFF0096C7) : AppColors.borderLowContrast,
              ),
              boxShadow: AppSpacing.cardShadow,
            ),
            child: Material(
              color: Colors.transparent,
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
                secondary: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isGuideEnabled
                        ? const Color(0xFF0096C7).withOpacity(0.15)
                        : AppColors.surfaceContainerHigh,
                    borderRadius: AppSpacing.roundedMd,
                  ),
                  child: Icon(
                    Icons.design_services_rounded,
                    color: isGuideEnabled ? const Color(0xFF0096C7) : AppColors.woodBrown,
                    size: 24,
                  ),
                ),
                title: Text(
                  'Designer Guide Mode',
                  style: AppTypography.labelLarge.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isGuideEnabled
                      ? 'Blueprint outlines and Figma component tags are ACTIVE.'
                      : 'Show UI wireframe boundaries and Figma element specs.',
                  style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                ),
                value: isGuideEnabled,
                activeColor: const Color(0xFF0096C7),
                onChanged: (val) {
                  ref.read(designerGuideProvider.notifier).state = val;
                },
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.sectionGap),

          // Debug-only API server override (compiled out of release builds).
          if (ServerOverrideStore.isAvailable) ...[
            const JdqSectionHeader(
              title: 'Developer — API server',
              subtitle: 'Debug and profile builds only. Point this device at another backend.',
            ),
            const _ApiServerOverrideCard(),
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const ValueKey('settings_ar_diagnostics'),
                leading: const Icon(Icons.view_in_ar_rounded, color: AppColors.woodBrown),
                title: const Text('AR diagnostics'),
                subtitle: const Text('Live sensor readout and a test object.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/ar-diagnostics'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
          ],

          // Session Sign Out
          DestructiveButton(
            label: 'Log Out of Account',
            icon: Icons.logout_rounded,
            onPressed: () {
              ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/');
            },
          ),

          const SizedBox(height: AppSpacing.sectionGap),
        ],
      ),
    );
  }
}

class _ApiServerOverrideCard extends StatefulWidget {
  const _ApiServerOverrideCard();

  @override
  State<_ApiServerOverrideCard> createState() => _ApiServerOverrideCardState();
}

class _ApiServerOverrideCardState extends State<_ApiServerOverrideCard> {
  final _controller = TextEditingController();
  String _statusLine = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final stored = await ServerOverrideStore.read();
    if (!mounted) return;
    setState(() {
      _controller.text = stored ?? '';
      _statusLine = stored == null
          ? 'Using the built-in server: ${ApiClient.apiBaseUrl}'
          : 'Override active (applies now): ${ApiClient.apiBaseUrl}';
    });
  }

  String _candidateUrl() {
    final raw = _controller.text.trim();
    if (raw.isEmpty) return ApiClient.normalizeBaseUrl(ApiClient.apiBaseUrl);
    return ApiClient.normalizeBaseUrl(raw);
  }

  Future<void> _testConnection() async {
    setState(() {
      _busy = true;
      _statusLine = 'Testing ${_candidateUrl()}/health/ready …';
    });
    final dio = Dio(BaseOptions(
      baseUrl: _candidateUrl(),
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
      headers: {'Accept': 'application/json'},
    ));
    try {
      final response = await dio.get<dynamic>('/health/ready');
      final data = response.data;
      final dependencies = data is Map ? data['dependencies'] : null;
      final summary = dependencies is Map
          ? dependencies.entries.map((entry) {
              final value = entry.value;
              final state = value is Map ? value['status'] ?? value['state'] : value;
              return '${entry.key}: $state';
            }).join(' · ')
          : 'no dependency detail';
      setState(() => _statusLine = 'OK (${response.statusCode}) — $summary');
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      setState(() => _statusLine = status == null
          ? 'Unreachable: ${error.type.name}'
          : 'HTTP $status from the candidate server');
    } catch (error) {
      setState(() => _statusLine = 'Test failed: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();
    await ServerOverrideStore.write(raw);
    await ApiClient.applyStoredServerOverride();
    if (!mounted) return;
    setState(() => _statusLine = 'Saved. Requests now use ${ApiClient.apiBaseUrl} — restart if anything looks stale.');
  }

  Future<void> _reset() async {
    await ServerOverrideStore.clear();
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _statusLine = 'Override cleared. Default server: ${ApiClient.normalizeBaseUrl(ApiClient.apiBaseUrl)}';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedLg,
        border: Border.all(color: AppColors.borderLowContrast),
        boxShadow: AppSpacing.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              hintText: 'http://192.168.1.20:4100',
              isDense: true,
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _statusLine,
            style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: _busy ? null : _testConnection,
                child: const Text('Test connection'),
              ),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Save override'),
              ),
              TextButton(
                onPressed: _busy ? null : _reset,
                child: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
