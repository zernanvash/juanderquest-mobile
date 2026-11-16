import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/settings/screens/settings_notifications_screen.dart';

ApiClient _client({
  required Map<String, dynamic> Function() onGet,
  required void Function(Map<String, dynamic> body) onPut,
  bool failPut = false,
}) {
  final client = ApiClient();
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      if (options.method == 'GET') {
        handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'success': true, 'data': onGet()},
        ));
        return;
      }
      onPut(Map<String, dynamic>.from(options.data as Map));
      if (failPut) {
        handler.reject(DioException(
          requestOptions: options,
          response: Response(requestOptions: options, statusCode: 503),
          type: DioExceptionType.badResponse,
        ));
        return;
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': onGet()},
      ));
    }),
  );
  return client;
}

Future<void> _pump(WidgetTester tester, ApiClient client,
    {Size size = const Size(400, 900), double textScale = 1.0}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiClientProvider.overrideWithValue(client)],
    child: MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: const SettingsNotificationsScreen(),
    ),
  ));
  await tester.pumpAndSettle();
}

/// Owner 2026-11-16: Settings -> Notifications edits /me/notification-preferences.
void main() {
  final server = <String, dynamic>{
    'push_overtaken': true,
    'push_friend_activity': false,
    'push_social': true,
    'push_weekly_recap': true,
    'quiet_hours': true,
  };

  testWidgets('shows the saved values and saves one switch at a time',
      (tester) async {
    final values = Map<String, dynamic>.from(server);
    final puts = <Map<String, dynamic>>[];
    await _pump(
        tester,
        _client(
            onGet: () => values,
            onPut: (b) {
              puts.add(b);
              values.addAll(b);
            }));

    for (final k in server.keys) {
      expect(find.byKey(ValueKey('notif_$k')), findsOneWidget, reason: k);
    }
    expect(
        tester
            .widget<PixelSwitch>(
                find.byKey(const ValueKey('notif_switch_push_friend_activity')))
            .value,
        isFalse);

    await tester
        .tap(find.byKey(const ValueKey('notif_switch_push_weekly_recap')));
    await tester.pumpAndSettle();
    expect(puts, [
      {'push_weekly_recap': false}
    ]);
    expect(values['push_weekly_recap'], isFalse);
  });

  testWidgets('a failed save flips the switch back and says so',
      (tester) async {
    final puts = <Map<String, dynamic>>[];
    await _pump(
        tester,
        _client(
            onGet: () => Map<String, dynamic>.from(server),
            onPut: puts.add,
            failPut: true));

    await tester.tap(find.byKey(const ValueKey('notif_switch_quiet_hours')));
    await tester.pumpAndSettle();
    expect(puts, [
      {'quiet_hours': false}
    ]);
    expect(find.textContaining("Couldn't save."), findsOneWidget);
    expect(
        tester
            .widget<PixelSwitch>(
                find.byKey(const ValueKey('notif_switch_quiet_hours')))
            .value,
        isTrue);
  });

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets('fits $size at 2.0x text', (tester) async {
      await _pump(
          tester,
          _client(
              onGet: () => Map<String, dynamic>.from(server), onPut: (_) {}),
          size: size,
          textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('notif_quiet_hours')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
