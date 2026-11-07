import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:juanderquest_app/core/network/api_client.dart';
import 'package:juanderquest_app/core/network/api_failure.dart';
import 'package:juanderquest_app/core/pixel/pixel_controls.dart';
import 'package:juanderquest_app/features/auth/models/user_model.dart';
import 'package:juanderquest_app/features/auth/providers/auth_provider.dart';
import 'package:juanderquest_app/features/cosmetics/screens/appearance_screen.dart';
import 'package:juanderquest_app/features/profile/providers/profile_stats_provider.dart';
import 'package:juanderquest_app/features/profile/providers/user_spots_provider.dart';
import 'package:juanderquest_app/features/profile/screens/affiliate_application_screen.dart';
import 'package:juanderquest_app/features/profile/screens/profile_screen.dart';
import 'package:juanderquest_app/features/shop/models/cosmetic_item.dart';
import 'package:juanderquest_app/features/shop/models/shop_teaser.dart';
import 'package:juanderquest_app/features/shop/models/voucher_model.dart';
import 'package:juanderquest_app/features/shop/providers/cosmetics_provider.dart';
import 'package:juanderquest_app/features/shop/providers/voucher_provider.dart';
import 'package:juanderquest_app/features/shop/screens/shop_screen.dart';
import 'package:juanderquest_app/features/spots/models/spot_model.dart';
import 'package:juanderquest_app/features/spots/providers/spot_discovery_provider.dart';
import 'package:juanderquest_app/features/spots/screens/saved_spots_screen.dart';
import 'package:juanderquest_app/features/submissions/models/submission_model.dart';
import 'package:juanderquest_app/features/submissions/providers/submission_provider.dart';
import 'package:juanderquest_app/features/submissions/screens/submission_history_screen.dart';
import 'package:juanderquest_app/features/wallet/screens/wallet_connect_screen.dart';

class _Auth extends AuthNotifier {
  _Auth(super.apiClient, super.refreshNotifier, UserModel? user) {
    state = AuthState(user: user, token: user == null ? null : 'token');
  }

  @override
  Future<void> refreshProfile() async {}
}

class _CosmeticsFixture extends CosmeticsNotifier {
  _CosmeticsFixture(super.ref, CosmeticsState initial) {
    state = initial;
  }

  int loads = 0;
  int equips = 0;
  int purchases = 0;

  @override
  Future<void> load() async {
    loads++;
  }

  @override
  Future<String?> equip(CosmeticItem item, {bool clear = false}) async {
    equips++;
    return null;
  }

  @override
  Future<String?> purchase(CosmeticItem item) async {
    purchases++;
    return null;
  }
}

class _VoucherFixture extends VoucherNotifier {
  _VoucherFixture(super.ref, VoucherState initial) {
    state = initial;
  }

  int fetches = 0;
  int redeems = 0;

  @override
  Future<void> fetchVouchers() async {
    fetches++;
  }

  @override
  Future<
      ({
        bool success,
        String? code,
        String? error,
        RedeemedVoucherModel? redeemed
      })> redeemVoucher(VoucherModel voucher) async {
    redeems++;
    return (
      success: true,
      code: 'JDQ-CODE-1',
      error: null,
      redeemed: RedeemedVoucherModel(
        voucherId: voucher.id,
        merchantName: voucher.merchantName,
        offerTitle: voucher.offerTitle,
        code: 'JDQ-CODE-1',
        redeemedAt: DateTime(2026, 11, 3),
        expiresAt: DateTime(2026, 12, 3),
        costPoints: voucher.costPoints,
      ),
    );
  }
}

class _SubmissionFixture extends SubmissionNotifier {
  _SubmissionFixture(super.apiClient, SubmissionState initial) {
    state = initial;
  }

  int fetches = 0;

  @override
  Future<void> fetchSubmissions({bool force = false}) async {
    fetches++;
  }
}

class _SpotsFixture extends SpotDiscoveryNotifier {
  _SpotsFixture(super.ref, SpotDiscoveryState initial) {
    state = initial;
  }

  int loads = 0;
  int toggles = 0;

