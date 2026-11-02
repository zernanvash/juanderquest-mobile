import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
import '../../map/widgets/map_origin_card.dart';

/// Settings -> Developer tools: designer guide overlay, and (debug/profile
/// builds only) the API server override, map origin and AR diagnostics.
class SettingsDeveloperScreen extends ConsumerWidget {
  const SettingsDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuideEnabled = ref.watch(designerGuideProvider);

    return JdqScaffold(
      scrollable: true,
      appBar: AppBar(title: const Text('Developer tools')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.md),

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
            if (kDebugMode) const MapOriginCard(),
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
            const SizedBox(height: AppSpacing.sm),
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                key: const ValueKey('settings_pixel_lab'),
                leading: const Icon(Icons.grid_on_rounded, color: AppColors.woodBrown),
                title: const Text('Pixel lab'),
                subtitle: const Text('Designer pixel art in the brand palette.'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/settings/pixel-lab'),
              ),
            ),
            const SizedBox(height: AppSpacing.sectionGap),
          ],
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
