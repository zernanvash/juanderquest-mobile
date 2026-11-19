import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:reown_appkit/reown_appkit.dart';

/// Wallet connection is only an authentication mechanism. It does not read,
/// mint, transfer, or convert any on-chain or off-chain balance.
class WalletSignatureService {
  static const projectId = String.fromEnvironment('REOWN_PROJECT_ID');
  static const redirectUri = 'juanderquest://wallet';

  static bool get isConfigured => projectId.trim().isNotEmpty;

  static Future<ReownAppKitModal> initialize(BuildContext context) async {
    if (!isConfigured) {
      throw StateError('Wallet sign-in is not configured in this build.');
    }
    final modal = ReownAppKitModal(
      context: context,
      projectId: projectId,
      disconnectOnDispose: false,
      metadata: const PairingMetadata(
        name: 'JuanDerQuest',
        description: 'Traveler passport sign-in; no token transaction',
        url: 'https://juanderquest.app',
        icons: ['https://juanderquest.app/favicon.ico'],
        redirect: Redirect(native: redirectUri),
      ),
    );
    await modal.init();
    return modal;
  }

  static String? connectedAddress(ReownAppKitModal modal) {
    final address = modal.session?.getAddress('eip155');
    if (address == null || !RegExp(r'^0x[a-fA-F0-9]{40}$').hasMatch(address)) {
      return null;
    }
    return address;
  }

  /// Ensures a wallet session is connected with minimal clicks:
  /// - If already connected, returns the address immediately.
  /// - Otherwise opens the Reown wallet picker directly and resolves as soon
  ///   as a wallet connects (or returns null if the user cancels).
  static Future<String?> ensureConnected(ReownAppKitModal modal) async {
    final existing = connectedAddress(modal);
    if (existing != null) return existing;

    final completer = Completer<String?>();
    void onConnect(ModalConnect? _) {
      final addr = connectedAddress(modal);
      if (addr != null && !completer.isCompleted) {
        completer.complete(addr);
      }
    }

    void onError(ModalError? err) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(err?.message ?? 'Wallet connection failed.'),
        );
      }
    }

    modal.onModalConnect.subscribe(onConnect);
    modal.onModalError.subscribe(onError);
    try {
      await modal.openModalView();
      if (!completer.isCompleted) {
        completer.complete(connectedAddress(modal));
      }
      return await completer.future;
    } finally {
      modal.onModalConnect.unsubscribe(onConnect);
      modal.onModalError.unsubscribe(onError);
    }
  }

  static String personalSignPayload(String message) {
    final bytes = utf8.encode(message);
    return '0x${bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join()}';
  }

  static Future<String> signChallenge(ReownAppKitModal modal, String message) async {
    final address = connectedAddress(modal);
    final session = modal.session;
    if (address == null || session == null) {
      throw StateError('Connect an EVM wallet before signing in.');
    }
    if (!(modal.getApprovedMethods(namespace: 'eip155')?.contains('personal_sign') ?? false)) {
      throw StateError('This wallet did not approve message signing.');
    }
    final signature = await modal.request(
      topic: session.topic,
      chainId: session.chainId,
      request: SessionRequestParams(
        method: 'personal_sign',
        params: [personalSignPayload(message), address],
      ),
    );
    if (signature is! String || !RegExp(r'^0x[a-fA-F0-9]{130}$').hasMatch(signature)) {
      throw StateError('Wallet did not return a valid EOA signature.');
    }
    return signature;
  }
}