  @override
  Future<void> load({
    String query = '',
    String category = '',
    String intent = '',
    bool refresh = false,
  }) async {
    loads++;
  }

  @override
  Future<ApiFailure?> toggleSaved(SpotModel spot) async {
    toggles++;
    return null;
  }
}

class _Probe extends StatelessWidget {
  const _Probe(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text('route:$label')));
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.push('/wallet/connect'),
            child: const Text('OPEN'),
          ),
        ),
      );
}

GoRouter _router(Widget home, {String initial = '/'}) => GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/', builder: (_, __) => home),
        GoRoute(
            path: '/wallet/connect',
            builder: (_, __) => const WalletConnectScreen()),
        GoRoute(path: '/saved', builder: (_, __) => const _Probe('/saved')),
        GoRoute(
            path: '/explore/:slug',
            builder: (_, __) => const _Probe('/explore')),
        GoRoute(path: '/explore', builder: (_, __) => const _Probe('/explore')),
        GoRoute(path: '/shop', builder: (_, __) => const _Probe('/shop')),
        GoRoute(path: '/plaza', builder: (_, __) => const _Probe('/plaza')),
        GoRoute(path: '/settings', builder: (_, __) => const _Probe('/settings')),
        GoRoute(
            path: '/settings/appearance',
            builder: (_, __) => const _Probe('/settings/appearance')),
        GoRoute(path: '/trail', builder: (_, __) => const _Probe('/trail')),
        GoRoute(
            path: '/notifications',
            builder: (_, __) => const _Probe('/notifications')),
        GoRoute(path: '/profile', builder: (_, __) => const _Probe('/profile')),
        GoRoute(
            path: '/profile/badges',
            builder: (_, __) => const _Probe('/profile/badges')),
      ],
    );

final _user = UserModel(
  id: 'u1',
  seedId: 'scale-01',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 1250,
  walletAddress: '0x71C8363820F80E68370520C5C330938F48420E40',
);

final _unboundUser = UserModel(
  id: 'u1',
  seedId: 'scale-01',
  displayName: 'Juan Dela Cruz',
  email: 'juan@example.test',
  avatarUrl: '',
  role: 'explorer',
  demoPoints: 1250,
);

const _banner = CosmeticItem(
  id: 'banner-1',
  kind: 'banner',
  name: 'Lingayen Sunset',
  rarity: 'common',
  asset: {
    'style': 'procedural',
    'generator': 'sunset',
    'palette': 'golden',
    'colors': ['#2b2a5c', '#c8577a', '#f6a85a', '#ffe2a0'],
  },
  seed: 42,
  owned: true,
  equipped: true,
  buyable: false,
);

const _frame = CosmeticItem(
  id: 'frame-1',
  kind: 'frame',
  name: 'Bamboo Frame',
  rarity: 'rare',
  asset: {'colors': ['#ffd166']},
  owned: false,
  equipped: false,
  buyable: true,
  pricePoints: 300,
);

const _teaser = ShopTeaser(
  id: 'teaser-1',
  title: 'Seasonal stamps',
  description: 'Collect stamps every town you visit.',
  iconKey: 'sparkles',
  etaText: 'Next month',
);

final _voucher = VoucherModel(
  id: 'v1',
  merchantName: 'Dagupan Bangus Grill',
  offerTitle: '150 Discount Voucher',
  costPoints: 200,
  category: 'food_trade',
  location: 'Dagupan City',
  description: 'Enjoy grilled bangus.',
  isActive: true,
);

final _submission = SubmissionModel(
  id: 'sub-1',
  questTitle: 'Hundred Islands Eco Trek',
  category: 'eco',
  status: 'approved',
  rewardPoints: 50,
  createdAt: '2026-11-02T09:30:00Z',
);

final _rejected = SubmissionModel(
  id: 'sub-2',
  questTitle: 'Patar Beach Cleanup',
  category: 'eco',
  status: 'rejected',
  rewardPoints: 40,
  rejectionReason: 'Photo does not show the checkpoint.',
  createdAt: '2026-11-01T08:00:00Z',
);

