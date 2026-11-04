import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/server_override.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/designer_guide.dart';
import '../../map/widgets/map_origin_card.dart';

/// Settings -> Developer tools: designer guide overlay, and (debug/profile
/// builds only) the API server override, map origin and AR diagnostics.
class SettingsDeveloperScreen extends ConsumerWidget {
  const SettingsDeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuideEnabled = ref.watch(designerGuideProvider);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Developer Tools',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(8) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        PixelPanel(
                          style: PixelBoxStyle.wood,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Developer & UI Designer Mode',
                                style: PixelType.title(
                                  context,
                                  color: PixelPalette.paper,
                                ),
                              ),
                              SizedBox(height: grid.px(1)),
                              Text(
                                'Inspect Figma component boundaries and semantic spec overlays.',
                                style: PixelType.body(
                                  context,
                                  color: PixelPalette.cream,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: grid.px(3)),
                        PixelPanel(
                          style: PixelBoxStyle.parchment,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Designer Guide Mode',
                                        style: PixelType.title(context)),
                                    SizedBox(height: grid.px(1)),
                                    Text(
                                      isGuideEnabled
                                          ? 'Blueprint outlines and Figma component tags are ACTIVE.'
                                          : 'Show UI wireframe boundaries and Figma element specs.',
                                      style: PixelType.body(
                                        context,
                                        color: PixelPalette.slate,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: grid.px(2)),
                              PixelSwitch(
                                key: const ValueKey('designer_guide_switch'),
                                value: isGuideEnabled,
                                semanticLabel: 'Designer Guide Mode',
                                onChanged: (value) => ref
                                    .read(designerGuideProvider.notifier)
                                    .state = value,
                              ),
                            ],
                          ),
                        ),
                        if (ServerOverrideStore.isAvailable) ...[
                          SizedBox(height: grid.px(4)),
                          Text(
                            'Developer — API server',
                            style: PixelType.title(context),
                          ),
                          SizedBox(height: grid.px(1)),
                          Text(
                            'Debug and profile builds only. Point this device at another backend.',
                            style: PixelType.body(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                          SizedBox(height: grid.px(2)),
                          const _ApiServerOverrideCard(),
                          if (kDebugMode) ...[
                            SizedBox(height: grid.px(2)),
                            const MapOriginCard(),
                          ],
                          SizedBox(height: grid.px(2)),
                          _link(
                            context,
                            grid,
                            key: const ValueKey('settings_ar_diagnostics'),
                            title: 'AR diagnostics',
                            subtitle: 'Live sensor readout and a test object.',
                            onTap: () => context.push('/ar-diagnostics'),
                          ),
                          SizedBox(height: grid.px(2)),
                          _link(
                            context,
                            grid,
                            key: const ValueKey('settings_pixel_lab'),
                            title: 'Pixel lab',
                            subtitle:
                                'Designer pixel art in the brand palette.',
                            onTap: () => context.push('/settings/pixel-lab'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _link(
    BuildContext context,
    PixelGrid grid, {
    required Key key,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: PixelType.title(context)),
                  Text(
                    subtitle,
                    style: PixelType.body(
                      context,
                      color: PixelPalette.slate,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: grid.px(1)),
            Text('>',
                style: PixelType.title(context, color: PixelPalette.woodMid)),
          ],
        ),
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
              final state =
                  value is Map ? value['status'] ?? value['state'] : value;
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
    setState(() => _statusLine =
        'Saved. Requests now use ${ApiClient.apiBaseUrl} — restart if anything looks stale.');
  }

  Future<void> _reset() async {
    await ServerOverrideStore.clear();
    if (!mounted) return;
    setState(() {
      _controller.clear();
      _statusLine =
          'Override cleared. Default server: ${ApiClient.normalizeBaseUrl(ApiClient.apiBaseUrl)}';
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PixelTextField(
            key: const ValueKey('dev_api_url'),
            controller: _controller,
            label: 'API base URL',
            hint: 'http://192.168.1.20:4100',
            keyboardType: TextInputType.url,
          ),
          SizedBox(height: grid.px(2)),
          Text(
            _statusLine,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(2),
            children: [
              PixelButton(
                key: const ValueKey('dev_api_test'),
                label: 'Test connection',
                variant: PixelButtonVariant.secondary,
                onPressed: _busy ? null : _testConnection,
              ),
              PixelButton(
                key: const ValueKey('dev_api_save'),
                label: 'Save override',
                onPressed: _busy ? null : _save,
              ),
              PixelButton(
                key: const ValueKey('dev_api_reset'),
                label: 'Reset',
                variant: PixelButtonVariant.secondary,
                onPressed: _busy ? null : _reset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
