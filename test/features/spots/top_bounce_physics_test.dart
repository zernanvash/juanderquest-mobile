import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/spots/screens/spot_detail_screen.dart';

// Owner 2026-11-20: destination details glitched when scrolled past the bottom.
void main() {
  Widget list(ScrollController c) => MaterialApp(
        home: CustomScrollView(
          controller: c,
          physics: const TopBounceScrollPhysics(),
          slivers: [
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => SizedBox(height: 100, child: Text('row $i')),
                childCount: 30,
              ),
            ),
          ],
        ),
      );

  testWidgets('stops at the bottom: no overscroll past the end', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(list(c));
    c.jumpTo(c.position.maxScrollExtent);
    await tester.pump();
    final gesture = await tester.startGesture(const Offset(200, 400));
    await gesture.moveBy(const Offset(0, -300));
    await tester.pump();
    expect(c.offset, c.position.maxScrollExtent);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.offset, c.position.maxScrollExtent);
  });

  testWidgets('still bounces when pulled past the top', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(list(c));
    final gesture = await tester.startGesture(const Offset(200, 300));
    await gesture.moveBy(const Offset(0, 200));
    await tester.pump();
    expect(c.offset, lessThan(0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(c.offset, 0);
  });

  testWidgets('a fling to the bottom ends exactly at the end', (tester) async {
    final c = ScrollController();
    await tester.pumpWidget(list(c));
    await tester.fling(find.byType(CustomScrollView), const Offset(0, -3000), 8000);
    await tester.pumpAndSettle();
    expect(c.offset, c.position.maxScrollExtent);
  });
}
