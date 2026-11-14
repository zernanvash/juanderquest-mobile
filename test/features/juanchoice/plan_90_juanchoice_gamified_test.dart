import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/generated/designer_art.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_art.dart';
import 'package:juanderquest_app/core/pixel/pixel_feedback.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/pixel/juanchoice_theme_spec.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/screens/juanchoice_screen.dart';

class _SignedInAuthNotifier extends AuthNotifier {
  _SignedInAuthNotifier() : super(ApiClient(), AuthRefreshNotifier()) {
    state = AuthState(
      user: UserModel(
        id: 'choice-test-user',
        seedId: 'wallet:choice-test-user',
        displayName: 'Choice Tester',
        email: 'choice@example.test',
        avatarUrl: '',
        role: 'user',
        demoPoints: 0,
      ),
      token: 'test-session',
    );
  }
}

void main() {
  final openCampaign = ChoiceCampaign(
    id: 'camp-coastal',
    theme: 'Coastal gems',
    region: 'Pangasinan',
    status: 'voting',
    opensAt: DateTime.now().subtract(const Duration(hours: 2)),
    closesAt: DateTime.now().add(const Duration(hours: 6)),
  );

  final hiddenCampaign = ChoiceCampaign(
    id: 'camp-hidden',
    theme: 'Nature and coast',
    region: 'Pangasinan',
    status: 'voting',
    opensAt: DateTime.now().subtract(const Duration(hours: 10)),
    closesAt: DateTime.now().add(const Duration(hours: 1)),
    tallyHidden: true,
  );

  ChoiceOverview makeOverview({ChoicePreviousResult? previous}) => ChoiceOverview(
        current: openCampaign,
        nextOpensAt: null,
        nextClosesAt: null,
        nextTheme: null,
        previous: previous,
        notice: null,
        votingEnabled: true,
        serverTime: DateTime.now(),
        receivedAt: DateTime.now(),
      );

  group('JuanChoiceThemeSpec.fromTheme', () {
    test('maps handout examples and live round names accurately', () {
      expect(
        JuanChoiceThemeSpec.fromTheme('Coastal gems').kind,
        JuanChoiceCategoryTheme.coastal,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Mountain & Falls').kind,
        JuanChoiceCategoryTheme.nature,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Heritage Churches').kind,
        JuanChoiceCategoryTheme.heritage,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Best Pangasinan Food').kind,
        JuanChoiceCategoryTheme.culinary,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Weekend Adventure').kind,
        JuanChoiceCategoryTheme.adventure,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Hidden Gems of the Week').kind,
        JuanChoiceCategoryTheme.spotlight,
      );

      // Live round names
      expect(
        JuanChoiceThemeSpec.fromTheme('Local activities').kind,
        JuanChoiceCategoryTheme.adventure,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Nature and coast').kind,
        JuanChoiceCategoryTheme.coastal,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Culture and heritage').kind,
        JuanChoiceCategoryTheme.heritage,
      );
    });

    test('matches whole words only (no substring false positives)', () {
      expect(
        JuanChoiceThemeSpec.fromTheme('Dry season spotlight').kind,
        JuanChoiceCategoryTheme.spotlight,
      );
      expect(
        JuanChoiceThemeSpec.fromTheme('Movie theater').kind,
        JuanChoiceCategoryTheme.spotlight,
      );
    });
  });

  testWidgets(
      'JuanChoiceScreen shows themed card, reward pills, previous winner trophy/bars, and journey bars',
      (tester) async {
    const previous = ChoicePreviousResult(
      periodLabel: 'Oct 1 - Oct 7',
      validBallots: 15,
      coWinnerIds: {'c1'},
      standings: [
        ChoiceStanding(candidateId: 'c1', spotName: 'Hundred Islands', votes: 10),
        ChoiceStanding(candidateId: 'c2', spotName: 'Bolinao Falls', votes: 5),
      ],
    );
    const engagement = ChoiceEngagementSummary(
      currentStreak: 2,
      longestStreak: 3,
      nextMilestone: 4,
      verifiedVisits: 5,
      uniqueDestinations: 4,
      municipalities: 3,
      participations: 2,
      challenges: [
        ChoiceChallenge(
          title: 'Coastal Voter',
          progress: 2,
          target: 3,
          complete: false,
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
          choiceOverviewProvider.overrideWith(
            (ref) async => makeOverview(previous: previous),
          ),
          choiceSupporterQuestProvider.overrideWith((ref) async => null),
          choiceEngagementProvider.overrideWith((ref) async => engagement),
        ],
        child: const MaterialApp(home: JuanChoiceScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('FREE BALLOT'), findsOneWidget);
    expect(find.text('+25 CIVIC XP'), findsOneWidget);
    expect(find.text('+1 STAMP'), findsOneWidget);
    expect(find.text('COASTAL ROUND'), findsOneWidget);
    expect(find.text('LIVE BALLOT'), findsOneWidget);
    expect(find.text('OPEN BALLOT'), findsOneWidget);

    // Co-winner trophy sprite in Previous results
    expect(
      find.byWidgetPredicate(
        (w) => w is PixelSprite && w.art == DesignerArt.plazaTrophy,
      ),
      findsOneWidget,
    );
    // Progress bars: 2 in previous results + 1 streak + 1 challenge = 4
    expect(find.byType(PixelProgressBar), findsNWidgets(4));
  });

  testWidgets(
      'JuanChoiceDetailScreen shows themed header, rank badges, share bars, and YOUR VOTE seal',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
          choiceOverviewProvider.overrideWith(
            (ref) async => ChoiceOverview(
              current: hiddenCampaign,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: true,
              serverTime: DateTime.now(),
              receivedAt: DateTime.now(),
            ),
          ),
          choiceDetailProvider('camp-coastal').overrideWith(
            (ref) async => ChoiceDetail(
              campaign: openCampaign,
              standings: const [
                ChoiceStanding(
                  candidateId: 'cand-1',
                  spotName: 'Patar Beach',
                  votes: 75,
                ),
                ChoiceStanding(
                  candidateId: 'cand-2',
                  spotName: 'Cabongaoan',
                  votes: 25,
                ),
              ],
              ballot: const ChoiceBallot(candidateId: 'cand-1', version: 1),
              eligibility: const ChoiceEligibility(
                eligible: true,
                reason: null,
                eligibleAt: null,
                canVoteNow: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: JuanChoiceDetailScreen(campaignId: 'camp-coastal'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('choice_week_header')), findsOneWidget);
    expect(find.byKey(const ValueKey('choice_ballot_banner')), findsOneWidget);
    expect(find.text('COASTAL ROUND'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);
    expect(find.text('75% share'), findsOneWidget);
    expect(find.text('25% share'), findsOneWidget);
    expect(find.text('YOUR VOTE'), findsOneWidget);
    expect(find.byType(PixelProgressBar), findsNWidgets(2));
  });

  testWidgets(
      'hidden tally hides rank badges, % share, and progress bars while keeping YOUR VOTE and vote button',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
          choiceOverviewProvider.overrideWith(
            (ref) async => ChoiceOverview(
              current: hiddenCampaign,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: true,
              serverTime: DateTime.now(),
              receivedAt: DateTime.now(),
            ),
          ),
          choiceDetailProvider('camp-hidden').overrideWith(
            (ref) async => ChoiceDetail(
              campaign: hiddenCampaign,
              standings: const [
                ChoiceStanding(
                  candidateId: 'cand-1',
                  spotName: 'Hundred Islands',
                  votes: null,
                ),
                ChoiceStanding(
                  candidateId: 'cand-2',
                  spotName: 'Tondol Beach',
                  votes: null,
                ),
              ],
              ballot: const ChoiceBallot(candidateId: 'cand-1', version: 1),
              eligibility: const ChoiceEligibility(
                eligible: true,
                reason: null,
                eligibleAt: null,
                canVoteNow: true,
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: JuanChoiceDetailScreen(campaignId: 'camp-hidden'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('choice_tally_hidden')), findsOneWidget);
    expect(
      find.text('Provisional votes: Hidden', findRichText: true),
      findsNWidgets(2),
    );
    expect(find.text('#1'), findsNothing);
    expect(find.text('#2'), findsNothing);
    expect(find.textContaining('% share'), findsNothing);
    expect(find.byType(PixelProgressBar), findsNothing);

    // YOUR VOTE seal and switch-vote action remain visible
    expect(find.text('YOUR VOTE'), findsOneWidget);
    expect(find.text('Change vote'), findsNWidgets(2));
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
        'JuanChoiceScreen has zero overflows at $size with 2x text scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      const previous = ChoicePreviousResult(
        periodLabel: 'Oct 1 - Oct 7',
        validBallots: 12,
        coWinnerIds: {'c1'},
        standings: [
          ChoiceStanding(candidateId: 'c1', spotName: 'Hundred Islands', votes: 8),
          ChoiceStanding(candidateId: 'c2', spotName: 'Bolinao Falls', votes: 4),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
            choiceOverviewProvider.overrideWith(
              (ref) async => makeOverview(previous: previous),
            ),
            choiceSupporterQuestProvider.overrideWith((ref) async => null),
            choiceEngagementProvider.overrideWith(
              (ref) async => const ChoiceEngagementSummary(
                currentStreak: 1,
                longestStreak: 2,
                nextMilestone: 4,
                verifiedVisits: 3,
                uniqueDestinations: 2,
                municipalities: 2,
                participations: 1,
                challenges: [
                  ChoiceChallenge(
                    title: 'Pangasinan Scout',
                    progress: 1,
                    target: 3,
                    complete: false,
                  ),
                ],
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const JuanChoiceScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'JuanChoiceDetailScreen has zero overflows at $size with 2x text scale',
        (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
            choiceOverviewProvider.overrideWith(
            (ref) async => ChoiceOverview(
              current: hiddenCampaign,
              nextOpensAt: null,
              nextClosesAt: null,
              nextTheme: null,
              previous: null,
              notice: null,
              votingEnabled: true,
              serverTime: DateTime.now(),
              receivedAt: DateTime.now(),
            ),
          ),
            choiceDetailProvider('camp-coastal').overrideWith(
              (ref) async => ChoiceDetail(
                campaign: openCampaign,
                standings: const [
                  ChoiceStanding(
                    candidateId: 'cand-1',
                    spotName: 'Patar Beach',
                    votes: 10,
                  ),
                  ChoiceStanding(
                    candidateId: 'cand-2',
                    spotName: 'Cabongaoan',
                    votes: 5,
                  ),
                ],
                ballot: const ChoiceBallot(candidateId: 'cand-1', version: 1),
                eligibility: const ChoiceEligibility(
                  eligible: true,
                  reason: null,
                  eligibleAt: null,
                  canVoteNow: true,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const JuanChoiceDetailScreen(campaignId: 'camp-coastal'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
