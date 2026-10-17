import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/map/widgets/map_cluster_list_sheet.dart';

void main() {
  testWidgets('cluster list stays scrollable without overflow at small size and large text', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(320, 568), textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: MapClusterListSheet(
              items: List.generate(
                30,
                (i) => MapClusterListItem(
                  id: '$i',
                  title: 'A very long destination title number $i',
                  subtitle: 'Municipality and province description number $i',
                  icon: Icons.place,
                ),
              ),
              onSelect: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Destinations at this location'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
