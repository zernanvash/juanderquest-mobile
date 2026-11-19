import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/pixel/generated/designer_art.g.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../core/realtime/realtime_provider.dart';
import '../pixel/pixel_tag.dart';
import '../widgets/sponsorship_conditions_widgets.dart';
import 'sponsor_request_screen.dart';

class QuestFundingScreen extends ConsumerStatefulWidget {
  final String questId;
  const QuestFundingScreen({super.key, required this.questId});
  @override
  ConsumerState<QuestFundingScreen> createState() => _QuestFundingScreenState();
}

class _QuestFundingScreenState extends ConsumerState<QuestFundingScreen> {
  final _completions = TextEditingController(text: '10');
  final _points = TextEditingController();
  Map<String, dynamic>? _plan;
  String _mode = 'budget';
  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(days: 14));
  bool _loading = true, _busy = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _completions.dispose();
    _points.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/quests/${Uri.encodeComponent(widget.questId)}/funding-plan');
      if (response.data['success'] != true) {
        throw Exception('Could not load this funding plan.');
      }
      setState(() {
        _plan = response.data['data']['plan'] as Map<String, dynamic>?;
        _error = null;
      });
    } on DioException catch (dioError) {
      if (dioError.response?.statusCode == 404) {
        setState(() {
          _plan = null;
          _error = null;
        });
      } else {
        final data = dioError.response?.data;
        String? serverMsg;
        if (data is Map && data['error'] is Map) {
          serverMsg = data['error']['message']?.toString();
        }
        setState(
            () => _error = serverMsg ?? 'Could not load this funding plan.');
      }
    } catch (error) {
      setState(() => _error = 'Could not load this funding plan.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _run(String success, Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      await action();
      if (!mounted) return;
      setState(() => _notice = success);
      await _load();
    } catch (error) {
      if (mounted) {
        if (error is DioException) {
          final data = error.response?.data;
          String? serverMsg;
          if (data is Map && data['error'] is Map) {
            serverMsg = data['error']['message']?.toString();
          }
          setState(
              () => _error = serverMsg ?? 'Action could not be completed.');
        } else {
          setState(
              () => _error = error.toString().replaceFirst('Exception: ', ''));
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final count = int.tryParse(_completions.text.trim());
    if (count == null || count < 1) {
      setState(() => _error = 'Enter at least one planned completion.');
      return;
    }
    await _run('Draft funding round created.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/quests/${Uri.encodeComponent(widget.questId)}/funding-plans',
          data: {
            'mode': _mode,
            'planned_completions': count,
            'starts_at': _starts.toUtc().toIso8601String(),
            'ends_at': _ends.toUtc().toIso8601String(),
            'idempotency_key': const Uuid().v4(),
          });
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding plan could not be created.');
      }
    });
  }

  Future<void> _contribute() async {
    final points = int.tryParse(_points.text.trim());
    final id = _plan?['id']?.toString();
    if (points == null || points < 1 || id == null) return;
    await _run('Contribution recorded from your demo-point balance.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/funding-plans/${Uri.encodeComponent(id)}/self-contribution',
          data: {
            'points': points,
            'idempotency_key': const Uuid().v4(),
          });
      if (response.data['success'] != true) {
        throw Exception(
            response.data['error']?['message'] ?? 'Contribution failed.');
      }
      _points.clear();
    });
  }

  Future<void> _submit() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    await _run(
        tr(
          context,
          en: 'Round submitted. You can now ask a merchant to sponsor it.',
          tl: 'Naisumite ang round. Maaari ka nang humiling sa tindahan.',
        ), () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/funding-plans/${Uri.encodeComponent(id)}/submit',
          data: {'idempotency_key': const Uuid().v4()});
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding plan could not be submitted.');
      }
    });
  }

  Future<void> _openAskMerchant() async {
    final planId = _plan?['id']?.toString();
    if (planId == null || planId.isEmpty) return;
    final sent = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SponsorRequestScreen(questId: widget.questId, planId: planId),
      ),
    );
    if (sent == true && mounted) {
      await _load();
    }
  }

  Future<void> _acceptCounter(Map sponsorship) async {
    final id = sponsorship['id']?.toString();
    if (id == null) return;
    final version = _asIntOrNull(sponsorship['terms_version']) ??
        int.tryParse('${sponsorship['terms_version']}') ??
        1;
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      final response = await ref.read(apiClientProvider).dio.post(
        '/sponsorships/${Uri.encodeComponent(id)}/accept-counter',
        data: {
          'terms_version': version,
          'idempotency_key': const Uuid().v4(),
        },
      );
      if (response.data['success'] != true) {
        throw Exception(
          response.data['error']?['message'] ??
              'Counter could not be accepted.',
        );
      }
      if (!mounted) return;
      setState(
        () => _notice = tr(
          context,
          en: 'Merchant counter-offer accepted.',
          tl: 'Tinanggap ang counter-offer ng tindahan.',
        ),
      );
      await _load();
    } on DioException catch (e) {
      if (!mounted) return;
      final body = e.response?.data;
      final code = body is Map && body['error'] is Map
          ? body['error']['code']?.toString()
          : null;
      if (code == 'CONDITIONS_NOT_MET') {
        final rawConds = body is Map && body['data'] is Map
            ? body['data']['conditions']
            : sponsorship['conditions'];
        final parsed = [
          if (rawConds is List)
            for (final c in rawConds)
              if (c is Map)
                SponsorshipConditionData.fromJson(Map<String, dynamic>.from(c)),
        ];
        final unmetDetails = parsed
            .where((c) => !c.isMet)
            .map((c) => c.detail.isNotEmpty
                ? c.detail
                : conditionLabelText(context, c.type, c.value))
            .join(' · ');
        setState(() {
          _error = unmetDetails.isNotEmpty
              ? "The shop's conditions aren't met yet. $unmetDetails"
              : "The shop's conditions aren't met yet.";
        });
      } else {
        final serverMsg = body is Map && body['error'] is Map
            ? body['error']['message']?.toString()
            : null;
        setState(
          () => _error = serverMsg ?? 'Counter could not be accepted.',
        );
      }
    } catch (err) {
      if (mounted) {
        setState(() => _error = err.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _withdraw(String sponsorshipId) async {
    await _run(
        tr(
          context,
          en: 'Sponsorship request withdrawn.',
          tl: 'Binawi ang hiling na sponsorship.',
        ), () async {
      final response = await ref.read(apiClientProvider).dio.post(
        '/sponsorships/${Uri.encodeComponent(sponsorshipId)}/withdraw',
        data: {'idempotency_key': const Uuid().v4()},
      );
      if (response.data['success'] != true) {
        throw Exception(
          response.data['error']?['message'] ?? 'Could not withdraw request.',
        );
      }
    });
  }

  Future<void> _cancel() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    if (!await _confirmEnd(close: false)) return;
    if (!mounted) return;
    await _run('Round cancelled and any locked points refunded.', () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/funding-plans/${Uri.encodeComponent(id)}/cancel',
          data: {'idempotency_key': const Uuid().v4()});
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding plan could not be cancelled.');
      }
    });
  }

  Future<void> _close() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    if (!await _confirmEnd(close: true)) return;
    if (!mounted) return;
    await _run(
        'Round closed. Existing traveler reward holds will still be honored.',
        () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/funding-plans/${Uri.encodeComponent(id)}/close',
          data: {'idempotency_key': const Uuid().v4()});
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding plan could not be closed.');
      }
    });
  }

  Future<void> _extend() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
    await _run('Funding window extended.', () async {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post('/funding-plans/${Uri.encodeComponent(id)}/extend', data: {
        'ends_at': _ends.toUtc().toIso8601String(),
        'idempotency_key': const Uuid().v4(),
      });
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding window could not be extended.');
      }
    });
  }

  Future<void> _chooseDate(bool start) async {
    final initial = start ? _starts : _ends;
    final date = await showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(initial));
    if (time == null || !mounted) return;
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    setState(() => start ? _starts = value : _ends = value);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(fundingChangedProvider, (_, __) => _load());
    final status = _plan?['status']?.toString() ?? '';
    final canContribute =
        ['draft', 'pending_sponsors', 'active'].contains(status);
    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          final canPop = Navigator.of(context).canPop();
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: Column(
                children: [
                  PixelAppBar(
                    title: 'Quest funding',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: PixelLoader(label: 'Loading funding plan'))
                        // A short management page: build every panel so
                        // the controls below the overview stay reachable.
                        : SingleChildScrollView(
                            padding: EdgeInsets.fromLTRB(
                              grid.gutter,
                              grid.px(3),
                              grid.gutter,
                              grid.px(8) + MediaQuery.paddingOf(context).bottom,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Fund a real reward pool',
                                    style: PixelType.title(context)),
                                SizedBox(height: grid.px(1)),
                                Text(
                                  'Demo points only. Reserved funds pay approved completions; no fiat or on-chain transfer occurs.',
                                  style: PixelType.body(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                ),
                                SizedBox(height: grid.px(3)),
                                if (_error != null) ...[
                                  _message(context, grid, _error!, error: true),
                                  SizedBox(height: grid.px(2)),
                                ],
                                if (_notice != null) ...[
                                  _message(context, grid, _notice!,
                                      error: false),
                                  SizedBox(height: grid.px(2)),
                                ],
                                if (_plan == null)
                                  _createCard(context, grid)
                                else ...[
                                  _overviewPanel(context, grid, status),
                                  SizedBox(height: grid.px(3)),
                                  _planCard(
                                      context, grid, status, canContribute),
                                  _sponsorshipsPanel(context, grid),
                                  _historyPanel(context, grid),
                                ],
                                SizedBox(height: grid.px(3)),
                                _message(
                                  context,
                                  grid,
                                  'Accepted traveler submissions keep their reward reserved while under review. Rejected proof can be resubmitted before the hold expires.',
                                  error: false,
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _createCard(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 20,
                child: FittedBox(
                  child: PixelSprite(DesignerArt.handshake, scale: 1),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child:
                    Text('Set up this round', style: PixelType.title(context)),
              ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Text('No funding round yet — set one up below',
              style: PixelType.body(context, color: PixelPalette.slate)),
          SizedBox(height: grid.px(2)),
          Text('FUNDING MODEL',
              style: PixelType.small(context, color: PixelPalette.slate)),
          SizedBox(height: grid.px(1)),
          PixelSegmented(
            items: const ['Fixed budget', 'Open window'],
            selectedIndex: _mode == 'budget' ? 0 : 1,
            onChanged: _busy
                ? (_) {}
                : (index) =>
                    setState(() => _mode = index == 0 ? 'budget' : 'window'),
          ),
          SizedBox(height: grid.px(2)),
          PixelTextField(
            key: const ValueKey('funding_completions'),
            controller: _completions,
            label: 'Planned completions',
            keyboardType: TextInputType.number,
          ),
          SizedBox(height: grid.px(2)),
          _dateButton(context, 'Starts', _starts, () => _chooseDate(true)),
          _dateButton(context, 'Ends', _ends, () => _chooseDate(false)),
          SizedBox(height: grid.px(3)),
          PixelButton(
            key: const ValueKey('funding_create'),
            label: _busy ? 'Creating' : 'Create draft funding plan',
            expand: true,
            loading: _busy,
            onPressed: _busy ? null : _create,
          ),
        ],
      ),
    );
  }

  Widget _planCard(
      BuildContext context, PixelGrid grid, String status, bool canContribute) {
    final ended = ['closed', 'expired', 'cancelled'].contains(status);
    return PixelPanel(
      key: const ValueKey('funding_controls'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, en: 'Manage round', tl: 'Pamahalaan ang round'),
              style: PixelType.title(context)),
          if (ended) ...[
            SizedBox(height: grid.px(1)),
            Text(
              tr(context,
                  en: 'This round has ended. Unused points went back to their funders.',
                  tl: 'Tapos na ang round na ito. Naibalik sa mga nagpondo ang hindi nagamit na puntos.'),
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
          ],
          if (canContribute) ...[
            SizedBox(height: grid.px(2)),
            PixelTextField(
              key: const ValueKey('funding_points'),
              controller: _points,
              label: 'Add your demo points',
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_contribute'),
              label: _busy ? 'Saving' : 'Contribute points',
              expand: true,
              loading: _busy,
              onPressed: _busy ? null : _contribute,
            ),
          ],
          if (status == 'draft') ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_submit'),
              label: 'Submit funding round',
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : _submit,
            ),
          ],
          // The server takes sponsor requests while a round is
          // pending_sponsors or active (not scheduled).
          if (['pending_sponsors', 'active'].contains(status)) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_ask_merchant'),
              label: tr(
                context,
                en: 'ASK A MERCHANT',
                tl: 'HUMILING SA TINDAHAN',
              ),
              expand: true,
              onPressed: _busy ? null : _openAskMerchant,
            ),
          ],
          if (['pending_sponsors', 'scheduled'].contains(status)) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_cancel'),
              label: _busy
                  ? 'Cancelling'
                  : 'Cancel round and refund locked points',
              variant: PixelButtonVariant.danger,
              expand: true,
              onPressed: _busy ? null : _cancel,
            ),
          ],
          if (['active', 'scheduled'].contains(status)) ...[
            SizedBox(height: grid.px(2)),
            _dateButton(
                context, 'New end date', _ends, () => _chooseDate(false)),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_extend'),
              label: _busy ? 'Extending' : 'Extend funding window',
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _busy ? null : _extend,
            ),
          ],
          if (['active', 'closing'].contains(status)) ...[
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('funding_close'),
              label: _busy ? 'Closing' : 'Close round early',
              variant: PixelButtonVariant.danger,
              expand: true,
              onPressed: _busy ? null : _close,
            ),
          ],
        ],
      ),
    );
  }

  /// Team review 2026-11-19: "users dont have overview of numbers". Prefers
  /// the server's read-only `summary`; falls back to summing contributions.
  _FundingNumbers get _numbers => _FundingNumbers.from(_plan ?? const {});

  Widget _overviewPanel(BuildContext context, PixelGrid grid, String status) {
    final n = _numbers;
    final progress = n.target > 0 ? n.committed / n.target : 0.0;
    final rows = <(String, String)>[
      (
        tr(context, en: 'Per completion', tl: 'Bawat pagkumpleto'),
        '${n.reward} pts + ${n.fee} fee'
      ),
      (
        tr(context,
            en: 'Reserved for travelers', tl: 'Nakareserba sa travelers'),
        '${n.held} pts'
      ),
      (tr(context, en: 'Paid out', tl: 'Naibayad'), '${n.paid} pts'),
      (
        tr(context, en: 'Remaining', tl: 'Natitira'),
        '${n.remaining} pts (~${n.completionsLeft} rewards)'
      ),
      if (n.refunded > 0)
        (
          tr(context, en: 'Returned to funders', tl: 'Naibalik'),
          '${n.refunded} pts'
        ),
      (
        tr(context, en: 'Completions paid', tl: 'Bayad na pagkumpleto'),
        '${n.paidCount} of ${n.planned}'
      ),
      (
        tr(context, en: 'Travelers playing', tl: 'Naglalaro'),
        '${n.activeHolds}'
      ),
      (
        tr(context, en: 'Pending review', tl: 'Hinihintay ang review'),
        '${n.pendingReview}'
      ),
      (
        tr(context, en: 'Your points', tl: 'Iyong puntos'),
        '${n.authorCommitted} pts'
      ),
      (
        tr(context, en: 'Sponsors', tl: 'Mga sponsor'),
        '${n.sponsorCommitted} pts · ${n.acceptedSponsors} accepted · ${n.openRequests} open'
      ),
      (
        tr(context, en: 'Ends', tl: 'Matatapos'),
        _dateLabel(_plan?['ends_at']?.toString())
      ),
    ];
    return PixelPanel(
      key: const ValueKey('funding_overview'),
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox.square(
                dimension: 20,
                child: FittedBox(
                  child: PixelSprite(DesignerArt.handshake, scale: 1),
                ),
              ),
              SizedBox(width: grid.px(1)),
              Expanded(
                child: Text(tr(context, en: 'Overview', tl: 'Buod'),
                    style: PixelType.title(context)),
              ),
            ],
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              PixelTag(status.replaceAll('_', ' ').toUpperCase(),
                  key: const ValueKey('funding_status_tag')),
              PixelTag(n.mode == 'window'
                  ? tr(context, en: 'OPEN WINDOW', tl: 'BUKAS NA WINDOW')
                  : tr(context, en: 'FIXED BUDGET', tl: 'TAKDANG BADYET')),
            ],
          ),
          SizedBox(height: grid.px(2)),
          PixelProgressBar(value: progress, idle: false),
          SizedBox(height: grid.px(1)),
          Text(
            '${n.committed} committed of ${n.target} target',
            key: const ValueKey('funding_committed_line'),
            style:
                PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(2)),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(bottom: grid.px(1)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(row.$1,
                        style: PixelType.small(context,
                            color: PixelPalette.slate)),
                  ),
                  SizedBox(width: grid.px(2)),
                  Expanded(
                    child: Text(row.$2,
                        textAlign: TextAlign.end,
                        style: PixelType.small(context)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Contributions, sponsorships and traveler reservations, newest first.
  Widget _historyPanel(BuildContext context, PixelGrid grid) {
    final events = <(DateTime, String)>[];
    void add(Object? raw, String text) {
      final at = DateTime.tryParse('${raw ?? ''}');
      if (at != null) events.add((at, text));
    }

    for (final c
        in (_plan?['contributions'] as List? ?? const []).whereType<Map>()) {
      final who = c['funder_kind'] == 'merchant'
          ? tr(context, en: 'A sponsor', tl: 'Isang sponsor')
          : tr(context, en: 'You', tl: 'Ikaw');
      add(c['created_at'],
          '$who committed ${_asInt(c['committed_points'])} pts');
    }
    for (final s
        in (_plan?['sponsorships'] as List? ?? const []).whereType<Map>()) {
      final shop = s['merchant_name']?.toString() ?? 'Merchant';
      add(s['updated_at'] ?? s['created_at'],
          'Sponsor request · $shop · ${s['status'] ?? 'requested'}');
    }
    for (final h in (_plan?['holds'] as List? ?? const []).whereType<Map>()) {
      final pts = _asInt(h['reward_points']);
      switch (h['status']) {
        case 'paid':
          add(h['settled_at'] ?? h['created_at'], 'Reward paid · $pts pts');
        case 'released':
          final reason = '${h['release_reason'] ?? ''}'.replaceAll('_', ' ');
          add(h['released_at'] ?? h['created_at'],
              'Reservation returned${reason.isEmpty ? '' : ' · $reason'}');
        default:
          add(
              h['created_at'],
              h['attempt_status'] == 'submitted'
                  ? 'Traveler submitted proof · $pts pts reserved'
                  : 'Traveler accepted · $pts pts reserved');
      }
    }
    events.sort((a, b) => b.$1.compareTo(a.$1));
    final shown = events.take(30).toList();
    return Padding(
      padding: EdgeInsets.only(top: grid.px(3)),
      child: PixelPanel(
        key: const ValueKey('funding_history'),
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(context, en: 'History', tl: 'Kasaysayan'),
                style: PixelType.title(context)),
            SizedBox(height: grid.px(1)),
            if (shown.isEmpty)
              Text(
                tr(context,
                    en: 'Nothing has happened in this round yet.',
                    tl: 'Wala pang nangyari sa round na ito.'),
                style: PixelType.small(context, color: PixelPalette.slate),
              ),
            for (final e in shown)
              Padding(
                padding: EdgeInsets.only(top: grid.px(1)),
                child: Text(
                  '${_dateLabel(e.$1.toIso8601String())} · ${e.$2}',
                  style: PixelType.small(context),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Team review 2026-11-19: "add a prompt warning when cancelling a fund and
  /// add details whats affected". Mirrors the server: close/cancel refund the
  /// unreserved budget, expire open sponsor requests and pause the quest once
  /// no traveler reservation is still open; open reservations are honored.
  Future<bool> _confirmEnd({required bool close}) async {
    final n = _numbers;
    final budget = n.mode != 'window';
    final lines = <String>[
      if (close)
        tr(context,
            en: 'No new travelers can accept this quest from now on.',
            tl: 'Wala nang bagong traveler na makakatanggap ng quest na ito.'),
      if (n.activeHolds > 0)
        tr(context,
            en: '${n.activeHolds} traveler(s) who already accepted keep their reserved reward (${n.held} pts) until they finish or the reservation runs out${n.pendingReview > 0 ? '; ${n.pendingReview} waiting for review will still be paid if approved' : ''}.',
            tl: 'Mananatili ang nakareserbang gantimpala (${n.held} pts) ng ${n.activeHolds} traveler na tumanggap na hanggang matapos sila o maubos ang reserba.'),
      if (budget && n.remaining > 0)
        tr(context,
            en: '${n.remaining} unreserved pts return now: ${n.authorRemaining} to you, ${n.sponsorRemaining} to sponsors.',
            tl: 'Ibabalik ngayon ang ${n.remaining} pts: ${n.authorRemaining} sa iyo, ${n.sponsorRemaining} sa mga sponsor.'),
      if (!budget)
        tr(context,
            en: 'Open-window funding: nothing more is taken from funders after this.',
            tl: 'Open window: wala nang kukunin sa mga nagpondo pagkatapos nito.'),
      if (n.openRequests > 0)
        tr(context,
            en: '${n.openRequests} open sponsor request(s) will be withdrawn.',
            tl: 'Babawiin ang ${n.openRequests} bukas na hiling sa sponsor.'),
      n.activeHolds > 0
          ? tr(context,
              en:
                  'The quest pauses after the last reservation resolves and pays no new rewards.',
              tl: 'Ihihinto ang quest kapag natapos ang huling reserba.')
          : tr(context,
              en: 'The quest pauses now and pays no new rewards.',
              tl: 'Ihihinto na ang quest at wala nang bagong gantimpala.'),
      tr(context,
          en: 'This cannot be undone. You can set up a new round later.',
          tl: 'Hindi na ito maibabalik. Maaari kang gumawa ng bagong round mamaya.'),
    ];
    final confirmed = await showPixelDialog<bool>(
      context: context,
      title: close
          ? tr(context, en: 'Close this round early?', tl: 'Isara nang maaga?')
          : tr(context, en: 'Cancel this round?', tl: 'Kanselahin ang round?'),
      content: Column(
        key: const ValueKey('funding_end_details'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('• $line', style: PixelType.body(context)),
            ),
        ],
      ),
      actions: [
        Builder(
          builder: (dialogContext) => PixelButton(
            key: const ValueKey('funding_end_keep'),
            label: tr(context, en: 'Keep round', tl: 'Huwag'),
            variant: PixelButtonVariant.secondary,
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
        ),
        Builder(
          builder: (dialogContext) => PixelButton(
            key: const ValueKey('funding_end_confirm'),
            label: close
                ? tr(context, en: 'Close round', tl: 'Isara')
                : tr(context, en: 'Cancel round', tl: 'Kanselahin'),
            variant: PixelButtonVariant.danger,
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ),
      ],
    );
    return confirmed == true;
  }

  Widget _sponsorshipsPanel(BuildContext context, PixelGrid grid) {
    final rows =
        (_plan?['sponsorships'] as List? ?? const []).whereType<Map>().toList();
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(top: grid.px(3)),
      child: PixelPanel(
        style: PixelBoxStyle.parchment,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr(
                context,
                en: 'SPONSORSHIP REQUESTS',
                tl: 'MGA HILING NA SPONSORSHIP',
              ),
              style: PixelType.title(context),
            ),
            SizedBox(height: grid.px(2)),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: grid.px(2)),
                  child: Container(
                    height: grid.unit,
                    color: PixelPalette.paperDim,
                  ),
                ),
              _sponsorshipRow(context, grid, rows[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _sponsorshipRow(
    BuildContext context,
    PixelGrid grid,
    Map sponsorship,
  ) {
    final id = sponsorship['id']?.toString() ?? '';
    final shopName = sponsorship['merchant_name']?.toString() ??
        sponsorship['merchant_id']?.toString() ??
        'Merchant';
    final status =
        (sponsorship['status']?.toString() ?? 'requested').toUpperCase();
    final pts = _asInt(sponsorship['points']);
    final vQty = _asInt(sponsorship['voucher_qty']);
    final rawConds = sponsorship['conditions'];
    final conditions = [
      if (rawConds is List)
        for (final c in rawConds)
          if (c is Map)
            SponsorshipConditionData.fromJson(Map<String, dynamic>.from(c)),
    ];
    final isCountered = status == 'COUNTERED';
    final isRequested = status == 'REQUESTED';
    final counterPts = _asIntOrNull(sponsorship['counter_points']) ?? pts;
    final counterVQty =
        _asIntOrNull(sponsorship['counter_voucher_qty']) ?? vQty;
    final counterMessage = sponsorship['counter_message']?.toString() ?? '';

    return Column(
      key: ValueKey('funding_sponsorship_$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: grid.px(1),
          runSpacing: grid.px(1),
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              shopName,
              style:
                  PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
            ),
            PixelTag(status),
            if (pts > 0) PixelTag('$pts pts'),
            if (vQty > 0) PixelTag('$vQty vouchers'),
          ],
        ),
        if (isCountered) ...[
          SizedBox(height: grid.px(1)),
          Text(
            tr(
              context,
              en: 'Counter terms: $counterPts pts${counterVQty > 0 ? ' · $counterVQty vouchers' : ''}${counterMessage.isNotEmpty ? ' · $counterMessage' : ''}',
              tl: 'Counter terms: $counterPts pts${counterVQty > 0 ? ' · $counterVQty vouchers' : ''}${counterMessage.isNotEmpty ? ' · $counterMessage' : ''}',
            ),
            style: PixelType.small(context, color: PixelPalette.goldDeep),
          ),
        ],
        if (conditions.isNotEmpty) ...[
          SizedBox(height: grid.px(1.5)),
          SponsorshipConditionsList(conditions: conditions),
        ],
        if (isCountered || isRequested) ...[
          SizedBox(height: grid.px(1.5)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              if (isCountered)
                PixelButton(
                  key: ValueKey('creator_accept_counter_$id'),
                  label: tr(
                    context,
                    en: 'ACCEPT COUNTER',
                    tl: 'TANGGAPIN ANG COUNTER',
                  ),
                  onPressed: _busy ? null : () => _acceptCounter(sponsorship),
                ),
              PixelButton(
                key: ValueKey('creator_withdraw_$id'),
                label: tr(context, en: 'WITHDRAW', tl: 'BAWIIN'),
                variant: PixelButtonVariant.danger,
                onPressed: _busy ? null : () => _withdraw(id),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _message(BuildContext context, PixelGrid grid, String message,
      {required bool error}) {
    return PixelPanel(
      style: error ? PixelBoxStyle.red : PixelBoxStyle.green,
      child: Text(
        message,
        style: PixelType.body(
          context,
          color: error ? PixelPalette.white : PixelPalette.cream,
        ),
      ),
    );
  }

  Widget _dateButton(
      BuildContext context, String label, DateTime date, VoidCallback onTap) {
    return Padding(
      padding: EdgeInsets.only(top: PixelGrid.of(context).px(1)),
      child: PixelButton(
        label: '$label · ${_dateLabel(date.toIso8601String())}',
        variant: PixelButtonVariant.secondary,
        expand: true,
        onPressed: _busy ? null : onTap,
      ),
    );
  }

  String _dateLabel(String? raw) {
    final date = DateTime.tryParse(raw ?? '');
    if (date == null) return 'not set';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${TimeOfDay.fromDateTime(date.toLocal()).format(context)}';
  }
}

/// Postgres BIGINT columns arrive as JSON strings ("100"); never cast them
/// with `as num` (owner 2026-11-18: contributing points crashed the screen).
int? _asIntOrNull(Object? value) =>
    value is num ? value.toInt() : int.tryParse('${value ?? ''}');

int _asInt(Object? value) => _asIntOrNull(value) ?? 0;

/// Overview numbers for one round (all plain ints).
class _FundingNumbers {
  const _FundingNumbers({
    required this.mode,
    required this.target,
    required this.committed,
    required this.held,
    required this.paid,
    required this.remaining,
    required this.refunded,
    required this.reward,
    required this.fee,
    required this.planned,
    required this.completionsLeft,
    required this.activeHolds,
    required this.pendingReview,
    required this.paidCount,
    required this.authorCommitted,
    required this.authorRemaining,
    required this.sponsorCommitted,
    required this.sponsorRemaining,
    required this.openRequests,
    required this.acceptedSponsors,
  });

  final String mode;
  final int target, committed, held, paid, remaining, refunded, reward, fee;
  final int planned, completionsLeft, activeHolds, pendingReview, paidCount;
  final int authorCommitted, authorRemaining, sponsorCommitted;
  final int sponsorRemaining, openRequests, acceptedSponsors;

  factory _FundingNumbers.from(Map plan) {
    final contributions =
        (plan['contributions'] as List? ?? const []).whereType<Map>().toList();
    final holds =
        (plan['holds'] as List? ?? const []).whereType<Map>().toList();
    final sponsorships =
        (plan['sponsorships'] as List? ?? const []).whereType<Map>().toList();
    int sum(Iterable<Map> rows, String field) =>
        rows.fold(0, (total, row) => total + _asInt(row[field]));
    final authorRows =
        contributions.where((c) => c['funder_kind'] != 'merchant');
    final sponsorRows =
        contributions.where((c) => c['funder_kind'] == 'merchant');
    final summary = plan['summary'] is Map ? plan['summary'] as Map : const {};
    final holdSummary =
        summary['holds'] is Map ? summary['holds'] as Map : const {};
    int pick(Map source, String key, int fallback) =>
        source.containsKey(key) ? _asInt(source[key]) : fallback;
    final reward = _asInt(plan['reward_points']);
    final fee = _asInt(plan['fee_points']);
    final remaining = pick(
        summary, 'remaining_points', sum(contributions, 'remaining_points'));
    final perCompletion = reward + fee;
    return _FundingNumbers(
      mode: plan['mode']?.toString() ?? 'budget',
      target: _asInt(plan['target_points']),
      committed: pick(
          summary, 'committed_points', sum(contributions, 'committed_points')),
      held: pick(summary, 'held_points', sum(contributions, 'held_points')),
      paid: pick(
          summary,
          'paid_points',
          sum(contributions, 'paid_reward_points') +
              sum(contributions, 'paid_fee_points')),
      remaining: remaining,
      refunded: pick(
          summary, 'refunded_points', sum(contributions, 'refunded_points')),
      reward: reward,
      fee: fee,
      planned: _asInt(plan['planned_completions']),
      completionsLeft: pick(summary, 'completions_left',
          perCompletion > 0 ? remaining ~/ perCompletion : 0),
      activeHolds: pick(holdSummary, 'active',
          holds.where((h) => h['status'] == 'held').length),
      pendingReview: pick(
          holdSummary,
          'pending_review',
          holds
              .where((h) =>
                  h['status'] == 'held' && h['attempt_status'] == 'submitted')
              .length),
      paidCount: pick(holdSummary, 'paid',
          holds.where((h) => h['status'] == 'paid').length),
      authorCommitted: sum(authorRows, 'committed_points'),
      authorRemaining: sum(authorRows, 'remaining_points'),
      sponsorCommitted: sum(sponsorRows, 'committed_points'),
      sponsorRemaining: sum(sponsorRows, 'remaining_points'),
      openRequests: sponsorships
          .where((s) => ['requested', 'countered'].contains(s['status']))
          .length,
      acceptedSponsors:
          sponsorships.where((s) => s['status'] == 'accepted').length,
    );
  }
}