const _spot = SpotModel(
  id: 's1',
  slug: 'hundred-islands',
  name: 'Hundred Islands National Park',
  description: 'Beautiful islands.',
  category: 'nature_outdoors',
  subcategory: 'islands',
  municipality: 'Alaminos City',
  address: 'Lucap Wharf',
  sourceName: 'Tourism Office',
  trustLevel: 'lgu_verified',
  gpsLat: 16.2,
  gpsLng: 120.0,
  tags: [],
  reasons: [],
  saved: true,
);

final _stats = ProfileStatsModel(
  completedQuestsCount: 7,
  pendingSubmissionsCount: 2,
  totalPointsEarned: 900,
  ecoPioneerState: BadgeState.earned,
  heritageKeeperState: BadgeState.inProgress,
  foodExplorerState: BadgeState.locked,
);

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  String initial = '/',
  UserModel? user = _userPlaceholder,
  CosmeticsState cosmetics = const CosmeticsState(),
  VoucherState? vouchers,
  SubmissionState? submissions,
  SpotDiscoveryState spots = const SpotDiscoveryState(isInitialLoading: false),
  ProfileStatsModel? stats,
  ApiClient? apiClient,
  CosmeticsNotifier Function(Ref ref)? cosmeticsNotifier,
  VoucherNotifier Function(Ref ref)? voucherNotifier,
  SubmissionNotifier Function(ApiClient client)? submissionNotifier,
  SpotDiscoveryNotifier Function(Ref ref)? spotsNotifier,
  List<Override> extraOverrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        if (apiClient != null) apiClientProvider.overrideWithValue(apiClient),
        authProvider.overrideWith((ref) => _Auth(
              ref.read(apiClientProvider),
              ref.watch(authRefreshProvider.notifier),
              user,
            )),
        profileStatsProvider.overrideWithValue(stats ?? _stats),
        cosmeticsProvider.overrideWith((ref) =>
            cosmeticsNotifier?.call(ref) ??
            _CosmeticsFixture(ref, cosmetics)),
        voucherProvider.overrideWith((ref) =>
            voucherNotifier?.call(ref) ??
            _VoucherFixture(ref, vouchers ?? VoucherState())),
        submissionProvider.overrideWith((ref) =>
            submissionNotifier?.call(ref.read(apiClientProvider)) ??
            _SubmissionFixture(
                ref.read(apiClientProvider), submissions ?? SubmissionState())),
        spotDiscoveryProvider.overrideWith((ref) =>
            spotsNotifier?.call(ref) ?? _SpotsFixture(ref, spots)),
        userSpotsProvider.overrideWith((ref, handle) => Future.value(const [])),
        ...extraOverrides,
      ],
      child: MaterialApp.router(routerConfig: _router(home, initial: initial)),
    ),
  );
  await tester.pump();
}

const UserModel? _userPlaceholder = null;

