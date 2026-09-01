import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/about/screens/about_screen.dart';

void main() {
  testWidgets('About screen lists team names without role labels', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AboutScreen()));

    expect(find.text('Ana Victoria V. Alentajan', skipOffstage: false), findsOneWidget);
    expect(find.text('Zernan Vash L. Arive', skipOffstage: false), findsOneWidget);
    expect(find.text('Clarissa Angel A. Gutlay', skipOffstage: false), findsOneWidget);
    expect(find.text('Carl Jacob Lavaro', skipOffstage: false), findsOneWidget);
    expect(find.text('Alyana Soriano', skipOffstage: false), findsOneWidget);


    expect(find.text('Research & UI/UX Lead'), findsNothing);
    expect(find.text('Lead System Architect & Web3'), findsNothing);
    expect(find.text('Mobile Frontend & QA'), findsNothing);
    expect(find.text('Backend & Data Architecture'), findsNothing);
    expect(find.text('Tourism & Community Engagement'), findsNothing);
  });
}
