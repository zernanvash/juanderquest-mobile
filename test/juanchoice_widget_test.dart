import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/features/juanchoice/models/juanchoice_models.dart';
import 'package:juanderquest_app/features/juanchoice/providers/juanchoice_provider.dart';
import 'package:juanderquest_app/features/juanchoice/screens/juanchoice_screen.dart';

void main() {
  final campaign = ChoiceCampaign(id: 'campaign-id', theme: 'Coastal gems',
    region: 'Pangasinan', status: 'voting',
    opensAt: DateTime.now().subtract(const Duration(hours: 1)),
    closesAt: DateTime.now().add(const Duration(hours: 1)));

  testWidgets('public list opens with a truthful campaign', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      choiceCampaignsProvider.overrideWith((ref) async => [campaign]),
      choiceSupporterQuestProvider.overrideWith((ref) async => null),
    ], child: const MaterialApp(home: JuanChoiceScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Coastal gems'), findsOneWidget);
    expect(find.textContaining('free and separate'), findsOneWidget);
  });

  testWidgets('reviewed supporter quest is visible without AR-only language', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
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

  testWidgets('guest sees sign-in, not a vote action', (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
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

  testWidgets('closed campaign cannot offer a vote', (tester) async {
    final closed = ChoiceCampaign(id: 'campaign-id', theme: 'Coastal gems',
      region: 'Pangasinan', status: 'voting',
      opensAt: DateTime.now().subtract(const Duration(days: 2)),
      closesAt: DateTime.now().subtract(const Duration(days: 1)));
    await tester.pumpWidget(ProviderScope(overrides: [
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
