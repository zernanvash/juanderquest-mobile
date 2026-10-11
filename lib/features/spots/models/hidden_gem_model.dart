/// A personalized lower-activity destination from `GET /spots/highlights`.
///
/// Mirrors the bounded public payload of `backend/src/spots/highlights.ts`;
/// the API never returns internal scores or actor history.
class HiddenGemModel {
  final String id;
  final String name;
  final String municipality;
  final String? imageUrl;
  final String crowdStatus;
  final String reason;

  const HiddenGemModel({
    required this.id,
    required this.name,
    required this.municipality,
    this.imageUrl,
    this.crowdStatus = 'unknown',
    this.reason = 'Discover somewhere different',
  });

  factory HiddenGemModel.fromJson(Map<String, dynamic> json) {
    final image = json['image_url'] as String?;
    return HiddenGemModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      municipality: json['municipality'] as String? ?? '',
      imageUrl: image != null && image.isNotEmpty ? image : null,
      crowdStatus: json['crowd_status'] as String? ?? 'unknown',
      reason: json['reason'] as String? ?? 'Discover somewhere different',
    );
  }

  /// Crowd copy stays honest: the backend only estimates, it never measures.
  String get crowdLabel => switch (crowdStatus) {
        'quiet' => 'Usually quiet',
        'moderate' => 'Some activity reported',
        _ => 'Crowd level not yet reported',
      };
}
