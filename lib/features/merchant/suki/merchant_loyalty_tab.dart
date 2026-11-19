import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../dashboard/pixel/home_pixel_art.dart';
import '../../quests/screens/qr_scan_screen.dart';
import '../providers/merchant_hub_provider.dart';
import '../widgets/merchant_counter.dart';
import 'merchant_suki_codes.dart';
import 'merchant_suki_models.dart';
import 'merchant_suki_widgets.dart';
import 'suki_standee_screen.dart';

/// The counter phone's GPS fix for "Pin shop location". Overridden in tests.
final merchantSukiPositionProvider =
    Provider<Future<Position?> Function()>((ref) => () async {
          try {
            var permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              permission = await Geolocator.requestPermission();
            }
            if (permission == LocationPermission.denied ||
                permission == LocationPermission.deniedForever) {
              return null;
            }
            return await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.high,
              timeLimit: const Duration(seconds: 15),
            );
          } catch (_) {
            return null;
          }
        });

/// Opens the camera and returns an accepted counter code (or null).
/// Overridden in tests.
final merchantSukiScannerProvider =
    Provider<Future<String?> Function(BuildContext context)>(
  (ref) => (context) => Navigator.of(context).push<String>(
        MaterialPageRoute(
          builder: (_) => const QrScanScreen(
            title: 'Scan a Suki pass, reward or voucher',
            extract: extractCounterCode,
            rejectedMessage: 'That is not a JuanderQuest counter code.',
          ),
        ),
      ),
);

const _kindLabels = ['FREE ITEM', '% OFF', '₱ OFF', 'PROMO'];
const _examples = [
  'Free iced coffee',
  'Free halo-halo',
  '10% off your order',
  'Buy 1 Take 1 halo-halo',
];

/// Plan 107 §7.4: the merchant hub's Loyalty tab (`/merchant?tab=loyalty`).
/// States: no program (setup form), draft (checklist + Activate), active
/// (SCAN, Print standee, stats, Pause), paused by admin.
class MerchantLoyaltyTab extends ConsumerStatefulWidget {
  const MerchantLoyaltyTab({super.key});

  @override
  ConsumerState<MerchantLoyaltyTab> createState() => _MerchantLoyaltyTabState();
}

class _MerchantLoyaltyTabState extends ConsumerState<MerchantLoyaltyTab> {
  MerchantSukiView? _view;
  MerchantSukiStats? _stats;
  Object? _error;
  bool _loading = true;
  bool _busy = false;
  bool _editing = false;

  final _title = TextEditingController(text: 'Suki Card');
  final _rewardText = TextEditingController();
  final _rewardValue = TextEditingController();
  int _kind = 0;
  int _visits = 10;
  bool _staffScan = false;
  String? _formError;

