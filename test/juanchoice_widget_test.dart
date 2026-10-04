import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/screens/juanchoice_screen.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/core/network/api_client.dart';

class _SignedInAuthNotifier extends AuthNotifier {
  _SignedInAuthNotifier() : super(ApiClient(), AuthRefreshNotifier()) {
    state = AuthState(user: UserModel(
      id: 'choice-test-user', seedId: 'wallet:choice-test-user', displayName: 'Choice Tester',
      email: 'choice@example.test', avatarUrl: '', role: 'user', demoPoints: 0,
    ), token: 'test-session');
  }
}

void main() {
  final campaign = ChoiceCampaign(id: 'campaign-id', theme: 'Coastal gems',
    region: 'Pangasinan', status: 'voting',
    opensAt: DateTime.now().subtract(const Duration(hours: 1)),
    closesAt: DateTime.now().add(const Duration(hours: 1)));
  ChoiceOverview overview() => ChoiceOverview(
    current: campaign, nextOpensAt: null, nextClosesAt: null,
    nextTheme: null, previous: null, notice: null, votingEnabled: true,
    serverTime: DateTime.now(), receivedAt: DateTime.now(),
  );

  testWidgets('public list opens with a truthful campaign', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceCampaignsProvider.overrideWith((ref) async => [campaign]),
      choiceSupporterQuestProvider.overrideWith((ref) async => null),
    ], child: const MaterialApp(home: JuanChoiceScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Coastal gems'), findsOneWidget);
    expect(find.textContaining('free and separate'), findsOneWidget);
  });

  testWidgets('reviewed supporter quest is visible without AR-only language', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceCampaignsProvider.overrideWith((ref) async => [campaign]),
      choiceSupporterQuestProvider.overrideWith((ref) async => ChoiceSupporterQuest(
        campaignId:'campaign-id',questId:'quest-id',spotName:'Hidden Cove',
        questTitle:'Supporter visit',questDescription:'Complete the verified destination quest.',
        expiresAt:DateTime.now().add(const Duration(days:1)),explorerXp:300,claimed:false)),
    ], child: const MaterialApp(home: JuanChoiceScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Visit the community winner'),findsOneWidget);
    expect(find.text('Open destination quest'),findsOneWidget);
    expect(find.textContaining('AR'),findsNothing);
  });

  testWidgets('supporter visit outage shows retry and recovers on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    var attempts = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceSupporterQuestProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return null;
      }),
    ], child: MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
      child: child!), home: const JuanChoiceScreen())));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Retry visit rewards'), 180);
    await tester.ensureVisible(find.text('Retry visit rewards'));
    await tester.pumpAndSettle();
    expect(find.text('Visit rewards could not be checked.'), findsOneWidget);
    await tester.tap(find.text('Retry visit rewards'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Visit rewards could not be checked.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('engagement outage shows retry and recovers for a signed-in traveler', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceSupporterQuestProvider.overrideWith((ref) async => null),
      choiceEngagementProvider.overrideWith((ref) async {
        attempts++;
        if (attempts == 1) throw StateError('offline');
        return const ChoiceEngagementSummary(
          currentStreak: 1, longestStreak: 1, nextMilestone: 4,
          verifiedVisits: 1, uniqueDestinations: 1, municipalities: 1,
          participations: 1, challenges: [],
        );
      }),
    ], child: const MaterialApp(home: JuanChoiceScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Your community journey could not be loaded.'), findsOneWidget);
    await tester.tap(find.text('Retry journey'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(find.text('Your community journey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest sees sign-in, not a vote action', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceDetailProvider('campaign-id').overrideWith((ref) async => ChoiceDetail(
        campaign: campaign,
        standings: const [ChoiceStanding(candidateId: 'candidate-id', spotName: 'Hidden Cove', votes: 2)],
        ballot: null)),
    ], child: const MaterialApp(home: JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
    await tester.pumpAndSettle();
    expect(find.text('Hidden Cove'), findsOneWidget);
    expect(find.text('Sign in to vote'), findsOneWidget);
    expect(find.text('Vote for this place'), findsNothing);
  });

  test('older ballot-only API responses cannot authorize a vote', () {
    expect(ChoiceEligibility.fromOwnerJson({'ballot': null}), isNull);
  });

  testWidgets('detail retry reloads voting overview after an API outage', (tester) async {
    var overviewAttempts = 0;
    var detailAttempts = 0;
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
      choiceOverviewProvider.overrideWith((ref) async {
        overviewAttempts++;
        if (overviewAttempts == 1) throw StateError('API offline');
        return overview();
      }),
      choiceDetailProvider('campaign-id').overrideWith((ref) async {
        detailAttempts++;
        if (detailAttempts == 1) throw StateError('API offline');
        return ChoiceDetail(campaign: campaign,
          standings: const [ChoiceStanding(candidateId: 'candidate-id',
            spotName: 'Hidden Cove', votes: 0)], ballot: null,
          eligibility: const ChoiceEligibility(eligible: true, reason: null,
            eligibleAt: null, canVoteNow: true));
      }),
    ], child: const MaterialApp(home: JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
    await tester.pumpAndSettle();
    expect(find.text('Campaign unavailable. Please try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(overviewAttempts, 2);
    expect(detailAttempts, 2);
    expect(find.text('Vote for this place'), findsOneWidget);
  });

  testWidgets('new account sees eligibility date, not a vote action at 320px and 2x text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceDetailProvider('campaign-id').overrideWith((ref) async => ChoiceDetail(
        campaign: campaign,
        standings: const [ChoiceStanding(candidateId: 'candidate-id', spotName: 'Hidden Cove', votes: 2)],
        ballot: null,
        eligibility: ChoiceEligibility(eligible: false, reason: 'ACCOUNT_TOO_NEW',
          eligibleAt: DateTime.now().add(const Duration(days: 3)), canVoteNow: false))),
    ], child: MaterialApp(builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
      child: child!), home: const JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voting unlocks after'), findsOneWidget);
    expect(find.text('Vote for this place'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('eligible signed-in traveler can see the explicit vote action', (tester) async {
    final scheduledInOpenWindow = ChoiceCampaign(id: campaign.id, theme: campaign.theme,
      region: campaign.region, status: 'scheduled', opensAt: campaign.opensAt,
      closesAt: campaign.closesAt);
    await tester.pumpWidget(ProviderScope(overrides: [
      authProvider.overrideWith((ref) => _SignedInAuthNotifier()),
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceDetailProvider('campaign-id').overrideWith((ref) async => ChoiceDetail(
        campaign: scheduledInOpenWindow,
        standings: const [ChoiceStanding(candidateId: 'candidate-id', spotName: 'Hidden Cove', votes: 2)],
        ballot: null,
        eligibility: const ChoiceEligibility(eligible: true, reason: null,
          eligibleAt: null, canVoteNow: true))),
    ], child: const MaterialApp(home: JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
    await tester.pumpAndSettle();
    expect(find.text('Vote for this place'), findsOneWidget);
    expect(find.text('Pangasinan · Voting open'), findsOneWidget);
  });

  testWidgets('closed campaign cannot offer a vote', (tester) async {
    final closed = ChoiceCampaign(id: 'campaign-id', theme: 'Coastal gems',
      region: 'Pangasinan', status: 'voting',
      opensAt: DateTime.now().subtract(const Duration(days: 2)),
      closesAt: DateTime.now().subtract(const Duration(days: 1)));
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceOverviewProvider.overrideWith((ref) async => overview()),
      choiceDetailProvider('campaign-id').overrideWith((ref) async => ChoiceDetail(
        campaign: closed, standings: const [], ballot: null)),
    ], child: const MaterialApp(home: JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
    await tester.pumpAndSettle();
    expect(find.textContaining('Voting is closed'), findsOneWidget);
    expect(find.text('Sign in to vote'), findsNothing);
  });

  for (final size in [const Size(320, 568), const Size(568, 320)]) {
    testWidgets('campaign detail has no overflow at $size and 2x text', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      await tester.pumpWidget(ProviderScope(overrides: [
        choiceOverviewProvider.overrideWith((ref) async => overview()),
        choiceDetailProvider('campaign-id').overrideWith((ref) async => ChoiceDetail(
          campaign: campaign,
          standings: const [ChoiceStanding(candidateId: 'candidate-id',
            spotName: 'Very Long Pangasinan Coastal Destination Name', votes: 100)],
          ballot: null)),
      ], child: MaterialApp(builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!),
        home: const JuanChoiceDetailScreen(campaignId: 'campaign-id'))));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
