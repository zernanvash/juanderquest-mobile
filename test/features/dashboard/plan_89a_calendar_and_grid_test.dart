import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/dashboard/data/verified_pangasinan_festivals.dart';
import 'package:juanderquest_app/features/dashboard/models/home_calendar_entry.dart';
import 'package:juanderquest_app/features/dashboard/pixel/home_pixel_art.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_calendar_provider.dart';
import 'package:juanderquest_app/features/dashboard/providers/home_daily_provider.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_adventure_calendar.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_command_grid.dart';
import 'package:juanderquest_app/features/dashboard/widgets/home_dual_bento_row.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/quests/models/campaign_model.dart';
import 'package:juanderquest_app/features/quests/models/quest_model.dart';
import 'package:juanderquest_app/features/quests/providers/campaign_provider.dart';

Widget _wrapPixel({
  required Widget child,
  List<Override> overrides = const [],
  Size size = const Size(360, 640),
  double textScale = 1.0,
  bool disableAnimations = false,
}) {
  return ProviderScope(
    overrides: overrides,
    child: MediaQuery(
      data: MediaQueryData(
        size: size,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: child,
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('WP-1: designer navProfile & plazaTrophy and HomePixelArt are valid', () {
    expect(DesignerArt.navProfile.width, greaterThan(0));
    expect(DesignerArt.navProfile.height, greaterThan(0));
    expect(DesignerArt.plazaTrophy.width, 16);
    expect(DesignerArt.plazaTrophy.height, 16);
    expect(HomePixelArt.calendar.width, 16);
    expect(HomePixelArt.calendar.height, 16);
    expect(HomePixelArt.stampCheck.width, 8);
    expect(HomePixelArt.stampCheck.height, 8);
  });

  test('WP-2: verified Pangasinan festivals are month-only and Mango-Bamboo is April', () {
    final festivals = verifiedPangasinanFestivalsForYear(2026);
    final mango = festivals.firstWhere((e) => e.id.contains('mango-bamboo'));
    expect(mango.startDate.month, 4);
    expect(mango.monthOnly, isTrue);
    expect(mango.spansMonth(2026, 4), isTrue);
    expect(mango.spansDay(DateTime(2026, 4, 1)), isFalse);

    final galicayo = festivals.firstWhere((e) => e.id.contains('galicayo'));
    expect(galicayo.startDate.month, 12);
    expect(galicayo.monthOnly, isTrue);
  });

  test('WP-2: calendar provider merges voting, real campaigns, and streak.current', () {
    final c2 = ProviderContainer(
      overrides: [
        choiceOverviewProvider.overrideWith((ref) async {
          return ChoiceOverview(
            current: ChoiceCampaign(
              id: 'jc-1',
              theme: 'Best Sunset Spot',
              region: 'Pangasinan',
              status: 'voting',
              opensAt: DateTime.utc(2026, 11, 14, 0),
              closesAt: DateTime.utc(2026, 11, 15, 22),
            ),
            nextOpensAt: DateTime.utc(2026, 11, 21, 0),
            nextClosesAt: DateTime.utc(2026, 11, 22, 22),
            nextTheme: 'Heritage',
            previous: null,
            notice: null,
            votingEnabled: true,
            serverTime: DateTime.utc(2026, 11, 14, 10),
            receivedAt: DateTime.now(),
          );
        }),
        homeDailyProvider.overrideWith((ref) async {
          return const HomeDailyState(
            stamps: 20,
            missions: [],
            date: '2026-11-14',
            claimToday: false,
            streak: 3,
          );
        }),
        campaignProvider.overrideWithProvider(
          StateNotifierProvider<CampaignNotifier, CampaignState>((ref) {
            const state = CampaignState(
              hasLoaded: true,
              campaigns: [
                // Demo fallback ID -> must be skipped
                CampaignModel(
                  id: 'bangus-festival-2026',
                  hostId: 'h',
                  hostName: 'LGU',
                  title: 'Demo Bangus',
                  category: 'cultural',
                  locationName: 'Dagupan',
                  municipality: 'Dagupan',
                  bannerImageUrl: '',
                  description: '',
                  eventDate: '2026-09-15T00:00:00Z',
                  startDate: '2026-09-01T00:00:00Z',
                  endDate: '2026-09-15T00:00:00Z',
                  totalBudgetMjdq: 0,
                  rewardPerParticipantMjdq: 500,
                  referralBountyMjdq: 0,
                  maxParticipants: 10,
                  reservedParticipants: 0,
                  completedParticipants: 0,
                  preQuestRequirements: [],
                  status: 'active',
                  createdAt: '2026-01-01T00:00:00Z',
                ),
                // Missing real start_date (fell back to createdAt) -> skipped
                CampaignModel(
                  id: 'undated-1',
                  hostId: 'h',
                  hostName: 'LGU',
                  title: 'Undated',
                  category: 'eco',
                  locationName: 'Sual',
                  municipality: 'Sual',
                  bannerImageUrl: '',
                  description: '',
                  eventDate: '2026-10-01T00:00:00Z',
                  startDate: '2026-10-01T00:00:00Z',
                  endDate: '2026-10-01T00:00:00Z',
                  totalBudgetMjdq: 0,
                  rewardPerParticipantMjdq: 100,
                  referralBountyMjdq: 0,
                  maxParticipants: 10,
                  reservedParticipants: 0,
                  completedParticipants: 0,
                  preQuestRequirements: [],
                  status: 'active',
                  createdAt: '2026-10-01T00:00:00Z',
                ),
                // Real dated live campaign -> included
                CampaignModel(
                  id: 'live-coastal-1',
                  hostId: 'h',
                  hostName: 'LGU',
                  title: 'Lingayen Coastal Cleanup',
                  category: 'eco',
                  locationName: 'Lingayen',
                  municipality: 'Lingayen',
                  bannerImageUrl: '',
                  description: '',
                  eventDate: '2026-11-18T00:00:00Z',
                  startDate: '2026-11-18T00:00:00Z',
                  endDate: '2026-11-19T00:00:00Z',
                  totalBudgetMjdq: 0,
                  rewardPerParticipantMjdq: 150,
                  referralBountyMjdq: 0,
                  maxParticipants: 50,
                  reservedParticipants: 5,
                  completedParticipants: 0,
                  preQuestRequirements: [],
                  status: 'active',
                  createdAt: '2026-11-01T00:00:00Z',
                ),
              ],
            );
            return _SeededCampaignNotifier(state);
          }),
        ),
      ],
    );
    addTearDown(c2.dispose);

    // Trigger futures
    return Future(() async {
      await c2.read(choiceOverviewProvider.future);
      await c2.read(homeDailyProvider.future);
      final entries = c2.read(homeCalendarEntriesProvider(2026));

      expect(entries.any((e) => e.id == 'campaign-live-coastal-1'), isTrue);
      expect(entries.any((e) => e.id == 'campaign-bangus-festival-2026'), isFalse);
      expect(entries.any((e) => e.id == 'campaign-undated-1'), isFalse);
      expect(entries.any((e) => e.kind == CalendarEntryKind.voting), isTrue);

      // Streak = 3, claimToday = false -> marks Nov 13, 12, 11 (NOT Nov 14)
      final streakDays = entries
          .where((e) => e.kind == CalendarEntryKind.stampStreak)
          .toList();
      expect(streakDays.length, 3);
      expect(
        streakDays.any((e) => e.spansDay(DateTime(2026, 11, 14))),
        isFalse,
      );
      expect(
        streakDays.any((e) => e.spansDay(DateTime(2026, 11, 13))),
        isTrue,
      );
      expect(
        streakDays.any((e) => e.spansDay(DateTime(2026, 11, 11))),
        isTrue,
      );
    });
  });

  testWidgets('WP-3: HomeCommandGrid renders 8 tiles (no LARO AR) & routes',
      (tester) async {
    String? navigatedTo;
    await tester.pumpWidget(
      _wrapPixel(
        child: HomeCommandGrid(
          activeQuestsCount: 2,
          savedCount: 5,
          nearbyQuizCount: 3,
          voteLive: true,
          onNavigate: (r) => navigatedTo = r,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home_menu_quests')), findsOneWidget);
    expect(find.text('2 active · 5 saved'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_tile_route')), findsOneWidget);
    expect(find.text('GO'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_tile_plaza')), findsOneWidget);
    expect(find.text('LARO AR'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('home_tile_route')));
    expect(navigatedTo, '/navigate');

    await tester.tap(find.text('TOWN'));
    await tester.pump();
    expect(find.byKey(const ValueKey('home_tile_plaza')), findsOneWidget);
    expect(find.byKey(const ValueKey('home_tile_route')), findsNothing);
  });

  testWidgets('WP-4: HomeDualBentoRow renders recommended quest & daily claim key',
      (tester) async {
    var claimed = false;
    String? navigatedTo;
    final rec = QuestModel(
      id: 'q-lingayen',
      title: 'Capitol Beach Walk',
      description: 'Explore',
      category: 'cultural',
      locationName: 'Lingayen',
      gpsLat: 16.02,
      gpsLng: 120.23,
      radiusMeters: 100,
      rewardPoints: 50,
      markerImageUrl: '',
    );

    await tester.pumpWidget(
      _wrapPixel(
        child: HomeDualBentoRow(
          recommendedQuest: rec,
          recommendedReason: 'In your town',
          dailyState: const HomeDailyState(
            stamps: 15,
            missions: [],
            claimedDays: 4,
            streak: 4,
            claimToday: false,
            nominalStamps: 5,
          ),
          onClaimDaily: () => claimed = true,
          gemName: 'Sual Cove',
          onNavigate: (r) => navigatedTo = r,
        ),
      ),
    );

    expect(find.text('In your town'), findsOneWidget);
    expect(find.text('Capitol Beach Walk'), findsOneWidget);
    expect(find.byKey(const ValueKey('home_daily_claim_button')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home_daily_claim_button')));
    expect(claimed, isTrue);

    await tester.tap(find.byKey(const ValueKey('home_mission_view_button')));
    expect(navigatedTo, '/quests/q-lingayen');
  });

  testWidgets('WP-5: HomeAdventureCalendar toggles WK/MO & jumps to next event',
      (tester) async {
    await tester.pumpWidget(
      _wrapPixel(
        overrides: [
          choiceOverviewProvider.overrideWith((ref) async {
            return ChoiceOverview(
              current: ChoiceCampaign(
                id: 'jc-1',
                theme: 'Wk 46 Vote',
                region: 'Pangasinan',
                status: 'voting',
                opensAt: DateTime.utc(2026, 11, 20, 0),
                closesAt: DateTime.utc(2026, 11, 20, 22),
              ),
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: true,
              serverTime: DateTime.utc(2026, 11, 14, 10),
              receivedAt: DateTime.now(),
            );
          }),
          homeDailyProvider.overrideWith((ref) async {
            return const HomeDailyState(stamps: 0, missions: []);
          }),
        ],
        child: HomeAdventureCalendar(
          initialDate: DateTime(2026, 11, 14),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Month-only festival chip appears for November (Bugallon Town Fiesta)
    expect(
      find.byKey(const ValueKey('home_calendar_month_fiesta_chip')),
      findsOneWidget,
    );

    // Filter to VOTE -> Nov 14 has no vote, so NEXT EVENT > appears
    await tester.tap(find.text('VOTE'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('home_calendar_next_event')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('home_calendar_next_event')));
    await tester.pump();
    expect(find.text('JuanChoice: Wk 46 Vote'), findsOneWidget);

    // Toggle to Full Month
    await tester.tap(find.byKey(const ValueKey('home_calendar_mode_toggle')));
    await tester.pump();
    expect(find.text('WK'), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
      'Overflow gate (${size.width.toInt()}x${size.height.toInt()} @ 2x text)',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrapPixel(
            size: size,
            textScale: 2.0,
            disableAnimations: true,
            overrides: [
              choiceOverviewProvider.overrideWith((ref) async {
                return const ChoiceOverview(
                  current: null,
                  nextOpensAt: null,
                  nextClosesAt: null,
                  nextTheme: null,
                  previous: null,
                  notice: null,
                  votingEnabled: false,
                );
              }),
              homeDailyProvider.overrideWith((ref) async {
                return const HomeDailyState(
                  stamps: 10,
                  missions: [],
                  claimedDays: 3,
                  streak: 3,
                );
              }),
            ],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const HomeCommandGrid(
                  activeQuestsCount: 2,
                  savedCount: 4,
                  nearbyQuizCount: 1,
                ),
                const SizedBox(height: 8),
                const HomeDualBentoRow(
                  dailyState: HomeDailyState(
                    stamps: 10,
                    missions: [],
                    claimedDays: 3,
                    streak: 3,
                  ),
                ),
                const SizedBox(height: 8),
                HomeAdventureCalendar(initialDate: DateTime(2026, 4, 10)),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Expand calendar to Month mode and verify zero overflow at 2x text.
        final toggle = find.byKey(const ValueKey('home_calendar_mode_toggle'));
        await tester.ensureVisible(toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('Review: streak row has no GO & single Pista\'y Dayat in May', (
    tester,
  ) async {
    final mayFests = verifiedPangasinanFestivalsForYear(2026)
        .where((e) => e.title.contains("Pista'y Dayat"))
        .toList();
    expect(mayFests.length, 1);
    expect(mayFests.first.startDate.month, 5);

    await tester.pumpWidget(
      _wrapPixel(
        overrides: [
          homeDailyProvider.overrideWith((ref) async {
            return const HomeDailyState(
              stamps: 10,
              missions: [],
              claimedDays: 1,
              date: '2026-11-14',
              claimToday: true,
              streak: 1,
            );
          }),
          homeFestivalEntriesProvider.overrideWith((ref, year) => const []),
          choiceOverviewProvider.overrideWith((ref) async {
            return const ChoiceOverview(
              current: null,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: false,
            );
          }),
        ],
        child: HomeAdventureCalendar(initialDate: DateTime(2026, 11, 14)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Stamp Streak Day'), findsOneWidget);
    expect(find.text('GO >'), findsNothing);
  });

  testWidgets('Review: NEXT EVENT from Dec 20 jumps to a January entry', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrapPixel(
        overrides: [
          homeDailyProvider.overrideWith((ref) async {
            return const HomeDailyState(
              stamps: 0,
              missions: [],
              claimedDays: 0,
              streak: 0,
            );
          }),
          homeFestivalEntriesProvider.overrideWith((ref, year) => const []),
          homeCalendarEntriesProvider.overrideWith((ref, year) {
            if (year == 2027) {
              return [
                HomeCalendarEntry(
                  id: 'jan-2027-vote',
                  title: 'New Year JuanChoice',
                  shortBadge: 'VOTE',
                  kind: CalendarEntryKind.voting,
                  startDate: DateTime(2027, 1, 5),
                  endDate: DateTime(2027, 1, 7),
                  route: '/choice',
                ),
              ];
            }
            return const [];
          }),
        ],
        child: HomeAdventureCalendar(initialDate: DateTime(2026, 12, 20)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('home_calendar_next_event')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('home_calendar_next_event')));
    await tester.pump();

    expect(find.text('New Year JuanChoice'), findsOneWidget);
    expect(find.text('ALMANAC · JAN 2027'), findsOneWidget);
  });

  testWidgets(
    'Review: agenda title/buttons have fontSize >= 11 and hit size >= 44x32',
    (tester) async {
      await tester.pumpWidget(
        _wrapPixel(
          overrides: [
            homeDailyProvider.overrideWith((ref) async {
              return const HomeDailyState(
                stamps: 0,
                missions: [],
                claimedDays: 0,
                streak: 0,
              );
            }),
            homeFestivalEntriesProvider.overrideWith((ref, year) => const []),
            homeCalendarEntriesProvider.overrideWith((ref, year) {
              return [
                HomeCalendarEntry(
                  id: 'camp-nov-14',
                  title: 'Lingayen Bay Quest',
                  shortBadge: 'EVENT',
                  kind: CalendarEntryKind.campaign,
                  startDate: DateTime(2026, 11, 14),
                  endDate: DateTime(2026, 11, 14),
                  route: '/quests/campaigns/1',
                ),
              ];
            }),
          ],
          child: Column(
            children: [
              const HomeCommandGrid(
                activeQuestsCount: 1,
                savedCount: 1,
                nearbyQuizCount: 0,
              ),
              HomeAdventureCalendar(initialDate: DateTime(2026, 11, 14)),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final agendaTitle = tester.widget<Text>(find.text('Lingayen Bay Quest'));
      expect((agendaTitle.style?.fontSize ?? 0) >= 11, isTrue);

      for (final key in const [
        ValueKey('home_calendar_prev'),
        ValueKey('home_calendar_next'),
        ValueKey('home_calendar_mode_toggle'),
      ]) {
        final boxSize = tester.getSize(find.byKey(key));
        expect(boxSize.width >= 44, isTrue, reason: '$key width < 44');
        expect(boxSize.height >= 32, isTrue, reason: '$key height < 32');
      }

      final goBtn = tester.getSize(find.text('GO >').first);
      expect(goBtn.height > 0, isTrue);
      // Verify GO > button text font size >= 11 and ancestor GestureDetector >= 44x32
      final goText = tester.widget<Text>(find.text('GO >'));
      expect((goText.style?.fontSize ?? 0) >= 11, isTrue);
      final goGesture = find.ancestor(
        of: find.text('GO >'),
        matching: find.byType(GestureDetector),
      );
      final goGestureSize = tester.getSize(goGesture.first);
      expect(goGestureSize.width >= 44, isTrue);
      expect(goGestureSize.height >= 32, isTrue);

      // Verify calendar filter chip ('VOTE') and grid category chip ('PLAY') hit size >= 44x32
      for (final chipLabel in const ['VOTE', 'PLAY']) {
        final chipGesture = find.ancestor(
          of: find.text(chipLabel),
          matching: find.byType(GestureDetector),
        );
        final chipSize = tester.getSize(chipGesture.first);
        expect(chipSize.width >= 44, isTrue, reason: '$chipLabel width < 44');
        expect(chipSize.height >= 32, isTrue, reason: '$chipLabel height < 32');
      }
    },
  );
}

class _SeededCampaignNotifier extends StateNotifier<CampaignState>
    implements CampaignNotifier {
  _SeededCampaignNotifier(super.state);

  @override
  Future<void> fetchCampaigns({bool forceRefresh = false}) async {}
}
