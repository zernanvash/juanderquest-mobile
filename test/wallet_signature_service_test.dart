import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/auth/services/wallet_signature_service.dart';

void main() {
  test('personal_sign payload uses UTF-8 bytes, not a fabricated signature', () {
    expect(WalletSignatureService.personalSignPayload('JuanDerQuest'),
        '0x4a75616e4465725175657374');
    expect(WalletSignatureService.personalSignPayload('Pangasinan 🏝️'),
        '0x50616e676173696e616e20f09f8f9defb88f');
  });

  test('wallet connection is gated on a nonblank project ID', () {
    expect(WalletSignatureService.isConfigured,
        WalletSignatureService.projectId.trim().isNotEmpty);
  });
}
