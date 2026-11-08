import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_hunt.dart';
import 'package:juanderquest_app/features/ar_experience/core/ar_task.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_game_factory.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_minigame_host.dart';
import 'package:juanderquest_app/features/ar_experience/games/ar_sprites.dart';
import 'package:juanderquest_app/features/ar_experience/games/palayok.dart';
import 'package:juanderquest_app/features/ar_experience/games/pana.dart';
import 'package:juanderquest_app/features/ar_experience/games/sipa.dart';
import 'package:juanderquest_app/features/ar_experience/screens/ar_quest_screen.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';

/// Records every request and answers like the Plan 77 backend.
class _FakeServer extends Interceptor {
  final requests = <RequestOptions>[];

  @override
  void onRequest(RequestOptions o, RequestInterceptorHandler h) {
    requests.add(o);
    final path = o.path;
    Object data = {'success': true, 'data': {}};
    if (path.endsWith('/ar-challenge')) {
      data = {
        'success': true,
        'data': {
          'challenge_token': 'tok',
          'expires_at': '2026-11-08T12:00:00Z',
          'relic': {'lat': 16.2, 'lng': 119.99}
        },
      };
    } else if (path.endsWith('/ar-game')) {
      data = {
        'success': true,
        'data': {'session_id': 'sess-1', 'seed': 42, 'game': 'pana'},
      };
    } else if (path.endsWith('/finish')) {
      data = {
        'success': true,
        'data': {
          'passed': true,
          'score': 64,
          'best': 64,
          'rank_place': 2,
          'rank_week': 5,
          'lower_is_better': false,
          'top': [
            {'rank': 1, 'handle': 'clara', 'display_name': 'Clara', 'score': 90},
            {'rank': 2, 'display_name': 'You', 'score': 64, 'is_self': true},
          ],
        },
      };
    }
    h.resolve(Response(requestOptions: o, data: data, statusCode: 200));
  }
}

void main() {
  QuestModel quest() => QuestModel.fromJson({
        'id': 'q1',
        'title': 'Plaza games',
        'description': '',
        'category': 'cultural',
        'location_name': 'Bolinao',
        'gps_lat': 16.2,
        'gps_lng': 119.99,
        'radius_meters': 100,
        'reward_points': 50,
        'marker_image_url': '',
        'crowd_status': 'low',
        'steps': [],
      });
  QuestStepModel step(Map<String, dynamic> cfg) => QuestStepModel(
        order: 1,
        title: 'Play here',
        description: '',
        checkpointType: 'ar',
        required: true,
        status: 'ready',
        verification: {
          'type': 'ar',
          'fence': {'lat': 16.2, 'lng': 119.99, 'radius_meters': 40},
          ...cfg
        },
      );
  final fix = ArFix(lat: 16.2003, lng: 119.99, accuracy: 5, at: DateTime(2026, 11, 8));

  group('Plan 77 game tasks', () {
    test('the task reads its game; missing or unknown games are collect tasks', () {
      expect(ArTaskSpec.from(quest(), step({'game': 'pana'})).isGame, isTrue);
      expect(ArTaskSpec.from(quest(), step({'game': 'pana'})).game, 'pana');
      expect(ArTaskSpec.from(quest(), step({})).game, 'collect');
      expect(ArTaskSpec.from(quest(), step({'game': 'chess'})).isGame, isFalse);
      expect(ArTaskSpec.from(quest(), step({'object': 'box'})).object, 'box');
    });

    test('a won game sends its session and no relic spot; the no-ARCore hunt says so', () async {
      final server = _FakeServer();
      final dio = Dio()..interceptors.add(server);
      final api = ArQuestApi(dio, ArTaskSpec.from(quest(), step({'game': 'pana'})));

      final s = await api.startGame(fix);
      expect((s.ok, s.data!.id, s.data!.seed), (true, 'sess-1', 42));
      final done = await api.finishGame('sess-1', score: 64, passed: true, stats: const {'arrows': 6});
      expect((done.data!.best, done.data!.rankPlace, done.data!.top.first.name), (64, 2, '@clara'));
      expect(server.requests.last.data, {
        'score': 64,
        'passed': true,
        'stats': {'arrows': 6}
      });

      final ch = await api.requestChallenge(fix);
      await api.submitEvidence(fix, ch.data!.token, gameSessionId: 'sess-1');
      final won = server.requests.last.data as Map;
      expect(won['ar_game_session_id'], 'sess-1');
      expect(won.containsKey('relic_mode'), isFalse);
      expect(won.containsKey('fallback'), isFalse);

      api.noArcoreFallback = true;
      await api.submitEvidence(fix, ch.data!.token);
      final hunted = server.requests.last.data as Map;
      expect((hunted['relic_mode'], hunted['fallback']), ('hidden_spot', 'no_arcore'));
    });

    test('games are seeded by the session', () {
      final a = createArGame('pana', 7) as PanaGame;
      expect(a, isA<PanaGame>());
      expect(createArGame('sipa', 7), isA<SipaGame>());
      expect(createArGame('pabitin_palayok', 7), isA<PalayokGame>());
      expect(createArGame('collect', 7), isNull);
      expect(arGameInfo.keys.toSet(), {'collect', ...ArTaskSpec.games});
    });

    test('the pixel relic sprites are in the bundled manifest', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final sheets = await ArSpriteSheet.loadManifest(rootBundle);
      for (final o in ['token', 'gem', 'box', 'beacon']) {
        for (final s in relicSprites(o, height: 0.35)) {
          expect(sheets.containsKey(s.sheet), isTrue, reason: s.sheet);
        }
      }
    });

    for (final size in const [Size(320, 568), Size(568, 320)]) {
      testWidgets('the end panel result fits at ${size.width.toInt()}x${size.height.toInt()} with 2x text',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.pixel,
          home: MediaQuery(
            data: MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: ArGameEndExtra(
                  result: ArGameResult.fromJson(const {
                    'passed': true,
                    'score': 4200,
                    'best': 4200,
                    'rank_place': 1,
                    'rank_week': 12,
                    'lower_is_better': true,
                    'top': [
                      {'rank': 1, 'display_name': 'A very long explorer display name indeed', 'score': 4200},
                    ],
                  }),
                ),
              ),
            ),
          ),
        ));
        expect(tester.takeException(), isNull);
        expect(find.text('YOUR BEST HERE 4.2 s · #1'), findsOneWidget);
      });
    }
  });
}
