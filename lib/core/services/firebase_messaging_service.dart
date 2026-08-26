import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final firebaseMessagingServiceProvider = Provider<FirebaseMessagingService>((ref) {
  return FirebaseMessagingService();
});

/// Service for managing Firebase In-App Messaging & Analytics triggers in JuanDerQuest
class FirebaseMessagingService {
  final FirebaseInAppMessaging _fiam = FirebaseInAppMessaging.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  /// Trigger a custom analytics event to activate In-App Messaging campaigns
  Future<void> triggerEvent(String eventName, [Map<String, Object>? parameters]) async {
    try {
      await _analytics.logEvent(name: eventName, parameters: parameters);
      debugPrint('[FIAM] Triggered event: $eventName with params: $parameters');
    } catch (e) {
      debugPrint('[FIAM] Note logging event $eventName: $e');
    }
  }

  /// Suppress or enable In-App message popups (e.g. during active AR viewfinder scanning)
  Future<void> setMessagesSuppressed(bool suppressed) async {
    try {
      await _fiam.setMessagesSuppressed(suppressed);
      debugPrint('[FIAM] Messages suppressed: $suppressed');
    } catch (e) {
      debugPrint('[FIAM] Note setting message suppression: $e');
    }
  }

  /// Trigger campaign message for completed quest
  Future<void> logQuestCompleted({
    required String questId,
    required String title,
    required int rewardPoints,
  }) async {
    await triggerEvent('quest_completed', {
      'quest_id': questId,
      'quest_title': title,
      'reward_points': rewardPoints,
    });
  }

  /// Trigger campaign message when exploring a destination spot
  Future<void> logSpotExplored({
    required String spotId,
    required String spotName,
    required String municipality,
  }) async {
    await triggerEvent('spot_explored', {
      'spot_id': spotId,
      'spot_name': spotName,
      'municipality': municipality,
    });
  }

  /// Trigger campaign message when finding simulated AR marker
  Future<void> logArMarkerFound({
    required String questId,
    required String locationName,
  }) async {
    await triggerEvent('ar_marker_found', {
      'quest_id': questId,
      'location_name': locationName,
    });
  }

  /// Trigger campaign message when voting on DAO governance proposal
  Future<void> logProposalVoted({
    required String proposalId,
    required String choice,
  }) async {
    await triggerEvent('proposal_voted', {
      'proposal_id': proposalId,
      'vote_choice': choice,
    });
  }

  /// Trigger campaign message when redeeming a merchant voucher
  Future<void> logVoucherRedeemed({
    required String voucherId,
    required String merchantName,
    required int cost,
  }) async {
    await triggerEvent('voucher_redeemed', {
      'voucher_id': voucherId,
      'merchant_name': merchantName,
      'cost_points': cost,
    });
  }
}
