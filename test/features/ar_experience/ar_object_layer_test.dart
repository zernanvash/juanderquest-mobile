import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/features/ar_experience/engine/shapes_factory.dart';
import 'package:juanderquest_app/features/ar_experience/widgets/ar_3d_canvas.dart';
import 'package:juanderquest_app/features/ar_experience/widgets/ar_overlay.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required bool draw, required bool collectable}) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Stack(children: [
        ArObjectLayer(
          object: ValueNotifier(const ArScreenObject(
              visible: true, center: Offset(200, 300), sizePx: 80, relativeDeg: 0)),
          mesh: ShapesFactory.createShape(ShapeType.gem),
          color: Colors.amber,
          collectable: collectable,
          onTap: () => taps++,
          drawObject: draw,
        ),
      ]),
    ));
    await tester.pump(const Duration(milliseconds: 50));
    if (collectable) {
      await tester.tap(find.byKey(const ValueKey('ar_object')));
      expect(taps, 1, reason: 'the tap target works whether or not Flutter draws the object');
    }
  }

  testWidgets('Flutter draws the object only when asked (World AR draws it natively)', (tester) async {
    await pump(tester, draw: true, collectable: false);
    expect(find.byType(Ar3dCanvas), findsOneWidget);
    await pump(tester, draw: false, collectable: true);
    expect(find.byType(Ar3dCanvas), findsNothing);
  });
}