void _useTallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 6000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  group('ProfileScreen', () {
    testWidgets('renders identity, badges button, saved places and posted spots', (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(), user: _user);
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.text('@scale-01'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_badges')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_saved')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_customize')), findsOneWidget);
      expect(find.textContaining('Posted Destinations'), findsOneWidget);
    });

    testWidgets('empty profile shows the fallback identity', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(),
        user: null,
        stats: ProfileStatsModel(
          completedQuestsCount: 0,
          pendingSubmissionsCount: 0,
          totalPointsEarned: 0,
          ecoPioneerState: BadgeState.locked,
          heritageKeeperState: BadgeState.locked,
          foodExplorerState: BadgeState.locked,
        ),
      );
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_badges')), findsOneWidget);
    });

    testWidgets('opens notifications and settings', (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(), user: _user);
      await tester.tap(find.bySemanticsLabel('Notifications'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/notifications'), findsOneWidget);

      await _pump(tester, const ProfileScreen(), user: _user);
      await tester.tap(find.bySemanticsLabel('Explorer Settings'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/settings'), findsOneWidget);
    });

    testWidgets('opens saved destinations', (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(), user: _user);
      await tester.tap(find.byKey(const ValueKey('profile_saved')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/saved'), findsOneWidget);
    });

    testWidgets('has no shop or settings rows (tab and header gear instead)',
        (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(), user: _user);
      expect(find.byKey(const ValueKey('profile_shop')), findsNothing);
      expect(find.byKey(const ValueKey('profile_settings')), findsNothing);
    });

    testWidgets('opens badges case and customize appearance', (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(), user: _user);
      await tester.tap(find.byKey(const ValueKey('profile_badges')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/profile/badges'), findsOneWidget);

      await _pump(tester, const ProfileScreen(), user: _user);
      await tester.tap(find.byKey(const ValueKey('profile_customize')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/settings/appearance'), findsOneWidget);
    });

    testWidgets('guest profile shows follow', (tester) async {
      _useTallView(tester);
      await _pump(tester, const ProfileScreen(username: 'maya'),
          user: _user);
      expect(find.text('@maya'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('profile_follow')));
      await tester.pump();
      expect(find.text('Following'), findsOneWidget);
    });

    testWidgets('own profile loads posted destinations and tap opens /explore/:slug', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(),
        user: _user,
        extraOverrides: [
          userSpotsProvider('scale-01').overrideWith((ref) => Future.value([_spot])),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posted Destinations (1)'), findsOneWidget);
      expect(find.text('Hundred Islands National Park'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_post_spot')), findsOneWidget);

      await tester.tap(find.text('Hundred Islands National Park'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore'), findsOneWidget);
    });

    testWidgets('own profile empty state shows + Post a Destination CTA', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(),
        user: _user,
        extraOverrides: [
          userSpotsProvider('scale-01').overrideWith((ref) => Future.value([])),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posted Destinations (0)'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_no_spots')), findsOneWidget);
      expect(find.text('No destinations posted yet. Share a hidden spot in Pangasinan!'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_post_spot_empty')), findsOneWidget);
    });

    testWidgets('own profile error state shows retry button', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(),
        user: _user,
        extraOverrides: [
          userSpotsProvider('scale-01').overrideWith((ref) => Future.error(Exception('network error'))),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const ValueKey('profile_spots_error')), findsOneWidget);
      expect(find.text('Unable to load destinations.'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_spots_retry')), findsOneWidget);
    });

    testWidgets('other profile loads posted destinations and tap opens /explore/:slug', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(username: 'maya'),
        user: _user,
        extraOverrides: [
          userSpotsProvider('maya').overrideWith((ref) => Future.value([_spot])),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posted Destinations (1)'), findsOneWidget);
      expect(find.text('Hundred Islands National Park'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_post_spot')), findsNothing);

      await tester.tap(find.text('Hundred Islands National Park'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore'), findsOneWidget);
    });

    testWidgets('other profile empty state shows no destinations by this explorer and no CTA', (tester) async {
      _useTallView(tester);
      await _pump(
        tester,
        const ProfileScreen(username: 'maya'),
        user: _user,
        extraOverrides: [
          userSpotsProvider('maya').overrideWith((ref) => Future.value([])),
        ],
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Posted Destinations (0)'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_no_spots')), findsOneWidget);
      expect(find.text('No destinations posted yet by this explorer.'), findsOneWidget);
      expect(find.byKey(const ValueKey('profile_post_spot_empty')), findsNothing);
    });
  });
  group('ShopScreen', () {
    const cosmetics = CosmeticsState(
      items: [_banner, _frame],
      owned: [OwnedCosmetic(item: _banner, source: 'purchase')],
      teasers: [_teaser],
      loadout: {'banner_id': 'banner-1'},
    );

    testWidgets('renders cosmetics, vouchers and my items', (tester) async {
      await _pump(tester, const ShopScreen(),
          cosmetics: cosmetics,
          vouchers: VoucherState(vouchers: [_voucher]));
      expect(find.text('Lingayen Sunset'), findsOneWidget);
      expect(find.text('Bamboo Frame'), findsOneWidget);
      expect(find.text('1250 mJDQ'), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
      await tester.pump();
      expect(find.text('150 Discount Voucher'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop_tab_2')));
      await tester.pump();
      expect(find.text('Seasonal stamps'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('shop_tab_3')));
      await tester.pump();
      expect(find.text('Lingayen Sunset'), findsOneWidget);
      expect(find.byKey(const ValueKey('shop_redeemed_empty')), findsOneWidget);
    });

    testWidgets('empty shop shows every empty state', (tester) async {
      await _pump(tester, const ShopScreen());
      expect(find.byKey(const ValueKey('shop_cosmetics_empty')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop_vouchers_empty')),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_tab_2')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop_teasers_empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_tab_3')));
      await tester.pump();
      expect(find.byKey(const ValueKey('shop_owned_empty')), findsOneWidget);
    });

    testWidgets('cosmetics error retry calls load', (tester) async {
      late _CosmeticsFixture cosmeticsFixture;
      await _pump(
        tester,
        const ShopScreen(),
        cosmetics: const CosmeticsState(error: 'Shop could not be loaded.'),
        voucherNotifier: (ref) =>
            _VoucherFixture(ref, VoucherState(vouchers: [_voucher])),
        cosmeticsNotifier: (ref) => cosmeticsFixture = _CosmeticsFixture(
            ref, const CosmeticsState(error: 'Shop could not be loaded.')),
      );
      expect(find.text('Could not load the shop'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_error_retry')));
      await tester.pump();
      expect(cosmeticsFixture.loads, greaterThanOrEqualTo(1));
    });

    testWidgets('voucher error retry calls fetchVouchers', (tester) async {
      late _VoucherFixture voucherFixture;
      await _pump(
        tester,
        const ShopScreen(),
        voucherNotifier: (ref) => voucherFixture = _VoucherFixture(
            ref, VoucherState(error: 'Could not connect to voucher store.')),
      );
      await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
      await tester.pump();
      expect(find.text('Could not load the shop'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_error_retry')));
      await tester.pump();
      expect(voucherFixture.fetches, greaterThanOrEqualTo(1));
    });

    testWidgets('filter and live animation toggle work', (tester) async {
      await _pump(tester, const ShopScreen(), cosmetics: cosmetics);
      await tester.tap(find.byKey(const ValueKey('shop_filter_frame')));
      await tester.pump();
      expect(find.text('Bamboo Frame'), findsOneWidget);
      expect(find.text('Lingayen Sunset'), findsNothing);

      final before = find.textContaining('Live animations:').evaluate().length;
      expect(before, 1);
      await tester.tap(find.byKey(const ValueKey('shop_live_animations')));
      await tester.pump();
      expect(find.textContaining('Live animations:').evaluate().length, 1);
      expect(find.textContaining('Live animations: Off'), findsOneWidget);
    });

    testWidgets('cosmetic preview buys and closes', (tester) async {
      late _CosmeticsFixture fixture;
      await _pump(
        tester,
        const ShopScreen(),
        user: _user,
        cosmetics: cosmetics,
        cosmeticsNotifier: (ref) =>
            fixture = _CosmeticsFixture(ref, cosmetics),
      );
      await tester.tap(find.byKey(const ValueKey('shop_cosmetic_frame-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Buy for 300 points'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_buy_cosmetic')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.purchases, greaterThanOrEqualTo(1));

      await _pump(
        tester,
        const ShopScreen(),
        cosmetics: cosmetics,
        cosmeticsNotifier: (ref) =>
            fixture = _CosmeticsFixture(ref, cosmetics),
      );
      await tester.tap(find.byKey(const ValueKey('shop_cosmetic_banner-1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('shop_equip_cosmetic')));
      await tester.pump();
      expect(fixture.equips, greaterThanOrEqualTo(1));
    });

    testWidgets('voucher redeem asks for confirmation', (tester) async {
      late _VoucherFixture fixture;
      await _pump(
        tester,
        const ShopScreen(),
        user: _user,
        vouchers: VoucherState(vouchers: [_voucher]),
        voucherNotifier: (ref) => fixture = _VoucherFixture(
            ref, VoucherState(vouchers: [_voucher])),
      );
      await tester.tap(find.byKey(const ValueKey('shop_tab_1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('shop_redeem_v1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Cost deduction'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('shop_voucher_confirm')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(fixture.redeems, greaterThanOrEqualTo(1));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Voucher Ready to Use!'), findsOneWidget);
    });
  });

  group('AppearanceScreen', () {
    const loaded = CosmeticsState(
      items: [_banner, _frame],
      owned: [
        OwnedCosmetic(item: _banner, source: 'purchase'),
        OwnedCosmetic(item: _frame, source: 'purchase'),
      ],
      loadout: {'banner_id': 'banner-1'},
    );

    testWidgets('renders the loadout and opens the picker', (tester) async {
      late _CosmeticsFixture fixture;
      await _pump(
        tester,
        const AppearanceScreen(),
        cosmetics: loaded,
        cosmeticsNotifier: (ref) => fixture = _CosmeticsFixture(ref, loaded),
      );
      expect(find.text('Lingayen Sunset'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('appearance_banner_choose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('Choose Banner'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('appearance_pick_none')));
      await tester.pump();
      expect(fixture.equips, greaterThanOrEqualTo(1));

      await _pump(
        tester,
        const AppearanceScreen(),
        cosmetics: loaded,
        cosmeticsNotifier: (ref) => fixture = _CosmeticsFixture(ref, loaded),
      );
      await tester.tap(find.byKey(const ValueKey('appearance_frame_choose')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byKey(const ValueKey('appearance_pick_frame-1')));
      await tester.pump();
      expect(fixture.equips, greaterThanOrEqualTo(1));
    });

    testWidgets('empty loadout shows none selected', (tester) async {
      await _pump(tester, const AppearanceScreen());
      expect(find.text('None selected'), findsNWidgets(4));
    });

    testWidgets('error retry calls load', (tester) async {
      late _CosmeticsFixture fixture;
      await _pump(
        tester,
        const AppearanceScreen(),
        cosmetics: const CosmeticsState(error: 'Appearance unavailable.'),
        cosmeticsNotifier: (ref) => fixture = _CosmeticsFixture(
            ref, const CosmeticsState(error: 'Appearance unavailable.')),
      );
      expect(find.text('Could not load your items'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('appearance_retry')));
      await tester.pump();
      expect(fixture.loads, greaterThanOrEqualTo(1));
    });
  });

  group('WalletConnectScreen', () {
    testWidgets('renders the traveler card and goes back', (tester) async {
      await _pump(tester, const _Launcher(), user: _unboundUser);
      await tester.tap(find.text('OPEN'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('Juan Dela Cruz'), findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('OPEN'), findsOneWidget);
    });

    testWidgets('shows the configuration error and empty guest state',
        (tester) async {
      await _pump(tester, const WalletConnectScreen(),
          initial: '/wallet/connect', user: null);
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey('wallet_connect_error')),
          findsOneWidget);
      expect(find.text('Juan Dela Cruz'), findsNothing);
    });
  });

  group('SubmissionHistoryScreen', () {
    testWidgets('renders approved and rejected submissions', (tester) async {
      await _pump(
        tester,
        const SubmissionHistoryScreen(),
        submissions: SubmissionState(
          submissions: [_submission, _rejected],
          isLoading: false,
        ),
      );
      expect(find.text('Hundred Islands Eco Trek'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.text('+50 points earned'), findsOneWidget);
      expect(find.text('Reason: Photo does not show the checkpoint.'),
          findsOneWidget);
    });

    testWidgets('empty state refreshes', (tester) async {
      late _SubmissionFixture fixture;
      await _pump(
        tester,
        const SubmissionHistoryScreen(),
        submissionNotifier: (client) =>
            fixture = _SubmissionFixture(client, SubmissionState()),
      );
      expect(find.byKey(const ValueKey('submissions_empty')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('submissions_refresh')));
      await tester.pump();
      expect(fixture.fetches, greaterThanOrEqualTo(1));
    });

    testWidgets('error retry calls the reload', (tester) async {
      late _SubmissionFixture fixture;
      await _pump(
        tester,
        const SubmissionHistoryScreen(),
        submissionNotifier: (client) => fixture = _SubmissionFixture(
            client,
            SubmissionState(
              error: 'Could not reach the quest server.',
            )),
      );
      expect(find.text('Could not load history'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('submissions_error_retry')));
      await tester.pump();
      expect(fixture.fetches, greaterThanOrEqualTo(1));
    });
  });

  group('SavedSpotsScreen', () {
    testWidgets('filters, removes and opens a saved place', (tester) async {
      late _SpotsFixture fixture;
      const state = SpotDiscoveryState(
        spots: [_spot],
        isInitialLoading: false,
      );
      await _pump(
        tester,
        const SavedSpotsScreen(),
        spots: state,
        spotsNotifier: (ref) => fixture = _SpotsFixture(ref, state),
      );
      expect(find.text('Hundred Islands National Park'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('saved_thumb_s1'))),
        const Size(56, 56),
      );
      expect(find.textContaining('Alaminos City'), findsOneWidget);
      expect(find.textContaining('Alaminos City · NATURE'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('saved_search')), 'zzz');
      await tester.pump();
      expect(find.textContaining('No saved destination matches'), findsOneWidget);
      await tester.enterText(
          find.byKey(const ValueKey('saved_search')), 'hundred');
      await tester.pump();
      expect(find.text('Hundred Islands National Park'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved_remove')));
      await tester.pump();
      expect(fixture.toggles, greaterThanOrEqualTo(1));
      await tester.tap(find.byKey(const ValueKey('saved_spot_s1')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore'), findsOneWidget);
    });

    testWidgets('empty state goes to Explore', (tester) async {
      await _pump(tester, const SavedSpotsScreen(),
          spots: const SpotDiscoveryState(isInitialLoading: false));
      expect(find.byKey(const ValueKey('saved_empty')), findsOneWidget);
      await tester.tap(find.text('Explore places'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.text('route:/explore'), findsOneWidget);
    });

    testWidgets('error retry reloads', (tester) async {
      late _SpotsFixture fixture;
      const state = SpotDiscoveryState(
        isInitialLoading: false,
        failure: ApiFailure(code: 'OFFLINE', message: 'You are offline.'),
      );
      await _pump(
        tester,
        const SavedSpotsScreen(),
        spots: state,
        spotsNotifier: (ref) => fixture = _SpotsFixture(ref, state),
      );
      expect(find.text('Could not load saved places'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('saved_error_retry')));
      await tester.pump();
      expect(fixture.loads, greaterThanOrEqualTo(1));
    });
  });

  group('AffiliateApplicationScreen', () {
    ApiClient stubClient() {
      final client = ApiClient();
      client.dio.interceptors.insert(
        0,
        InterceptorsWrapper(onRequest: (options, handler) {
          if (options.path == '/affiliate/applications/me') {
            handler.resolve(Response(
              requestOptions: options,
              statusCode: 200,
              data: {'success': true, 'data': null},
            ));
            return;
          }
          handler.next(options);
        }),
      );
      return client;
    }

    testWidgets('renders the form and validates required fields',
        (tester) async {
      _useTallView(tester);
      await _pump(tester, const AffiliateApplicationScreen(),
          apiClient: stubClient());
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('Partner with local tourism'), findsOneWidget);
      expect(find.text('Submit Application'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('affiliate_submit')));
      await tester.pump();
      expect(find.text('Enter Business name'), findsOneWidget);
    });

    testWidgets('search error and goal toggles', (tester) async {
      _useTallView(tester);
      await _pump(tester, const AffiliateApplicationScreen(),
          apiClient: stubClient());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('affiliate_search_map')));
      await tester.pump();
      expect(find.text('Enter at least two characters to search.'),
          findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('affiliate_goal_quest_stop')));
      await tester.pump();
      expect(find.byKey(const ValueKey('affiliate_goal_quest_stop')),
          findsOneWidget);
    });

    testWidgets('category picker opens and selects', (tester) async {
      _useTallView(tester);
      await _pump(tester, const AffiliateApplicationScreen(),
          apiClient: stubClient());
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.byKey(const ValueKey('affiliate_category')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.widgetWithText(PixelButton, 'dining'), findsOneWidget);
      await tester.tap(find.widgetWithText(PixelButton, 'dining'));
      await tester.pump();
      expect(find.text('dining'), findsOneWidget);
    });
  });
}
