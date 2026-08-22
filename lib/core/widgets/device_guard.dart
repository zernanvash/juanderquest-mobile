import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

class DeviceGuard extends StatefulWidget {
  final Widget child;

  const DeviceGuard({super.key, required this.child});

  @override
  State<DeviceGuard> createState() => _DeviceGuardState();
}

class _DeviceGuardState extends State<DeviceGuard> {
  bool _overrideBypass = false;

  Future<void> _launchApkUrl() async {
    final Uri url = Uri.parse('https://jdq.zernanvash.dev/downloads/juanderquest-latest.apk');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      print('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebMobile = kIsWeb && MediaQuery.of(context).size.width < 768;

    if (!isWebMobile || _overrideBypass) {
      return widget.child;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFB703).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFFFB703), width: 3),
                  ),
                  child: const Icon(
                    Icons.desktop_windows_rounded,
                    size: 44,
                    color: Color(0xFF7D5800),
                  ),
                ),
                const SizedBox(height: 24),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3F6653).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'JUANDERQUEST WEB • DESKTOP ONLY',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF3F6653),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                Text(
                  'Optimized for Desktop End-to-End Testing',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.epilogue(
                    color: const Color(0xFF582F0E),
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),

                Text(
                  'The web version of JuanDerQuest is specifically tailored for desktop evaluation and end-to-end testing. For real-time GPS location tracking and AR camera marker validation, please download and install the official Android mobile app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF514532),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),

                ElevatedButton.icon(
                  onPressed: _launchApkUrl,
                  icon: const Icon(Icons.android_rounded, size: 22),
                  label: Text(
                    'Download Android Mobile App (APK)',
                    style: GoogleFonts.epilogue(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: const Color(0xFF2D6A4F),
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _overrideBypass = true;
                    });
                  },
                  icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Color(0xFF7D5800)),
                  label: Text(
                    'Continue in Web Test Mode anyway',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF7D5800),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'JuanDerQuest • School of Information Technology Education • Universidad de Dagupan',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: const Color(0xFF837560),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
