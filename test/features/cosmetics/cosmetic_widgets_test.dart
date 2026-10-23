import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/cosmetic_avatar.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/display_name.dart';
import 'package:juanderquest_app/features/cosmetics/widgets/profile_banner.dart';

void main() {
  testWidgets('profile banner renders its fallback gradient', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ProfileBanner(asset: null, height: 100, child: Text('Passport')),
    ));
    expect(find.text('Passport'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
  });

  testWidgets('avatar renders with and without an equipped frame', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Column(children: [
      CosmeticAvatar(name: 'Traveler'),
      CosmeticAvatar(name: 'Traveler', frame: {'colors': ['#95d5b2', '#2d6a4f'], 'width': 3}),
    ])));
    expect(find.text('T'), findsNWidgets(2));
    expect(find.byType(CosmeticAvatar), findsNWidgets(2));
  });

  testWidgets('display name includes title and optional color', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: DisplayName(name: 'Traveler', title: 'Island Hopper', color: Color(0xff2d6a4f)),
    ));
    expect(find.text('Traveler'), findsOneWidget);
    expect(find.text('Island Hopper'), findsOneWidget);
  });
}
