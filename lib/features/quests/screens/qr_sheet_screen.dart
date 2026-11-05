import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
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
    _future =
        ref.read(questBuilderRepositoryProvider).getQrSheet(widget.questId);
  }

  void _reload() {
    setState(() {
      _future =
          ref.read(questBuilderRepositoryProvider).getQrSheet(widget.questId);
    });
  }

  void _showFullScreenQr(
      BuildContext context, QrSheetTask task, String locationName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Theme(
          data: AppTheme.pixel,
          child: Builder(
            builder: (context) {
              final grid = PixelGrid.of(context);
              return Scaffold(
                backgroundColor: PixelPalette.paper,
                body: DitherBackground(
                  top: PixelPalette.paper,
                  bottom: PixelPalette.parchment,
                  child: Column(
                    children: [
                      PixelAppBar(
                        title: 'Step ${task.stepOrder}: ${task.title}',
                        onBack: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.fromLTRB(
                            grid.px(4),
                            grid.px(3),
                            grid.px(4),
                            grid.px(8),
                          ),
                          children: [
                            PixelPanel(
                              style: PixelBoxStyle.wood,
                              child: Column(
                                children: [
                                  Text(
                                    'JUANDERQUEST CHALLENGE PLACARD',
                                    style: PixelType.small(
                                      context,
                                      color: PixelPalette.sun,
                                    ),
                                  ),
                                  SizedBox(height: grid.px(1)),
                                  Text(
                                    '${task.stepOrder}. ${task.title}',
                                    textAlign: TextAlign.center,
                                    style: PixelType.title(
                                      context,
                                      color: PixelPalette.paper,
                                    ),
                                  ),
                                  Text(
                                    locationName,
                                    textAlign: TextAlign.center,
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.cream,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: grid.px(3)),
                            Center(
                              child: Container(
                                color: PixelPalette.white,
                                padding: EdgeInsets.all(grid.px(2)),
                                child: QrImageView(
                                  data: task.qrPayload,
                                  version: QrVersions.auto,
                                  size: 260.0,
                                  backgroundColor: PixelPalette.white,
                                ),
                              ),
                            ),
                            SizedBox(height: grid.px(3)),
                            PixelPanel(
                              style: PixelBoxStyle.slot,
                              child: Text(
                                'Code: ${task.markerCode}',
                                textAlign: TextAlign.center,
                                style: PixelType.numbers(context),
                              ),
                            ),
                            SizedBox(height: grid.px(2)),
                            Text(
                              'Display this on your phone or print it for travelers to scan on site.',
                              textAlign: TextAlign.center,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _shareCode(BuildContext context, QrSheetTask task) {
    Clipboard.setData(ClipboardData(text: task.markerCode));
    showPixelToast(
        context, 'Marker code copied to clipboard: ${task.markerCode}');
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'QR Sheet & Placards',
                    onBack: () => Navigator.of(context).pop(),
                  ),
                  Expanded(
                    child: FutureBuilder<QrSheetData>(
                      future: _future,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: PixelLoader(label: 'Loading QR sheet'),
                          );
                        }
                        if (snapshot.hasError) {
                          final error = snapshot.error;
                          final bool is403 = (error is DioException &&
                                  error.response?.statusCode == 403) ||
                              (error?.toString().contains('403') ?? false);
                          final String message;
                          if (is403) {
                            message =
                                'Only the quest creator or an LGU admin can print QR placards for this quest';
                          } else if (error is DioException) {
                            final data = error.response?.data;
                            String? serverMsg;
                            if (data is Map && data['error'] is Map) {
                              serverMsg = data['error']['message']?.toString();
                            }
                            message = serverMsg ??
                                'Failed to load QR sheet. Please check your connection.';
                          } else {
                            message =
                                'Failed to load QR sheet. Please check your connection.';
                          }
                          return ListView(
                            padding: EdgeInsets.all(grid.px(4)),
                            children: [
                              PixelPanel(
                                style: is403
                                    ? PixelBoxStyle.parchment
                                    : PixelBoxStyle.red,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message,
                                      style: PixelType.body(
                                        context,
                                        color: is403
                                            ? PixelPalette.ink
                                            : PixelPalette.white,
                                      ),
                                    ),
                                    if (!is403) ...[
                                      SizedBox(height: grid.px(3)),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: PixelButton(
                                          key: const ValueKey('qr_sheet_retry'),
                                          label: 'Retry',
                                          onPressed: _reload,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        final data = snapshot.data!;
                        final printableTasks = data.qrTasks
                            .where((t) => t.scanMode != 'host_scans_traveler')
                            .toList();
                        final hostScanTasks = data.qrTasks
                            .where((t) => t.scanMode == 'host_scans_traveler')
                            .toList();

                        return ListView(
                          padding: EdgeInsets.fromLTRB(
                            grid.px(4),
                            grid.px(3),
                            grid.px(4),
                            grid.px(8) + MediaQuery.paddingOf(context).bottom,
                          ),
                          children: [
                            PixelPanel(
                              style: PixelBoxStyle.parchment,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(data.questTitle,
                                      style: PixelType.title(context)),
                                  Text(
                                    data.locationName,
                                    style: PixelType.body(
                                      context,
                                      color: PixelPalette.slate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (hostScanTasks.isNotEmpty) ...[
                              SizedBox(height: grid.px(2)),
                              PixelPanel(
                                style: PixelBoxStyle.gold,
                                child: Text(
                                  'No placard needed for: ${hostScanTasks.map((t) => "${t.stepOrder}. ${t.title}").join(", ")}. Hosts scan the traveler\'s pass in the app — nothing to print.',
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.goldDeep,
                                  ),
                                ),
                              ),
                            ],
                            if (printableTasks.isEmpty &&
                                hostScanTasks.isEmpty) ...[
                              SizedBox(height: grid.px(6)),
                              const PixelEmptyState(
                                key: ValueKey('qr_sheet_empty'),
                                title: 'No QR tasks',
                                message:
                                    'This quest does not contain any QR verification tasks.',
                              ),
                            ],
                            SizedBox(height: grid.px(3)),
                            for (final task in printableTasks) ...[
                              _placard(context, grid, task, data.locationName),
                              SizedBox(height: grid.px(3)),
                            ],
                          ],
                        );
                      },
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

  Widget _placard(BuildContext context, PixelGrid grid, QrSheetTask task,
      String locationName) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        children: [
          const PixelChip('ON-SITE PLACARD'),
          SizedBox(height: grid.px(2)),
          Text(
            '${task.stepOrder}. ${task.title}',
            textAlign: TextAlign.center,
            style: PixelType.title(context),
          ),
          Text(
            locationName,
            textAlign: TextAlign.center,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(3)),
          Container(
            color: PixelPalette.white,
            padding: EdgeInsets.all(grid.px(2)),
            child: QrImageView(
              data: task.qrPayload,
              version: QrVersions.auto,
              size: 180.0,
              backgroundColor: PixelPalette.white,
            ),
          ),
          SizedBox(height: grid.px(2)),
          PixelPanel(
            style: PixelBoxStyle.slot,
            child: Text(
              'Code: ${task.markerCode}',
              style: PixelType.numbers(context),
            ),
          ),
          SizedBox(height: grid.px(3)),
          PixelButton(
            key: ValueKey('qr_copy_${task.taskKey}'),
            label: 'Copy code',
            variant: PixelButtonVariant.secondary,
            expand: true,
            onPressed: () => _shareCode(context, task),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            key: ValueKey('qr_full_${task.taskKey}'),
            label: 'Full screen',
            expand: true,
            onPressed: () => _showFullScreenQr(context, task, locationName),
          ),
        ],
      ),
    );
  }
}