  MerchantApi get _api => ref.read(merchantApiProvider);

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _title.dispose();
    _rewardText.dispose();
    _rewardValue.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final view = await _api.suki();
      MerchantSukiStats? stats;
      if (view.program?.isActive == true) {
        try {
          stats = await _api.sukiStats();
        } catch (_) {
          stats = _stats;
        }
      }
      if (!mounted) return;
      setState(() {
        _view = view;
        _stats = stats;
        _fillForm(view.program);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _fillForm(MerchantSukiProgram? p) {
    if (p == null) return;
    _title.text = p.title;
    _rewardText.text = p.rewardText;
    _rewardValue.text =
        p.rewardValue == null ? '' : '${p.rewardValue!.round()}';
    _kind = sukiRewardKinds.indexOf(p.rewardKind).clamp(0, 3);
    _visits = p.visitsRequired;
    _staffScan = p.staffScan;
  }

  Future<void> _run(Future<MerchantSukiView> Function() work) async {
    setState(() => _busy = true);
    try {
      final view = await work();
      if (!mounted) return;
      setState(() {
        _view = view;
        _editing = false;
      });
      if (view.program?.isActive == true) await _load();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, merchantSukiErrorText(context, error));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    final valued = _kind == 1 || _kind == 2;
    final value = int.tryParse(_rewardValue.text.trim());
    final title = _title.text.trim();
    final reward = _rewardText.text.trim();
    String? problem;
    if (title.length < 3 || title.length > 60) {
      problem = tr(context,
          en: 'The card name needs 3 to 60 letters.',
          tl: '3 hanggang 60 titik ang pangalan.');
    } else if (reward.length < 3 || reward.length > 120) {
      problem = tr(context,
          en: 'Write the reward, e.g. "Free iced coffee".',
          tl: 'Isulat ang reward, hal. "Free iced coffee".');
    } else if (valued &&
        (value == null || value < 1 || value > (_kind == 1 ? 100 : 5000))) {
      problem = _kind == 1
          ? tr(context,
              en: 'Percent off must be 1 to 100.', tl: '1 hanggang 100 lang.')
          : tr(context,
              en: 'Peso off must be 1 to 5000.', tl: '1 hanggang 5000 lang.');
    }
    setState(() => _formError = problem);
    if (problem != null) return;
    await _run(() => _api.saveSuki({
          'title': title,
          'reward_kind': sukiRewardKinds[_kind],
          'reward_value': valued ? value : null,
          'reward_text': reward,
          'visits_required': _visits,
          'mode': _staffScan ? 'staff_scan' : 'standee',
          'radius_m': _view?.program?.radiusM ?? 75,
        }));
  }

  Future<void> _pinLocation() async {
    setState(() => _busy = true);
    final pos = await ref.read(merchantSukiPositionProvider)();
    if (!mounted) return;
    setState(() => _busy = false);
    if (pos == null) {
      showPixelToast(
          context,
          tr(context,
              en: 'Turn on location and allow JuanderQuest to use it.',
              tl: 'I-on ang lokasyon at payagan ang JuanderQuest.'));
      return;
    }
    await _run(() => _api.pinSukiLocation(
        lat: pos.latitude, lng: pos.longitude, accuracyM: pos.accuracy));
  }

  Future<void> _counterScan() async {
    await runMerchantCounter(context, ref);
    if (mounted) _load();
  }

  void _openStandee() {
    final router = GoRouter.maybeOf(context);
    if (router != null) {
      router.push('/merchant/suki/standee');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SukiStandeeScreen()),
      );
    }
  }

