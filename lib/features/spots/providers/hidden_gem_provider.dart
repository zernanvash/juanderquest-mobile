import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/hidden_gem_model.dart';

/// Personalized Hidden Gem recommendations for the Explore feed.
///
/// Personalization happens server-side from the authenticated token
/// (interests + server-saved/liked places). Watching the user id makes the
/// card refetch when the traveler signs in or out.
final hiddenGemProvider = FutureProvider<List<HiddenGemModel>>((ref) async {
  ref.watch(authProvider.select((state) => state.user?.id));
  final response = await ref.read(apiClientProvider).dio.get('/spots/highlights');
  final data = response.data;
  if (data is! Map || data['data'] is! List) return const [];
  return (data['data'] as List)
      .whereType<Map>()
      .map((item) => HiddenGemModel.fromJson(Map<String, dynamic>.from(item)))
      .where((gem) => gem.id.isNotEmpty && gem.name.isNotEmpty)
      .toList();
});
