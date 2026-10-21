import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';

/// Same choices as the web onboarding (`/onboarding/interests`).
const travelInterests = <String, String>{
  'eat_drink': 'Food & coffee',
  'nature_outdoors': 'Nature',
  'culture_heritage': 'Culture',
  'activities_wellness': 'Sports & activities',
  'shopping_local': 'Local finds',
  'stay': 'Places to stay',
};

/// Decides whether to ask for interests after sign-in.
///
/// The server keeps preferences in memory and reports `pending` again after a
/// restart, so the device also remembers that this account already answered.
class InterestsPrompt {
  static const _storage = FlutterSecureStorage();
  static String _key(String userId) => 'jdq_interests_answered_$userId';

  static Future<bool> answeredOnDevice(String userId) async {
    try {
      return await _storage.read(key: _key(userId)) == 'true';
    } catch (_) {
      return false;
    }
  }

  static Future<void> markAnswered(String userId) async {
    try {
      await _storage.write(key: _key(userId), value: 'true');
    } catch (_) {}
  }

  /// Opens the interests screen once if the account has never answered.
  static Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(authProvider).user?.id;
    if (userId == null || await answeredOnDevice(userId)) return;
    try {
      final res =
          await ref.read(apiClientProvider).dio.get('/me/discovery-preferences');
      final data = res.data is Map ? res.data['data'] : null;
      final state = data is Map ? data['onboarding_state'] : null;
      if (state != 'pending') {
        await markAnswered(userId);
        return;
      }
    } catch (_) {
      return; // Never block the dashboard on this.
    }
    if (context.mounted) await context.push('/onboarding/interests');
  }
}

/// "What do you enjoy while traveling?" (Plan 47 B5).
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final Set<String> _selected = {};
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    try {
      final res =
          await ref.read(apiClientProvider).dio.get('/me/discovery-preferences');
      final data = res.data is Map ? res.data['data'] : null;
      final cats = data is Map ? data['categories'] : null;
      if (cats is List && mounted) {
        setState(() => _selected.addAll(
            cats.whereType<String>().where(travelInterests.containsKey)));
      }
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _finish(bool completed) async {
    setState(() => _saving = true);
    try {
      await ref.read(apiClientProvider).dio.put('/me/discovery-preferences', data: {
        'categories': completed ? _selected.toList() : <String>[],
        'tags': <String>[],
        'occasions': <String>[],
        'price_levels': <int>[],
        'radius_km': 25,
        'onboarding_state': completed ? 'completed' : 'skipped',
      });
      final userId = ref.read(authProvider).user?.id;
      if (userId != null) await InterestsPrompt.markAnswered(userId);
      if (!mounted) return;
      if (context.canPop()) {
        context.pop(true);
      } else {
        context.go('/explore');
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your interests. Try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Your interests')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.gutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PERSONALIZE YOUR DISCOVERIES',
                  style: AppTypography.labelMedium.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text('What do you enjoy while traveling?',
                  style: AppTypography.headlineSmall
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text('Choose any that fit. You can change these later in Settings.',
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: AppSpacing.lg),
              if (!_loaded)
                const Center(child: CircularProgressIndicator())
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in travelInterests.entries)
                      FilterChip(
                        key: ValueKey('interest_${e.key}'),
                        label: Text(e.value),
                        selected: _selected.contains(e.key),
                        onSelected: (on) => setState(() =>
                            on ? _selected.add(e.key) : _selected.remove(e.key)),
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                key: const ValueKey('interests_save'),
                label: 'Save my interests',
                isLoading: _saving,
                onPressed: _saving || _selected.isEmpty ? null : () => _finish(true),
              ),
              TextButton(
                key: const ValueKey('interests_skip'),
                onPressed: _saving ? null : () => _finish(false),
                child: const Text('Skip for now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
