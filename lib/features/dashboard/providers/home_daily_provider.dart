import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';

/// One assigned daily mission from `/me/daily`.
class HomeDailyMission {
  const HomeDailyMission({
    required this.id,
    required this.kind,
    required this.title,
    required this.stamps,
    required this.progress,
    required this.target,
    required this.completed,
  });

  final String id;
  final String kind;
  final String title;
  final int stamps;
  final int progress;
  final int target;
  final bool completed;

  factory HomeDailyMission.fromJson(Map<String, dynamic> row) =>
      HomeDailyMission(
        id: row['id']?.toString() ?? '',
        kind: row['kind']?.toString() ?? '',
        title: row['title']?.toString() ?? 'Daily mission',
        stamps: _int(row['stamps']),
        progress: _int(row['progress']),
        target: _int(row['target'], 1),
        completed: row['completed'] == true,
      );
}

class HomeStampDay {
  const HomeStampDay({
    required this.day,
    required this.stamps,
    required this.claimed,
  });

  final int day;
  final int stamps;
  final bool claimed;
}

/// The Home slice of the daily rewards state. Home reads the balance, the
/// seven-day claim strip, today's missions, the streak and the weekly cap;
/// the claim button lives on Home too.
class HomeDailyState {
  const HomeDailyState({
    required this.stamps,
    required this.missions,
    this.date = '',
    this.nextResetAt,
    this.claimToday = false,
    this.claimDay = 1,
    this.nominalStamps = 0,
    this.awardedStamps = 0,
    this.claimedDays = 0,
    this.calendar = const [],
    this.streak = 0,
    this.bestStreak = 0,
    this.shieldsHeld = 0,
    this.shieldsMax = 0,
    this.weekUsed = 0,
    this.weekCap = 0,
    this.chestCompleted = 0,
    this.chestRequired = 0,
    this.chestStamps = 0,
    this.chestEarned = false,
    this.capped = false,
  });

  final int stamps;
  final List<HomeDailyMission> missions;
  final String date;
  final DateTime? nextResetAt;
  final bool claimToday;
  final int claimDay;
  final int nominalStamps;
  final int awardedStamps;
  final int claimedDays;
  final List<HomeStampDay> calendar;
  final int streak;
  final int bestStreak;
  final int shieldsHeld;
  final int shieldsMax;
  final int weekUsed;
  final int weekCap;
  final int chestCompleted;
  final int chestRequired;
  final int chestStamps;
  final bool chestEarned;
  final bool capped;

  bool get allComplete =>
      missions.isNotEmpty && missions.every((mission) => mission.completed);

  HomeDailyMission? get nextMission {
    for (final mission in missions) {
      if (!mission.completed) return mission;
    }
    return missions.isEmpty ? null : missions.first;
  }

  HomeDailyState copyWith({
    int? stamps,
    bool? claimToday,
    int? awardedStamps,
  }) =>
      HomeDailyState(
        stamps: stamps ?? this.stamps,
        missions: missions,
        date: date,
        nextResetAt: nextResetAt,
        claimToday: claimToday ?? this.claimToday,
        claimDay: claimDay,
        nominalStamps: nominalStamps,
        awardedStamps: awardedStamps ?? this.awardedStamps,
        claimedDays: claimedDays,
        calendar: calendar,
        streak: streak,
        bestStreak: bestStreak,
        shieldsHeld: shieldsHeld,
        shieldsMax: shieldsMax,
        weekUsed: weekUsed,
        weekCap: weekCap,
        chestCompleted: chestCompleted,
        chestRequired: chestRequired,
        chestStamps: chestStamps,
        chestEarned: chestEarned,
        capped: capped,
      );

