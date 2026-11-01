import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';
import 'builder_models.dart';

class QrSheetTask {
  final String taskKey;
  final int stepOrder;
  final String title;
  final String markerCode;
  final String qrPayload;
  final String scanMode; // 'traveler_scans' | 'host_scans_traveler'
  final GeoFence? fence;

  const QrSheetTask({
    required this.taskKey,
    required this.stepOrder,
    required this.title,
    required this.markerCode,
    required this.qrPayload,
    required this.scanMode,
    this.fence,
  });

  factory QrSheetTask.fromJson(Map<String, dynamic> json) => QrSheetTask(
        taskKey: json['task_key'] as String? ?? '',
        stepOrder: (json['step_order'] as num?)?.toInt() ?? 1,
        title: json['title'] as String? ?? '',
        markerCode: json['marker_code'] as String? ?? '',
        qrPayload: json['qr_payload'] as String? ?? '',
        scanMode: json['scan_mode'] as String? ?? 'traveler_scans',
        fence: json['fence'] is Map<String, dynamic>
            ? GeoFence.fromJson(json['fence'] as Map<String, dynamic>)
            : null,
      );
}

class QrSheetData {
  final String questId;
  final String questTitle;
  final String locationName;
  final List<QrSheetTask> qrTasks;

  const QrSheetData({
    required this.questId,
    required this.questTitle,
    required this.locationName,
    required this.qrTasks,
  });

  factory QrSheetData.fromJson(Map<String, dynamic> json) => QrSheetData(
        questId: json['quest_id'] as String? ?? '',
        questTitle: json['quest_title'] as String? ?? '',
        locationName: json['location_name'] as String? ?? '',
        qrTasks: (json['qr_tasks'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(QrSheetTask.fromJson)
            .toList(),
      );
}

class QuestBuilderRepository {
  final ApiClient _client;

  QuestBuilderRepository(this._client);

  /// Fetch full quest definition for editing: GET /quests/:id/edit
  Future<Map<String, dynamic>> getQuestForEdit(String questId) async {
    final res = await _client.dio.get('/quests/$questId/edit');
    final data = res.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    return Map<String, dynamic>.from(data as Map);
  }

  /// Create author quest: POST /spots/:spotIdOrSlug/quests
  Future<String> createQuest({
    required String spotIdOrSlug,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client.dio.post(
      '/spots/${Uri.encodeComponent(spotIdOrSlug)}/quests',
      data: payload,
    );
    final data = res.data;
    if (data is Map<String, dynamic>) {
      final inner = data['data'];
      if (inner is Map<String, dynamic> && inner['id'] != null) {
        return inner['id'].toString();
      }
    }
    throw Exception('Failed to parse created quest ID');
  }

  /// Save author quest edit: PATCH /quests/:id. Returns the server's new
  /// version (editing a published quest bumps it) so the next save is not a 409.
  Future<int?> patchQuest({
    required String questId,
    required Map<String, dynamic> payload,
  }) async {
    final res = await _client.dio.patch(
      '/quests/$questId',
      data: payload,
    );
    final data = res.data;
    final inner = data is Map ? data['data'] : null;
    final version = inner is Map ? inner['version'] : null;
    return version is num ? version.toInt() : null;
  }

  /// Update quest status: PATCH /quests/:id/status
  Future<void> updateQuestStatus({
    required String questId,
    required String status,
  }) async {
    await _client.dio.patch(
      '/quests/$questId/status',
      data: {'status': status},
    );
  }

  /// Fetch QR sheet data: GET /quests/:id/qr-sheet
  Future<QrSheetData> getQrSheet(String questId) async {
    final res = await _client.dio.get('/quests/$questId/qr-sheet');
    final data = res.data;
    if (data is Map<String, dynamic> && data['data'] is Map<String, dynamic>) {
      return QrSheetData.fromJson(Map<String, dynamic>.from(data['data'] as Map));
    }
    return QrSheetData.fromJson(Map<String, dynamic>.from(data as Map));
  }
}

final questBuilderRepositoryProvider = Provider<QuestBuilderRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return QuestBuilderRepository(client);
});
