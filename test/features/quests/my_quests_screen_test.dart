import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/quests/screens/my_quests_screen.dart';

const _draft = MyQuest(
  id: 'q-draft',
  title: 'Bolinao cliff walk with a very long title that has to wrap nicely',
  status: 'draft',
  stepCount: 2,
  spotName: 'Patar Beach',
);
const _published = MyQuest(
  id: 'q-pub',
  title: 'Dagupan bangus trail',
  status: 'published',
  stepCount: 1,
);

Widget _app(List<String> asked) => ProviderScope(
      overrides: [
        myQuestsProvider.overrideWith((ref, status) async {
          asked.add(status);
          return status == 'draft'
              ? [_draft]
              : status == 'published'
                  ? [_published]
                  : <MyQuest>[];
        }),
      ],
      child: const MaterialApp(home: MyQuestsScreen()),
    );

void main() {
  test('MyQuest.fromJson reads the API row', () {
    final q = MyQuest.fromJson({
      'id': 'x',
      'title': 'T',
      'status': 'draft',
      'step_count': 3,
      'spot': {'id': 's', 'slug': 's', 'name': 'Bolinao'},
    });
    expect(q.stepCount, 3);
    expect(q.spotName, 'Bolinao');
  });

  testWidgets('Plan 56: opens on drafts and switches status', (tester) async {
    final asked = <String>[];
    await tester.pumpWidget(_app(asked));
    await tester.pumpAndSettle();
    expect(asked.first, 'draft');
    expect(find.byKey(const ValueKey('my_quest_q-draft')), findsOneWidget);
    expect(find.textContaining('finish to publish'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my_quests_published')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my_quest_q-pub')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('my_quests_paused')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('my_quests_empty')), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('Plan 56: no overflow at $size with 2.0x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MediaQuery(
        data:
            MediaQueryData(size: size, textScaler: const TextScaler.linear(2)),
        child: _app([]),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
