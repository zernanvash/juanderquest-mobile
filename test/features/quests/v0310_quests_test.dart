import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/screens/quest_detail_screen.dart';
import 'package:juanderquest_app/features/quests/screens/quest_funding_screen.dart';

// v0.3.10 team review (2026-11-19): author actions on their own quest, the
// accepted-quest idle countdown, the funding overview and the close warning.

class _SignedIn extends AuthNotifier {
  _SignedIn(super.client, super.refresh, String id) {
    state = AuthState(
      token: 'test-token',
      user: UserModel(
        id: id,
        seedId: id,
        displayName: id,
        email: '$id@example.test',
        avatarUrl: '',
        role: 'explorer',
        demoPoints: 0,
      ),
    );
  }
}

final _quest = QuestModel(
  id: 'quest-1',
  title: 'Coastal cleanup',
  description: 'Help care for this destination.',
  category: 'eco',
  locationName: 'Coast',
  gpsLat: 16,
  gpsLng: 120,
  radiusMeters: 100,
  rewardPoints: 50,
  markerImageUrl: '',
  authorId: 'author-1',
  steps: const [
    QuestStepModel(
      order: 1,
      title: 'Photo evidence',
      description: 'Document the cleanup.',
      checkpointType: 'photo',
      required: true,
    ),
  ],
);

Map<String, dynamic> _attempt(
        {required String expires, String step = 'ready'}) =>
    {
      'id': 'attempt-1',
      'quest_id': 'quest-1',
      'user_id': 'traveler-1',
      'status': 'in_progress',
      'verified_steps': step == 'verified' ? 1 : 0,
      'required_steps': 1,
      'idle_expires_at': expires,
      'steps': [
        {
          'step_order': 1,
          'title': 'Photo evidence',
          'description': 'Document the cleanup.',
          'checkpoint_type': 'photo',
          'required': true,
          'status': step,
        }
      ],
    };

Future<int> _pumpDetail(
  WidgetTester tester, {
  required String userId,
  Map<String, dynamic>? progress,
}) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (o.path == '/quests/quest-1/progress') {
      return h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'success': true,
        'data': progress ?? {'has_completed': false, 'active_attempt': null},
      }));
    }
    return h.reject(DioException(requestOptions: o));
  }));
  var gpsReads = 0;
  await tester.pumpWidget(ProviderScope(
    overrides: [
      apiClientProvider.overrideWithValue(client),
      questAcceptPositionProvider.overrideWithValue(() async {
        gpsReads++;
        return null;
      }),
      authProvider.overrideWith((ref) => _SignedIn(ref.read(apiClientProvider),
          ref.read(authRefreshProvider.notifier), userId)),
    ],
    child: MaterialApp(home: QuestDetailScreen(quest: _quest)),
  ));
  await tester.pumpAndSettle();
  return gpsReads;
}

Map<String, dynamic> _plan({String status = 'active'}) => {
      'id': 'plan-1',
      'quest_id': 'quest-1',
      'status': status,
      'mode': 'budget',
      'reward_points': 50,
      'fee_points': 3,
      'planned_completions': 4,
      'target_points': '212',
      'ends_at': '2026-12-02T11:12:00.000Z',
      'contributions': [
        {
          'funder_kind': 'author',
          'committed_points': '162',
          'remaining_points': '56',
          'held_points': '53',
          'paid_reward_points': '50',
          'paid_fee_points': '3',
          'refunded_points': '0',
          'created_at': '2026-11-18T11:12:14.000Z',
        },
        {
          'funder_kind': 'merchant',
          'merchant_id': 'm-1',
          'committed_points': '50',
          'remaining_points': '50',
          'held_points': '0',
          'paid_reward_points': '0',
          'paid_fee_points': '0',
          'refunded_points': '0',
          'created_at': '2026-11-18T12:00:00.000Z',
        },
      ],
      'holds': [
        {
          'status': 'paid',
          'reward_points': 50,
          'created_at': '2026-11-18T13:00:00.000Z',
          'settled_at': '2026-11-18T15:00:00.000Z',
        },
        {
          'status': 'held',
          'attempt_status': 'submitted',
          'reward_points': 50,
          'created_at': '2026-11-19T01:00:00.000Z',
        },
      ],
      'sponsorships': [
        {
          'id': 'sp-1',
          'merchant_name': 'Patar Cove Bakery',
          'status': 'requested',
          'points': 40,
          'created_at': '2026-11-19T02:00:00.000Z',
        },
      ],
      'summary': {
        'committed_points': 212,
        'remaining_points': 106,
        'held_points': 53,
        'paid_points': 53,
        'refunded_points': 0,
        'completions_left': 2,
        'holds': {'active': 1, 'pending_review': 1, 'paid': 1, 'released': 0},
      },
    };

