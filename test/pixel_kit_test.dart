import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanderquest_app/core/pixel/generated/pixel_palette.g.dart';
import 'package:juanderquest_app/core/pixel/pixel_box.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/core/pixel/pixel_feedback.dart';
import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/core/pixel/pixel_input.dart';
import 'package:juanderquest_app/core/pixel/pixel_nav.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/pixel_lab/pixel_lab_screen.dart';

class _MemoryPixelSettingsStore implements PixelSettingsStore {
  PixelSettings? value;

  @override
  Future<PixelSettings?> read() async => value;

  @override
  Future<void> write(PixelSettings settings) async {
    value = settings;
  }
}

Future<void> _pumpPixel(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(360, 720);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        pixelSettingsStoreProvider.overrideWithValue(
          _MemoryPixelSettingsStore(),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.pixel,
        home: Scaffold(
          body: Center(
            child: SingleChildScrollView(child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('PixelGrid', () {
    test('snaps to whole device pixels at common ratios', () {
      for (final dpr in const [2.0, 2.625, 2.75, 3.0]) {
        final grid = PixelGrid(dpr, 2);
        expect(grid.unit * dpr, grid.devicePerArt);
        for (final value in const [0.0, 1.0, 13.37, 47.123]) {
          final snapped = grid.snap(value);
          expect(
            ((snapped * dpr) - (snapped * dpr).roundToDouble()).abs(),
            lessThan(1e-9),
            reason: 'dpr $dpr value $value',
          );
          expect(grid.snap(snapped), snapped);
        }
        expect(grid.px(3), grid.unit * 3);
      }
    });
  });

  group('steppedRects', () {
    test('area and shape shrink by the corner steps', () {
      for (var steps = 0; steps <= 3; steps++) {
        final rects = steppedRects(0, 0, 12, 10, steps);
        final area = rects.fold<double>(
          0,
          (sum, rect) => sum + rect.width * rect.height,
        );
        expect(area, 120 - 2 * steps * (steps + 1));
        for (final rect in rects) {
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.top, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(12));
          expect(rect.bottom, lessThanOrEqualTo(10));
        }
      }
    });

    test('clamps steps to half the shorter side and returns empty for no size',
        () {
      expect(steppedRects(0, 0, 0, 10, 2), isEmpty);
      expect(steppedRects(0, 0, 10, 0, 2), isEmpty);
      final clamped = steppedRects(0, 0, 4, 4, 9);
      final atLimit = steppedRects(0, 0, 4, 4, 2);
      expect(clamped.length, atLimit.length);
    });
  });

  test('pixel kit uses only the generated palette', () {
    final dir = Directory('lib/core/pixel');
    final files = dir
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .where(
          (file) => !file.path.replaceAll('\\', '/').contains('/generated/'),
        )
        .toList();
    expect(files, isNotEmpty);
    for (final file in files) {
      final source = file.readAsStringSync();
      expect(
        source.contains('Color(0x'),
        isFalse,
        reason: '${file.path} contains a raw colour',
      );
    }
  });

  test('PixelSettings decodes only known kit values', () {
    final stored = PixelSettings.fromJson(
      '{"artPx":4,"font":"VT323","fontV":2,"haptics":false}',
    );
    expect(
        stored, const PixelSettings(artPx: 4, font: 'VT323', haptics: false));
    // A font saved before Silkscreen became the default moves to it.
    final legacy = PixelSettings.fromJson('{"font":"Monocraft"}');
    expect(legacy?.font, 'Silkscreen');
    final fallback = PixelSettings.fromJson(
      '{"artPx":99,"font":"Comic Sans","haptics":"yes"}',
    );
    expect(fallback, const PixelSettings());
    expect(PixelSettings.fromJson('not json'), isNull);
  });

  group('PixelButton', () {
    testWidgets('presses sink, fires once and exposes its label', (
      tester,
    ) async {
      var taps = 0;
      await _pumpPixel(
        tester,
        PixelButton(label: 'Start', onPressed: () => taps++),
      );
      final semantics = tester.ensureSemantics();
      expect(find.bySemanticsLabel('Start'), findsOneWidget);
      expect(
          tester.widget<PixelPanel>(find.byType(PixelPanel)).pressed, isFalse);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(PixelButton)),
      );
      await tester.pump();
      expect(
          tester.widget<PixelPanel>(find.byType(PixelPanel)).pressed, isTrue);
      await gesture.up();
      await tester.pump();
      expect(taps, 1);
      expect(
          tester.widget<PixelPanel>(find.byType(PixelPanel)).pressed, isFalse);
      semantics.dispose();
    });

    testWidgets('disabled button does nothing and loading blocks taps', (
      tester,
    ) async {
      var taps = 0;
      await _pumpPixel(tester, const PixelButton(label: 'Disabled'));
      await tester.tap(find.byType(PixelButton));
      await tester.pump();
      expect(taps, 0);

      await _pumpPixel(
        tester,
        PixelButton(
          label: 'Loading',
          loading: true,
          onPressed: () => taps++,
        ),
      );
      await tester.tap(find.byType(PixelButton));
      await tester.pump();
      expect(taps, 0);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('PixelSwitch and PixelCheckbox toggle', (tester) async {
    var switched = true;
    var checked = false;
    await _pumpPixel(
      tester,
      StatefulBuilder(
        builder: (context, setState) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            PixelSwitch(
              value: switched,
              onChanged: (value) => setState(() => switched = value),
            ),
            PixelCheckbox(
              value: checked,
              label: 'TRAVELER',
              onChanged: (value) => setState(() => checked = value),
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.byType(PixelSwitch));
    await tester.pump();
    expect(switched, isFalse);
    await tester.tap(find.byType(PixelCheckbox));
    await tester.pump();
    expect(checked, isTrue);
  });

  testWidgets('PixelTextField shows its error state and validates a form', (
    tester,
  ) async {
    final formKey = GlobalKey<FormState>();
    await _pumpPixel(
      tester,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const PixelTextField(
            label: 'Destination',
            hint: 'Where to?',
            errorText: 'Enter a destination',
          ),
          Form(
            key: formKey,
            child: PixelTextField(
              hint: 'Required field',
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'This field is required'
                  : null,
            ),
          ),
        ],
      ),
    );
    expect(find.text('Enter a destination'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter is PixelBoxPainter &&
            (widget.painter! as PixelBoxPainter).style.outline ==
                PixelPalette.alert,
      ),
      findsWidgets,
    );
    expect(find.text('This field is required'), findsNothing);
    expect(formKey.currentState!.validate(), isFalse);
    await tester.pump();
    expect(find.text('This field is required'), findsOneWidget);
  });

  testWidgets('PixelDialogue reveal tap skips to the end and advances', (
    tester,
  ) async {
    await _pumpPixel(
      tester,
      const PixelDialogue(
        speaker: 'Juan',
        lines: ['Hello traveler', 'Second line'],
      ),
    );
    expect(find.text('Hello traveler'), findsNothing);
    await tester.tap(find.byType(PixelDialogue));
    await tester.pump();
    expect(find.text('Hello traveler'), findsOneWidget);
    await tester.tap(find.byType(PixelDialogue));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Second line'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('Pixel lab fits a 2.75 dpr phone at 2x text', (tester) async {
    tester.view.physicalSize = const Size(880, 1562);
    tester.view.devicePixelRatio = 2.75;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pixelSettingsStoreProvider.overrideWithValue(
            _MemoryPixelSettingsStore(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.pixel,
          home: const PixelLabScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('DESIGNER ART'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('PixelHotbar reports and marks the selected item', (
    tester,
  ) async {
    var index = 0;
    await _pumpPixel(
      tester,
      StatefulBuilder(
        builder: (context, setState) => PixelHotbar(
          index: index,
          onTap: (value) => setState(() => index = value),
          items: const [
            PixelHotbarItem(label: 'Explore'),
            PixelHotbarItem(label: 'Shop'),
          ],
        ),
      ),
    );
    final semantics = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Shop')),
      containsSemantics(label: 'Shop', isButton: true, isSelected: false),
    );
    await tester.tap(find.bySemanticsLabel('Shop'));
    await tester.pump();
    expect(index, 1);
    expect(
      tester.getSemantics(find.bySemanticsLabel('Shop')),
      containsSemantics(label: 'Shop', isButton: true, isSelected: true),
    );
    semantics.dispose();
  });
}
