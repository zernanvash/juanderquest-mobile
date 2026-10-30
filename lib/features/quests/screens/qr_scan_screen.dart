import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(
            key: const ValueKey('qr_torch'),
            tooltip: 'Flashlight',
            icon: const Icon(Icons.flashlight_on_rounded),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Camera access is off. Allow it in Settings, or enter the code instead.'
                      : 'The camera could not start. Enter the code instead.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFFFB703), width: 3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              minimum: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _rejected ?? 'Point your camera at the QR code.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    key: const ValueKey('qr_enter_code'),
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                    ),
                    child: const Text('Enter code instead'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
