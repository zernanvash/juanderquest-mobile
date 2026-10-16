import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/widgets/trail_preview_card.dart';

void main() {
  testWidgets('labels the Trail preview honestly and never promises live routing', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TrailPreviewCard())));

    expect(find.text('IN DEVELOPMENT'), findsOneWidget);
    expect(find.textContaining('not available yet'), findsOneWidget);
    expect(find.textContaining('nothing is routed or promised today'), findsOneWidget);
    expect(find.textContaining('not sent anywhere yet'), findsOneWidget);
  });

  testWidgets('toggles preference chips locally', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: TrailPreviewCard())));

    expect(find.text('Scenic route'), findsOneWidget);
    await tester.tap(find.text('Scenic route'));
    await tester.pumpAndSettle();

    final semantics = tester.getSemantics(find.text('Scenic route'));
    expect(semantics.hasFlag(SemanticsFlag.isSelected), isTrue);
  });
}
