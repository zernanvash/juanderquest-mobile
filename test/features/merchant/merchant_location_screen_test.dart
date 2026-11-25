import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:juanderquest_app/core/pixel/pixel_grid.dart';
import 'package:juanderquest_app/features/merchant/screens/merchant_location_screen.dart';

class _FakeMerchantLocationApi implements MerchantLocationApi {
  MerchantLinkedSpot? linked;
  MerchantPendingClaim? pending;
  final List<MerchantLinkedSpot> authored = const [
    MerchantLinkedSpot(
      id: 'spot-auth-1',
      slug: 'kape-pangasinan',
      name: 'Kape Pangasinan',
      municipality: 'Lingayen',
      gpsLat: 16.025,
      gpsLng: 120.231,
    ),
  ];

  @override
  Future<MerchantLocationCandidates> fetchCandidates() async =>
      MerchantLocationCandidates(
        authoredSpots: authored,
        linkedSpot: linked,
        pendingClaim: pending,
      );

  @override
  Future<MerchantLinkedSpot> linkAuthoredSpot(String spotId) async {
    linked = authored.firstWhere((s) => s.id == spotId);
    pending = null;
    return linked!;
  }

  @override
  Future<void> unlinkLocation() async {
    linked = null;
  }

  @override
  Future<List<ClaimSpotHit>> searchSpots(String query) async => const [
        ClaimSpotHit(
          id: 'spot-lgu-1',
          slug: 'lingayen-capitol',
          name: 'Lingayen Capitol Grounds',
          municipality: 'Lingayen',
        ),
      ];

  @override
  Future<MerchantPendingClaim> submitClaim({
    required String spotId,
    required String note,
    String? proofUrl,
  }) async {
    pending = MerchantPendingClaim(
      id: 'msc-1',
      spotId: spotId,
      spotName: 'Lingayen Capitol Grounds',
      status: 'pending',
      createdAt: '2026-11-25T00:00:00Z',
    );
    return pending!;
  }

  @override
  Future<void> cancelClaim(String claimId) async {
    pending = null;
  }
}

void main() {
  testWidgets(
    'Plan 122a — MerchantLocationScreen supports instant link, unlink, and claim submit/cancel',
    (tester) async {
      final api = _FakeMerchantLocationApi();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [merchantLocationApiProvider.overrideWithValue(api)],
          child: const MaterialApp(
            home: PixelScope(
              settings: PixelSettings(),
              child: MerchantLocationScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Instant link authored spot
      expect(find.text('Kape Pangasinan'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('merchant_link_spot_spot-auth-1')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('merchant_location_unlink_btn')),
        findsOneWidget,
      );

      // 2. Unlink
      await tester.tap(
        find.byKey(const ValueKey('merchant_location_unlink_btn')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('merchant_location_unlink_btn')),
        findsNothing,
      );

      // 3. Search & submit claim
      await tester.enterText(
        find.byKey(const ValueKey('merchant_claim_search_input')),
        'Lingayen',
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('merchant_claim_search_btn')),
      );
      await tester.tap(find.byKey(const ValueKey('merchant_claim_search_btn')));
      await tester.pumpAndSettle();

      await tester.ensureVisible(
        find.byKey(const ValueKey('merchant_claim_hit_spot-lgu-1')),
      );
      await tester.tap(
        find.byKey(const ValueKey('merchant_claim_hit_spot-lgu-1')),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('merchant_claim_note_input')),
        'We operate our verified storefront inside Lingayen Capitol Grounds.',
      );
      ScaffoldMessenger.of(
        tester.element(find.byType(MerchantLocationScreen)),
      ).clearSnackBars();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('merchant_claim_submit_btn')),
      );
      await tester.tap(find.byKey(const ValueKey('merchant_claim_submit_btn')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('merchant_location_pending_banner')),
        findsOneWidget,
      );

      // 4. Cancel pending claim
      await tester.ensureVisible(
        find.byKey(const ValueKey('merchant_location_cancel_claim_btn')),
      );
      await tester.tap(
        find.byKey(const ValueKey('merchant_location_cancel_claim_btn')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('merchant_location_pending_banner')),
        findsNothing,
      );
    },
  );

  for (final size in const [Size(320, 568), Size(568, 320)]) {
    testWidgets(
      'Plan 122a — MerchantLocationScreen does not overflow at ${size.width.toInt()}x${size.height.toInt()} @ 2.0x text',
      (tester) async {
        final errors = <FlutterErrorDetails>[];
        final prev = FlutterError.onError;
        FlutterError.onError = errors.add;
        addTearDown(() => FlutterError.onError = prev);

        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final api = _FakeMerchantLocationApi()
          ..linked = const MerchantLinkedSpot(
            id: 'spot-auth-1',
            slug: 'kape-pangasinan',
            name: 'Kape Pangasinan Heritage Roasters & Cafe',
            municipality: 'Lingayen, Pangasinan',
            gpsLat: 16.025,
            gpsLng: 120.231,
          );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [merchantLocationApiProvider.overrideWithValue(api)],
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: const TextScaler.linear(2.0),
              ),
              child: const MaterialApp(
                home: PixelScope(
                  settings: PixelSettings(),
                  child: MerchantLocationScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final overflows = errors
            .where((e) => e.exceptionAsString().contains('overflowed'))
            .toList();
        expect(overflows, isEmpty);
      },
    );
  }
}
