import '../quests/screens/qr_scan_screen.dart';
import '../suki/suki_codes.dart';

/// Parsed destination/action for any QR code scanned in the unified Quick QR Hub.
sealed class QuickQrResult {
  const QuickQrResult();
}

final class SukiStandeeQr extends QuickQrResult {
  const SukiStandeeQr(this.standeeUrl);
  final String standeeUrl;
}

final class SpotLinkQr extends QuickQrResult {
  const SpotLinkQr(this.slug);
  final String slug;
}

final class QuestLinkQr extends QuickQrResult {
  const QuestLinkQr(this.questId);
  final String questId;
}

final class ProfileLinkQr extends QuickQrResult {
  const ProfileLinkQr(this.handle);
  final String handle;
}

final class WalletAddressQr extends QuickQrResult {
  const WalletAddressQr(this.address);
  final String address;
}

final class CheckpointCodeQr extends QuickQrResult {
  const CheckpointCodeQr(this.code);
  final String code;
}

final _evmAddressPattern = RegExp(r'^(?:ethereum:)?(0x[a-fA-F0-9]{40})(?:@.*)?$');

/// Auto-detects the payload type of a scanned QR string.
/// Returns `null` when the payload is empty or unrecognized.
QuickQrResult? parseQuickQrPayload(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return null;

  final standee = extractSukiStandee(text);
  if (standee != null) return SukiStandeeQr(standee);

  final evmMatch = _evmAddressPattern.firstMatch(text);
  if (evmMatch != null) {
    return WalletAddressQr(evmMatch.group(1)!);
  }

  final uri = Uri.tryParse(text);
  if (uri != null &&
      (uri.host == 'juanderquest.app' || uri.scheme == 'juanderquest')) {
    final segs = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segs.length >= 2) {
      if (segs[0] == 'explore' || segs[0] == 'spots') {
        return SpotLinkQr(segs[1]);
      }
      if (segs[0] == 'quests') {
        return QuestLinkQr(segs[1]);
      }
      if (segs[0] == 'profile') {
        return ProfileLinkQr(segs[1]);
      }
    }
    if (uri.scheme == 'juanderquest' && uri.host == 'profile' && segs.isNotEmpty) {
      return ProfileLinkQr(segs.first);
    }
  }

  final marker = extractMarkerCode(text);
  if (marker != null) return CheckpointCodeQr(marker);

  return null;
}
