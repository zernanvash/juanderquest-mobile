import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/dashboard/models/home_calendar_entry.dart';
import 'package:juanderquest_app/features/dashboard/providers/festival_calendar_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_calendar_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';

/// Plan 94: festivals staff entered with exact dates show on the Almanac.
ApiClient _api({Object? data, bool fail = false, List<String>? paths}) {
  final api = ApiClient(enableRetries: false);
  api.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        paths?.add('${options.path}?year=${options.queryParameters['year']}');
        if (fail) {
          handler.reject(
            DioException(requestOptions: options, type: DioExceptionType.connectionError),
          );
          return;
        }
        handler.resolve(
          Response(requestOptions: options, statusCode: 200, data: {'success': true, 'data': data}),
        );
      },
    ),
  );
  return api;
}

HomeCalendarEntry _builtIn(String id, String town, int month) => HomeCalendarEntry(
      id: id,
      title: id,
      municipality: town,
      shortBadge: 'FIESTA',
      kind: CalendarEntryKind.festival,
      startDate: DateTime(2027, month, 1),
      endDate: DateTime(2027, month, 1),
      route: '/explore',
      monthOnly: true,
    );

ProviderContainer _container(ApiClient api) {
  final container = ProviderContainer(
    overrides: [
      apiClientProvider.overrideWithValue(api),
      homeDailyProvider.overrideWith(
        (ref) async => const HomeDailyState(stamps: 0, missions: [], claimedDays: 0, streak: 0),
      ),
      choiceOverviewProvider.overrideWith(
        (ref) async => const ChoiceOverview(
          current: null,
          nextOpensAt: null,
          nextClosesAt: null,
          nextTheme: null,
          previous: null,
          notice: null,
          votingEnabled: false,
        ),
      ),
      homeFestivalEntriesProvider.overrideWith(
        (ref, year) => [
          _builtIn('built-in-bangus', 'Dagupan', 4),
          _builtIn('built-in-bagoong', 'Lingayen', 3),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('reads dated festivals for the year and parses exact days', () async {
    final paths = <String>[];
    final container = _container(
      _api(
        paths: paths,
        data: [
          {'id': 'f1', 'name': 'Bangus Festival', 'municipality': 'Dagupan', 'starts_on': '2027-04-20', 'ends_on': '2027-04-30'},
          {'id': 'f2', 'name': 'Broken', 'municipality': null, 'starts_on': 'not-a-date', 'ends_on': '2027-01-01'},
        ],
      ),
    );

    final festivals = await container.read(festivalCalendarProvider(2027).future);

    expect(paths, ['/calendar/festivals?year=2027']);
    expect(festivals, hasLength(1));
    final bangus = festivals.single;
    expect(bangus.id, 'festival-admin-f1');
    expect(bangus.monthOnly, isFalse);
    expect(bangus.kind, CalendarEntryKind.festival);
    expect(bangus.spansDay(DateTime(2027, 4, 20)), isTrue);
    expect(bangus.spansDay(DateTime(2027, 4, 30)), isTrue);
    expect(bangus.spansDay(DateTime(2027, 5, 1)), isFalse);
  });

  test('a dated festival replaces the built-in month entry for the same town and month only', () async {
    final container = _container(
      _api(
        data: [
          {'id': 'f1', 'name': 'Bangus Festival', 'municipality': 'dagupan', 'starts_on': '2027-04-20', 'ends_on': '2027-04-30'},
        ],
      ),
    );
    await container.read(festivalCalendarProvider(2027).future);
    await container.read(homeDailyProvider.future);
    await container.read(choiceOverviewProvider.future);

    final ids = container.read(homeCalendarEntriesProvider(2027)).map((e) => e.id).toList();

    expect(ids, contains('festival-admin-f1'));
    expect(ids, isNot(contains('built-in-bangus')));
    expect(ids, contains('built-in-bagoong'));
  });

  test('offline or an older server keeps the built-in month list', () async {
    final container = _container(_api(fail: true));
    expect(await container.read(festivalCalendarProvider(2027).future), isEmpty);
    await container.read(homeDailyProvider.future);
    await container.read(choiceOverviewProvider.future);

    final ids = container.read(homeCalendarEntriesProvider(2027)).map((e) => e.id).toList();

    expect(ids, containsAll(['built-in-bangus', 'built-in-bagoong']));
  });
}
