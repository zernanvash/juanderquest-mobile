import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/navigation/models/route_model.dart';
import 'package:juanderquest_app/features/navigation/widgets/route_fallback_notice_card.dart';

void main() {
  testWidgets('fallback notice explains estimate and fits a narrow large-text viewport', (tester) async {
    tester.view.physicalSize = const Size(640, 1136);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final route = RouteModel.fromJson({
      'degraded': true,
      'warning': {'code': 'OUTSIDE_ROUTING_COVERAGE', 'message': 'Road routing is unavailable.', 'coverageLabel': 'Pangasinan'},
      'summary': {'distanceKm': 3.2, 'durationFormatted': '6 min'},
      'coordinates': [[16.0, 120.0], [16.1, 120.1]],
      'maneuvers': [],
    });

    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)),
        child: child!,
      ),
      home: Scaffold(body: SingleChildScrollView(child: RouteFallbackNoticeCard(route: route, destination: '16,120'))),
    ));
    expect(find.text('Road routing is unavailable.'), findsOneWidget);
    expect(find.textContaining('3.2 km straight-line distance'), findsOneWidget);
    expect(find.text('Google Maps'), findsOneWidget);
    expect(find.text('Waze'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