  factory HomeDailyState.fromJson(Map<String, dynamic> data) {
    final claim = (data['claim'] as Map?)?.cast<String, dynamic>() ?? const {};
    final streak =
        (data['streak'] as Map?)?.cast<String, dynamic>() ?? const {};
    final week = (data['week'] as Map?)?.cast<String, dynamic>() ?? const {};
    final chest = (data['chest'] as Map?)?.cast<String, dynamic>() ?? const {};
    final calendarRaw = claim['calendar'];
    final missionsRaw = data['missions'];
    return HomeDailyState(
      stamps: _int(data['balance']),
      missions: (missionsRaw is List ? missionsRaw : const [])
          .whereType<Map>()
          .map(
            (row) => HomeDailyMission.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(),
      date: data['date']?.toString() ?? '',
      nextResetAt: DateTime.tryParse(data['next_reset_at']?.toString() ?? ''),
      claimToday: claim['claimed_today'] == true,
      claimDay: _int(claim['cycle_day'], 1),
      nominalStamps: _int(claim['nominal_stamps']),
      awardedStamps: _int(claim['awarded']),
      claimedDays: _int(claim['claimed_days']),
      calendar: (calendarRaw is List ? calendarRaw : const [])
          .whereType<Map>()
          .map(
            (row) => HomeStampDay(
              day: _int(row['day']),
              stamps: _int(row['stamps']),
              claimed: row['claimed'] == true,
            ),
          )
          .toList(),
      streak: _int(streak['current']),
      bestStreak: _int(streak['best']),
      shieldsHeld: _int(streak['shields_held']),
      shieldsMax: _int(streak['shields_max']),
      weekUsed: _int(week['used']),
      weekCap: _int(week['cap']),
      chestCompleted: _int(chest['completed_missions']),
      chestRequired: _int(chest['required']),
      chestStamps: _int(chest['stamps']),
      chestEarned: chest['earned'] == true,
      capped: claim['capped'] == true,
    );
  }
}

int _int(Object? value, [int fallback = 0]) =>
    (value as num?)?.toInt() ?? fallback;

final homeDailyProvider = FutureProvider<HomeDailyState>((ref) async {
  final response = await ref.read(apiClientProvider).dio.get('/me/daily');
  final body = response.data;
  final data = body is Map ? body['data'] : null;
  if (data is! Map) {
    throw StateError('Daily rewards response was not understood.');
  }
  return HomeDailyState.fromJson(Map<String, dynamic>.from(data));
});

class HomeDailyClaimState {
  const HomeDailyClaimState({this.claiming = false, this.error, this.latest});

  final bool claiming;
  final String? error;

  /// The server state after a successful claim, so the card can show the new
  /// balance and the claimed day without a second request.
  final HomeDailyState? latest;
}

class HomeDailyClaimNotifier extends StateNotifier<HomeDailyClaimState> {
  HomeDailyClaimNotifier(this._ref) : super(const HomeDailyClaimState());

  final Ref _ref;
  bool _busy = false;
  static const _uuid = Uuid();

  Future<void> claim(HomeDailyState data) async {
    final alreadyClaimed =
        state.latest?.claimToday == true && state.latest?.date == data.date;
    if (_busy || data.claimToday || alreadyClaimed) return;
    _busy = true;
    state = const HomeDailyClaimState(claiming: true);
    try {
      final response = await _ref.read(apiClientProvider).dio.post(
            '/me/daily/claim',
            data: const <String, dynamic>{},
            options: Options(headers: {'Idempotency-Key': _uuid.v4()}),
          );
      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      final latest = raw is Map
          ? HomeDailyState.fromJson(Map<String, dynamic>.from(raw))
          : null;
      state = HomeDailyClaimState(latest: latest);
      _ref.invalidate(homeDailyProvider);
    } catch (_) {
      state = const HomeDailyClaimState(
        error: 'Could not claim today\'s stamps. Try again.',
      );
    } finally {
      _busy = false;
    }
  }
}

final homeDailyClaimProvider =
    StateNotifierProvider<HomeDailyClaimNotifier, HomeDailyClaimState>(
  (ref) => HomeDailyClaimNotifier(ref),
);
