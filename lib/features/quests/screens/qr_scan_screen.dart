import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';

/// Pulls the marker code out of a scanned QR payload.
///
/// Plan 43 QR sheets encode the raw `marker_code`. Links that carry it as a
/// `code`/`marker` query parameter are accepted too.
String? extractMarkerCode(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri != null && uri.hasScheme && uri.host.isNotEmpty) {
    final q = uri.queryParameters['code'] ?? uri.queryParameters['marker'];
    if (q != null && q.trim().isNotEmpty) return q.trim();
    return null;
  }
  return text.length <= 200 ? text : null;
}

/// Full-screen QR scanner. Pops with the accepted code, or null on cancel.
/// [extract] decides what is accepted (checkpoint marker codes by default).
class QrScanScreen extends StatefulWidget {
  final String title;
  final String? Function(String? raw) extract;
  final String rejectedMessage;

  const QrScanScreen({
    super.key,
    this.title = 'Scan the checkpoint QR',
    this.extract = extractMarkerCode,
    this.rejectedMessage = 'That QR code is not a JuanDerQuest checkpoint.',
  });

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _done = false;
  String? _rejected;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_done) return;
    for (final b in capture.barcodes) {
      final code = widget.extract(b.rawValue);
      if (code != null) {
        _done = true;
        Navigator.of(context).pop(code);
        return;
      }
    }
    setState(() => _rejected = widget.rejectedMessage);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.ink,
            body: Column(
              children: [
                PixelAppBar(
                  title: widget.title,
                  onBack:
                      canPop ? () => Navigator.of(context).maybePop() : null,
                  actions: [
                    PixelButton(
                      key: const ValueKey('qr_torch'),
                      label: 'Torch',
                      variant: PixelButtonVariant.secondary,
                      onPressed: () => _controller.toggleTorch(),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _controller,
                        onDetect: _onDetect,
                        errorBuilder: (context, error) => Center(
                          child: Padding(
                            padding: EdgeInsets.all(grid.px(6)),
                            child: Text(
                              error.errorCode ==
                                      MobileScannerErrorCode.permissionDenied
                                  ? 'Camera access is off. Allow it in Settings, or enter the code instead.'
                                  : 'The camera could not start. Enter the code instead.',
                              textAlign: TextAlign.center,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.paper,
                              ),
                            ),
                          ),
                        ),
                      ),
                      IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: grid.px(120),
                            height: grid.px(120),
                            child: CustomPaint(
                              painter: _PixelFramePainter(grid),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.bottomCenter,
                        child: SafeArea(
                          minimum: EdgeInsets.all(grid.px(4)),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                  fit: FlexFit.loose,
                                  child: SingleChildScrollView(
                                      child: PixelPanel(
                                    style: PixelBoxStyle.inkDialogue,
                                    child: Text(
                                      _rejected ??
                                          'Point your camera at the QR code.',
                                      textAlign: TextAlign.center,
                                      style: PixelType.body(
                                        context,
                                        color: PixelPalette.paper,
                                      ),
                                    ),
                                  ))),
                              SizedBox(height: grid.px(2)),
                              PixelButton(
                                key: const ValueKey('qr_enter_code'),
                                label: 'Enter code instead',
                                expand: true,
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PixelFramePainter extends CustomPainter {
  _PixelFramePainter(this.grid);

  final PixelGrid grid;

  @override
  void paint(Canvas canvas, Size size) {
    final u = grid.unit;
    final paint = Paint()
      ..color = PixelPalette.sun
      ..isAntiAlias = false;
    final w = (size.width / u).floor();
    final h = (size.height / u).floor();
    const arm = 10;
    const thick = 2;
    for (var i = 0; i < arm; i++) {
      for (var t = 0; t < thick; t++) {
        canvas.drawRect(
          Rect.fromLTWH(
              grid.snap(i * u), grid.snap(t * u), grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap((w - 1 - i) * u), grid.snap(t * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap(i * u), grid.snap((h - 1 - t) * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap((w - 1 - i) * u), grid.snap((h - 1 - t) * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(
              grid.snap(t * u), grid.snap(i * u), grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap((w - 1 - t) * u), grid.snap(i * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap(t * u), grid.snap((h - 1 - i) * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
        canvas.drawRect(
          Rect.fromLTWH(grid.snap((w - 1 - t) * u), grid.snap((h - 1 - i) * u),
              grid.snap(u), grid.snap(u)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PixelFramePainter old) => old.grid.unit != grid.unit;
}
