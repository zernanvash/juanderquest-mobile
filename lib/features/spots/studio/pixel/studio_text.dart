import '../../utils/spot_posting.dart';

/// Strips a leading emoji/colour glyph from a category label, keeping the
/// sentence-case text the studio shows ("Nature & Beaches", not a wave emoji).
String studioPlainLabel(String raw) {
  final match = RegExp(r'[A-Za-z]').firstMatch(raw);
  if (match == null) return raw.trim();
  return raw.substring(match.start).trim();
}

String studioCategoryName(String id) => studioPlainLabel(categoryLabel(id));

String studioSubcategoryName(String sub) => sub.replaceAll('_', ' ');

/// One clear bottom-bar hint, or a short list when several required fields are
/// still missing. Validation itself stays in `validatePostingDraft`.
String? studioReadinessHint(SpotPostingDraft draft) {
  final errors = validatePostingDraft(draft);
  final missing = <String>[];
  if (errors.containsKey('pin')) missing.add('pin');
  if (errors.containsKey('name')) missing.add('name');
  if (errors.containsKey('description')) missing.add('story');
  if (errors.containsKey('municipality') || errors.containsKey('address')) {
    missing.add('town');
  }
  if (errors.containsKey('category') || errors.containsKey('subcategory')) {
    missing.add('category');
  }
  if (missing.isEmpty) return null;
  if (missing.length > 1) return 'Add: ${missing.join(', ')}';
  return switch (missing.single) {
    'pin' => 'Place the pin on the map',
    'name' => 'Add a name for this place',
    'story' => 'Tap a story starter or add a short description',
    'town' => 'Add the town and a landmark',
    _ => 'Choose a category',
  };
}