  Future<void> _rotateStandee() async {
    final ok = await showPixelDialog<bool>(
      context: context,
      title: tr(context, en: 'Replace the QR?', tl: 'Palitan ang QR?'),
      message: tr(context,
          en: 'Old printed standees stop working. Print the new one.',
          tl: 'Hindi na gagana ang lumang standee. I-print ang bago.'),
      actions: [
        Builder(
          builder: (ctx) => PixelButton(
            label: tr(ctx, en: 'Replace', tl: 'Palitan'),
            variant: PixelButtonVariant.danger,
            onPressed: () => Navigator.of(ctx).pop(true),
          ),
        ),
        Builder(
          builder: (ctx) => PixelButton(
            label: tr(ctx, en: 'Cancel', tl: 'Kanselahin'),
            variant: PixelButtonVariant.secondary,
            onPressed: () => Navigator.of(ctx).pop(false),
          ),
        ),
      ],
    );
    if (ok != true || !mounted) return;
    try {
      await _api.rotateSukiStandee();
      if (mounted) _openStandee();
    } catch (error) {
      if (mounted) {
        showPixelToast(context, merchantSukiErrorText(context, error));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final view = _view;
    if (_loading && view == null) {
      return const Center(child: PixelLoader(label: 'Loading Suki Card'));
    }
    if (view == null) {
      final disabled = isSukiDisabled(_error);
      return PixelPanel(
        key: ValueKey(disabled ? 'loyalty_disabled' : 'loyalty_error'),
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(merchantSukiErrorText(context, _error),
                style: PixelType.body(context)),
            if (!disabled) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: const ValueKey('loyalty_retry'),
                label: tr(context, en: 'Retry', tl: 'Subukang muli'),
                variant: PixelButtonVariant.secondary,
                onPressed: _load,
              ),
            ],
          ],
        ),
      );
    }
    final p = view.program;
    if (p == null || _editing) return _form(context, grid, view);

    final gap = SizedBox(height: grid.px(3));
    return Column(
      key: ValueKey(
          'loyalty_state_${p.adminPaused ? 'admin_paused' : p.status}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.adminPaused) ...[
          PixelPanel(
            key: const ValueKey('loyalty_admin_paused'),
            style: PixelBoxStyle.red,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context,
                      en: 'Paused by your LGU tourism office',
                      tl: 'Pinahinto ng LGU tourism office'),
                  style: PixelType.title(context, color: PixelPalette.white),
                ),
                if (p.pauseReason != null) ...[
                  SizedBox(height: grid.px(1)),
                  Text(
                    tr(context,
                        en: 'Reason: ${p.pauseReason}',
                        tl: 'Dahilan: ${p.pauseReason}'),
                    style: PixelType.body(context, color: PixelPalette.white),
                  ),
                ],
                SizedBox(height: grid.px(1)),
                Text(
                  tr(context,
                      en: 'Contact your LGU tourism office to resume it.',
                      tl: 'Makipag-ugnayan sa LGU tourism office para ituloy.'),
                  style: PixelType.body(context, color: PixelPalette.white),
                ),
              ],
            ),
          ),
          gap,
        ],
        if (p.isActive) ...[
          PixelButton(
            key: const ValueKey('loyalty_scan'),
            label: tr(context, en: 'SCAN', tl: 'I-SCAN'),
            expand: true,
            onPressed: _counterScan,
          ),
          SizedBox(height: grid.px(1)),
          Text(
            tr(context,
                en: 'Scans a Suki pass, a Suki reward or a Shop voucher.',
                tl: 'Suki pass, Suki reward o Shop voucher.'),
            textAlign: TextAlign.center,
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          gap,
        ],
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            PixelChip(_statusLabel(context, p),
                key: const ValueKey('loyalty_status'),
                style: p.isActive ? PixelBoxStyle.green : PixelBoxStyle.stone,
                textColor: PixelPalette.white),
            PixelChip(
                p.staffScan
                    ? tr(context, en: 'STAFF SCAN', tl: 'STAFF SCAN')
                    : tr(context, en: 'STANDEE', tl: 'STANDEE'),
                style: PixelBoxStyle.parchment),
          ],
        ),
        SizedBox(height: grid.px(2)),
        SukiCardPreview(
          title: p.title,
          visitsRequired: p.visitsRequired,
          rewardTag: p.rewardTag,
          rewardText: p.rewardText,
        ),
        if (!p.isActive) ...[gap, _checklist(context, grid, view)],
        if (p.isActive && _stats != null) ...[
          gap,
          SukiStatsPanel(stats: _stats!),
        ],
        gap,
        Wrap(
          spacing: grid.px(2),
          runSpacing: grid.px(2),
          children: [
            if (view.isOwner && p.isActive)
              PixelButton(
                key: const ValueKey('loyalty_pause'),
                label: tr(context, en: 'Pause', tl: 'Ihinto'),
                variant: PixelButtonVariant.secondary,
                loading: _busy,
                onPressed: () => _run(_api.pauseSuki),
              ),
            if (view.isOwner && !p.isActive)
              PixelButton(
                key: const ValueKey('loyalty_activate'),
                label: tr(context, en: 'Activate', tl: 'I-activate'),
                loading: _busy,
                onPressed:
                    p.adminPaused || !view.hasLocation || !view.isPublished
                        ? null
                        : () => _run(_api.activateSuki),
              ),
            if (!p.adminPaused)
              PixelButton(
                key: const ValueKey('loyalty_standee'),
                label:
                    tr(context, en: 'Print standee', tl: 'I-print ang standee'),
                variant: PixelButtonVariant.secondary,
                onPressed: _openStandee,
              ),
            if (view.isOwner && !p.adminPaused)
              PixelButton(
                key: const ValueKey('loyalty_edit'),
                label: tr(context, en: 'Edit card', tl: 'Baguhin'),
                variant: PixelButtonVariant.secondary,
                onPressed: () => setState(() {
                  _fillForm(p);
                  _formError = null;
                  _editing = true;
                }),
              ),
            if (view.isOwner && p.isActive)
              PixelButton(
                key: const ValueKey('loyalty_rotate'),
                label: tr(context, en: 'Replace QR', tl: 'Palitan ang QR'),
                variant: PixelButtonVariant.ghost,
                onPressed: _rotateStandee,
              ),
          ],
        ),
      ],
    );
  }

  String _statusLabel(BuildContext context, MerchantSukiProgram p) {
    if (p.adminPaused) {
      return tr(context, en: 'PAUSED BY LGU', tl: 'PINAHINTO NG LGU');
    }
    return switch (p.status) {
      'active' => tr(context, en: 'ACTIVE', tl: 'AKTIBO'),
      'paused' => tr(context, en: 'PAUSED', tl: 'NAKAHINTO'),
      _ => tr(context, en: 'DRAFT', tl: 'DRAFT'),
    };
  }

  Widget _checklist(
      BuildContext context, PixelGrid grid, MerchantSukiView view) {
    Widget row(bool ok, String text, Key key) => Padding(
          key: key,
          padding: EdgeInsets.symmetric(vertical: grid.px(1)),
          child: Row(
            children: [
              SizedBox.square(
                dimension: grid.px(8),
                child: ok
                    ? const FittedBox(
                        child: PixelSprite(HomePixelArt.stampCheck, scale: 1))
                    : const PixelPanel(
                        style: PixelBoxStyle.slot,
                        sunken: true,
                        padding: 0,
                        child: SizedBox.expand()),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(child: Text(text, style: PixelType.body(context))),
            ],
          ),
        );
    return PixelPanel(
      key: const ValueKey('loyalty_checklist'),
      style: PixelBoxStyle.parchment,
      padding: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr(context, en: 'Before you activate', tl: 'Bago i-activate'),
              style: PixelType.title(context)),
          SizedBox(height: grid.px(1)),
          row(
              view.hasLocation,
              tr(context,
                  en: 'Shop location pinned',
                  tl: 'Naka-pin ang lokasyon ng tindahan'),
              const ValueKey('loyalty_check_location')),
          row(
              view.isPublished,
              tr(context,
                  en: 'Shop profile published',
                  tl: 'Naka-publish ang profile ng tindahan'),
              const ValueKey('loyalty_check_published')),
          if (view.isOwner) ...[
            SizedBox(height: grid.px(1)),
            PixelButton(
              key: const ValueKey('loyalty_pin'),
              label: view.hasLocation
                  ? tr(context,
                      en: 'Pin again at the counter',
                      tl: 'I-pin muli sa counter')
                  : tr(context,
                      en: 'Pin shop location', tl: 'I-pin ang lokasyon'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              loading: _busy,
              onPressed: _pinLocation,
            ),
            SizedBox(height: grid.px(1)),
            Text(
              tr(context,
                  en: 'Stand at your counter when you pin, so customers can collect visits there.',
                  tl: 'Tumayo sa counter habang nagpi-pin.'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
        ],
      ),
    );
  }

  Widget _form(BuildContext context, PixelGrid grid, MerchantSukiView view) {
    if (!view.isOwner) {
      return PixelPanel(
        key: const ValueKey('loyalty_staff_only'),
        style: PixelBoxStyle.parchment,
        padding: 2,
        child: Text(
          tr(context,
              en: 'The shop owner sets up the Suki Card.',
              tl: 'Ang may-ari ang nagse-set up ng Suki Card.'),
          style: PixelType.body(context),
        ),
      );
    }
    final valued = _kind == 1 || _kind == 2;
    final value = num.tryParse(_rewardValue.text.trim());
    final gap = SizedBox(height: grid.px(2));
    return Column(
      key: const ValueKey('loyalty_form'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (view.program == null) ...[
          PixelPanel(
            key: const ValueKey('loyalty_intro'),
            style: PixelBoxStyle.parchment,
            padding: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  tr(context,
                      en: 'Turn your regulars into JuanderQuest explorers',
                      tl: 'Gawing JuanderQuest explorer ang mga suki mo'),
                  style: PixelType.title(context),
                ),
                SizedBox(height: grid.px(1)),
                Text(
                  tr(context,
                      en: 'Customers collect one visit a day at your counter. On the last visit they get your reward, which you give in kind. No points or money change hands.',
                      tl: 'Isang bisita bawat araw sa counter mo. Sa huling bisita, makukuha nila ang reward mo. Walang points o perang kailangan.'),
                  style: PixelType.body(context, color: PixelPalette.slate),
                ),
              ],
            ),
          ),
          SizedBox(height: grid.px(3)),
        ],
        PixelTextField(
          key: const ValueKey('loyalty_title'),
          controller: _title,
          label: tr(context, en: 'Card name', tl: 'Pangalan ng card'),
          onChanged: (_) => setState(() {}),
        ),
        gap,
        Text(tr(context, en: 'Reward type', tl: 'Uri ng reward'),
            style: PixelType.small(context)),
        SizedBox(height: grid.px(1)),
        PixelSegmented(
          key: const ValueKey('loyalty_kind'),
          items: _kindLabels,
          selectedIndex: _kind,
          onChanged: (i) => setState(() => _kind = i),
        ),
        if (valued) ...[
          gap,
          PixelTextField(
            key: const ValueKey('loyalty_value'),
            controller: _rewardValue,
            keyboardType: TextInputType.number,
            label: _kind == 1
                ? tr(context,
                    en: 'Percent off (1 to 100)',
                    tl: 'Porsyento (1 hanggang 100)')
                : tr(context,
                    en: 'Pesos off (1 to 5000)', tl: 'Piso (1 hanggang 5000)'),
            onChanged: (_) => setState(() {}),
          ),
        ],
        gap,
        PixelTextField(
          key: const ValueKey('loyalty_reward_text'),
          controller: _rewardText,
          label: tr(context, en: 'Reward line', tl: 'Reward'),
          hint: 'Free iced coffee',
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: grid.px(1)),
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          children: [
            for (final example in _examples)
              PixelChip(example,
                  style: PixelBoxStyle.slot,
                  onTap: () => setState(() => _rewardText.text = example)),
          ],
        ),
        gap,
        Text(tr(context, en: 'Visits needed', tl: 'Bilang ng bisita'),
            style: PixelType.small(context)),
        SizedBox(height: grid.px(1)),
        Row(
          children: [
            PixelButton(
              key: const ValueKey('loyalty_visits_minus'),
              label: '-',
              variant: PixelButtonVariant.secondary,
              onPressed: _visits > 3 ? () => setState(() => _visits--) : null,
            ),
            Expanded(
              child: Text('$_visits',
                  key: const ValueKey('loyalty_visits'),
                  textAlign: TextAlign.center,
                  style: PixelType.numbers(context)),
            ),
            PixelButton(
              key: const ValueKey('loyalty_visits_plus'),
              label: '+',
              variant: PixelButtonVariant.secondary,
              onPressed: _visits < 20 ? () => setState(() => _visits++) : null,
            ),
          ],
        ),
        gap,
        Text(tr(context, en: 'How visits are recorded', tl: 'Paano itatala'),
            style: PixelType.small(context)),
        SizedBox(height: grid.px(1)),
        PixelSegmented(
          key: const ValueKey('loyalty_mode'),
          items: [
            tr(context, en: 'Standee', tl: 'Standee'),
            tr(context, en: 'Staff scan', tl: 'Staff scan'),
          ],
          selectedIndex: _staffScan ? 1 : 0,
          onChanged: (i) => setState(() => _staffScan = i == 1),
        ),
        SizedBox(height: grid.px(1)),
        Text(
          _staffScan
              ? tr(context,
                  en: 'Staff scan the customer\'s 2-minute pass with SCAN.',
                  tl: 'Ini-scan ng staff ang 2-minutong pass ng customer.')
              : tr(context,
                  en: 'Customers scan the printed QR at your counter.',
                  tl: 'Ini-scan ng customer ang QR sa counter mo.'),
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(3)),
        Text(tr(context, en: 'Preview', tl: 'Silip'),
            style: PixelType.small(context)),
        SizedBox(height: grid.px(1)),
        SukiCardPreview(
          title: _title.text.trim().isEmpty ? 'Suki Card' : _title.text.trim(),
          visitsRequired: _visits,
          rewardTag:
              sukiRewardTag(sukiRewardKinds[_kind], valued ? value : null),
          rewardText:
              _rewardText.text.trim().isEmpty ? '…' : _rewardText.text.trim(),
        ),
        if (_formError != null) ...[
          gap,
          Text(_formError!,
              key: const ValueKey('loyalty_form_error'),
              style: PixelType.body(context, color: PixelPalette.redDeep)),
        ],
        SizedBox(height: grid.px(3)),
        Wrap(
          spacing: grid.px(2),
          runSpacing: grid.px(2),
          children: [
            PixelButton(
              key: const ValueKey('loyalty_save'),
              label: tr(context, en: 'Save card', tl: 'I-save'),
              loading: _busy,
              onPressed: _save,
            ),
            if (_editing)
              PixelButton(
                key: const ValueKey('loyalty_cancel'),
                label: tr(context, en: 'Cancel', tl: 'Kanselahin'),
                variant: PixelButtonVariant.secondary,
                onPressed: () => setState(() => _editing = false),
              ),
          ],
        ),
      ],
    );
  }
}