Future<List<String>> _pumpFunding(WidgetTester tester) async {
  tester.view.physicalSize = const Size(720, 1600);
  tester.view.devicePixelRatio = 2;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final posts = <String>[];
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    if (o.method == 'POST') posts.add(o.path);
    if (o.path == '/quests/quest-1/funding-plan') {
      return h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'success': true,
        'data': {'plan': _plan()},
      }));
    }
    return h.resolve(
        Response(requestOptions: o, statusCode: 200, data: {'success': true}));
  }));
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: const QuestFundingScreen(questId: 'quest-1'),
    ),
  ));
  await tester.pumpAndSettle();
  return posts;
}

void main() {
  testWidgets(
      'the author sees Edit / Funding / QR sheet instead of Accept, with no distance check',
      (tester) async {
    final gpsReads = await _pumpDetail(tester, userId: 'author-1');
    expect(find.byKey(const ValueKey('quest_accept_btn')), findsNothing);
    expect(find.byKey(const ValueKey('quest_author_bar')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_edit_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_funding_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_qr_sheet_btn')), findsOneWidget);
    expect(find.text("You're too far from this quest"), findsNothing);
    expect(gpsReads, 0);
  });

  testWidgets('other travelers still get Accept quest', (tester) async {
    await _pumpDetail(tester, userId: 'traveler-1');
    expect(find.byKey(const ValueKey('quest_accept_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_author_bar')), findsNothing);
  });

  testWidgets('an accepted quest shows its idle countdown chip',
      (tester) async {
    final expires = DateTime.now()
        .add(const Duration(hours: 52, minutes: 30))
        .toUtc()
        .toIso8601String();
    await _pumpDetail(tester, userId: 'traveler-1', progress: {
      'has_completed': false,
      'active_attempt': _attempt(expires: expires),
    });
    expect(find.text('Start within 2d 4h'), findsOneWidget);
  });

  testWidgets('after progress the chip counts down to the next step',
      (tester) async {
    final expires = DateTime.now()
        .add(const Duration(hours: 18, minutes: 20))
        .toUtc()
        .toIso8601String();
    await _pumpDetail(tester, userId: 'traveler-1', progress: {
      'has_completed': false,
      'active_attempt': _attempt(expires: expires, step: 'pending_review'),
    });
    expect(find.text('Next step within 18h'), findsOneWidget);
  });

  testWidgets('an expired acceptance explains itself and offers Accept again',
      (tester) async {
    await _pumpDetail(tester, userId: 'traveler-1', progress: {
      'has_completed': false,
      'active_attempt': null,
      'last_expired_at': '2026-11-19T01:00:00.000Z',
    });
    expect(find.textContaining('Your last acceptance expired'), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_accept_btn')), findsOneWidget);
    expect(find.byKey(const ValueKey('quest_idle_chip')), findsNothing);
  });

  testWidgets('the funding page shows an overview of the numbers and history',
      (tester) async {
    await _pumpFunding(tester);
    expect(find.byKey(const ValueKey('funding_overview')), findsOneWidget);
    expect(find.text('212 committed of 212 target'), findsOneWidget);
    expect(find.text('106 pts (~2 rewards)'), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    expect(find.text('53 pts'), findsNWidgets(2)); // reserved + paid out
    expect(find.text('50 pts · 0 accepted · 1 open'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('funding_history')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('Reward paid · 50 pts'), findsOneWidget);
    expect(find.textContaining('Traveler submitted proof'), findsOneWidget);
    expect(find.textContaining('A sponsor committed 50 pts'), findsOneWidget);
  });

  testWidgets('closing a round early warns with the real numbers first',
      (tester) async {
    final posts = await _pumpFunding(tester);
    final close = find.byKey(const ValueKey('funding_close'));
    await tester.scrollUntilVisible(close, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(close);
    await tester.pumpAndSettle();
    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('funding_end_details')), findsOneWidget);
    expect(find.textContaining('No new travelers can accept'), findsOneWidget);
    expect(
        find.textContaining(
            '1 traveler(s) who already accepted keep their reserved reward (53 pts)'),
        findsOneWidget);
    expect(find.textContaining('1 waiting for review'), findsOneWidget);
    expect(
        find.textContaining(
            '106 unreserved pts return now: 56 to you, 50 to sponsors.'),
        findsOneWidget);
    expect(find.textContaining('1 open sponsor request(s) will be withdrawn'),
        findsOneWidget);
    expect(find.textContaining('pauses after the last reservation'),
        findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('funding_end_keep')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('funding_end_keep')));
    await tester.pumpAndSettle();
    expect(posts.where((p) => p.endsWith('/close')), isEmpty);

    await tester.ensureVisible(close);
    await tester.tap(close);
    await tester.pumpAndSettle();
    await tester
        .ensureVisible(find.byKey(const ValueKey('funding_end_confirm')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('funding_end_confirm')));
    await tester.pumpAndSettle();
    expect(
        posts.where((p) => p == '/funding-plans/plan-1/close'), hasLength(1));
  });
}
