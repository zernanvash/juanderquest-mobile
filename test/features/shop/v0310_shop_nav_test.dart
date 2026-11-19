import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/theme/app_theme.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/providers/shop_nav_provider.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';

/// v0.3.10 ("Exiting out of shop does not exit out of the sub pages"): the
/// Shop category lives in [shopCategoryProvider]; the bottom bar and the back
/// button reset it (see MainShell), so Shop reopens on its hub.

final _user = UserModel(
  id: 'u-310',
  seedId: 'u-310',
  email: 'shop@juanderquest.app',
  displayName: 'Shop 310',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 500,
);

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier) {
    state = AuthState(user: _user, token: 't');
  }

  @override
  Future<void> refreshProfile() async {}
}

ApiClient _client() {
  final client = ApiClient(enableRetries: false);
  client.dio.interceptors.insert(
    0,
    InterceptorsWrapper(onRequest: (options, handler) {
      Object data = const {};
      if (options.path == '/vouchers') {
        data = [
          {
            'id': 'v1',
            'merchant_id': 'm1',
            'merchant_name': 'Aling Nena Cafe',
            'title': 'Free halo-halo',
            'cost_points': 10,
            'availability': 'live',
            'redeemable': true,
          },
        ];
      }
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {'success': true, 'data': data},
      ));
    }),
  );
  return client;
}

void main() {
  testWidgets('a reset from the bottom bar returns Shop to its hub',
      (tester) async {
    tester.view.physicalSize = const Size(900, 3000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        apiClientProvider.overrideWithValue(_client()),
        authProvider.overrideWith((ref) => _Auth(ref.watch(apiClientProvider),
            ref.watch(authRefreshProvider.notifier))),
      ],
      child: MaterialApp(theme: AppTheme.pixel, home: const ShopScreen()),
    ));
    await tester.pumpAndSettle();
    final container =
        ProviderScope.containerOf(tester.element(find.byType(ShopScreen)));

    await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
    await tester.pumpAndSettle();
    expect(container.read(shopCategoryProvider), 1);
    expect(find.byKey(const ValueKey('shop_back_to_hub')), findsOneWidget);
    // The shop name on a Partner Voucher links to its page.
    expect(
        find.byKey(const ValueKey('shop_voucher_merchant_v1')), findsOneWidget);
    expect(find.text('Aling Nena Cafe >'), findsOneWidget);

    // What MainShell does when the Shop tab is tapped or back is pressed.
    container.read(shopCategoryProvider.notifier).state = null;
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('shop_back_to_hub')), findsNothing);
    expect(find.byKey(const ValueKey('shop_tab_1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
  });

  test('vouchers carry their merchant id', () {
    final v = VoucherModel.fromJson({'id': 'v1', 'merchant_id': 'm1'});
    expect(v.merchantId, 'm1');
    expect(VoucherModel.fromJson({'id': 'v2'}).merchantId, '');
  });
}
