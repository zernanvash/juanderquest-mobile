import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/cache/snapshot_store.dart';

void main() {
  late Directory tempDir;
  late SnapshotStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('jdq-snapshots-');
    store = SnapshotStore(directoryProvider: () async => tempDir);
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SnapshotStore', () {
    test('saves and loads a snapshot with savedAt and schema version', () async {
      await store.save('quests', {'items': [1, 2, 3]});
      final entry = await store.load('quests');
      expect(entry, isNotNull);
      expect((entry!.data as Map)['items'], [1, 2, 3]);
      expect(entry.schemaVersion, 1);
      expect(DateTime.now().difference(entry.savedAt).inSeconds, lessThan(5));
    });

    test('returns null for a missing key or a stale/old snapshot', () async {
      expect(await store.load('missing'), isNull);

      await store.save('leaderboard', {'rows': []});
      final fresh = await store.load('leaderboard', maxAge: const Duration(hours: 1));
      expect(fresh, isNotNull);
      final tooOld = await store.load('leaderboard', maxAge: Duration.zero);
      expect(tooOld, isNull);
    });

    test('ignores snapshots written with a different schema version', () async {
      final other = SnapshotStore(directoryProvider: () async => tempDir, schemaVersion: 2);
      await other.save('profile', {'name': 'x'});
      expect(await store.load('profile'), isNull);
      expect(await other.load('profile'), isNotNull);
    });

    test('keys with special characters map to safe file names', () async {
      await store.save('user:42/summary', {'points': 10});
      final files = tempDir.listSync().map((entity) => entity.uri.pathSegments.last).toList();
      expect(files, hasLength(1));
      expect(files.single, 'snapshot_user_42_summary.json');
      final entry = await store.load('user:42/summary');
      expect((entry!.data as Map)['points'], 10);
    });

    test('clear removes the snapshot; corrupt files load as null', () async {
      await store.save('vouchers', {'v': 1});
      await store.clear('vouchers');
      expect(await store.load('vouchers'), isNull);

      final corrupt = File('${tempDir.path}/snapshot_corrupt.json');
      await corrupt.writeAsString('{not json');
      expect(await store.load('corrupt'), isNull);
    });
  });

  group('relativeSnapshotAge', () {
    test('formats human copy', () {
      final now = DateTime(2026, 10, 17, 12, 0, 0);
      expect(relativeSnapshotAge(now.subtract(const Duration(seconds: 20)), now: now), 'Saved just now');
      expect(relativeSnapshotAge(now.subtract(const Duration(minutes: 12)), now: now), 'Saved 12 min ago');
      expect(relativeSnapshotAge(now.subtract(const Duration(hours: 3)), now: now), 'Saved 3 h ago');
      expect(relativeSnapshotAge(now.subtract(const Duration(days: 2)), now: now), 'Saved 2 d ago');
    });
  });
}
