import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
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
        'Round submitted. Sponsor matching can now continue on the web workspace.',
        () async {
      final response = await ref.read(apiClientProvider).dio.post(
          '/funding-plans/${Uri.encodeComponent(id)}/submit',
          data: {'idempotency_key': const Uuid().v4()});
      if (response.data['success'] != true) {
        throw Exception(response.data['error']?['message'] ??
            'Funding plan could not be submitted.');
      }
    });
  }

  Future<void> _cancel() async {
    final id = _plan?['id']?.toString();
    if (id == null) return;
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
                    title: 'Eco-Quest Funding',
                    onBack:
                        canPop ? () => Navigator.of(context).maybePop() : null,
                  ),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: PixelLoader(label: 'Loading funding plan'))
                        : ListView(
                            padding: EdgeInsets.fromLTRB(
                              grid.px(4),
                              grid.px(3),
                              grid.px(4),
                              grid.px(8) + MediaQuery.paddingOf(context).bottom,
                            ),
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
                                _message(context, grid, _notice!, error: false),
                                SizedBox(height: grid.px(2)),
                              ],
                              if (_plan == null)
                                _createCard(context, grid)
                              else
                                _planCard(context, grid, status, canContribute),
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
          Text('No funding round yet — set one up below',
              style: PixelType.title(context)),
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
    final contributions = (_plan?['contributions'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final committed = contributions.fold<int>(
        0,
        (sum, row) =>
            sum +
            ((row['committed_points'] as num?)?.toInt() ??
                int.tryParse('${row['committed_points']}') ??
                0));
    final held = contributions.fold<int>(
        0,
        (sum, row) =>
            sum +
            ((row['held_points'] as num?)?.toInt() ??
                int.tryParse('${row['held_points']}') ??
                0));
    return PixelPanel(
      style: PixelBoxStyle.parchment,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Funding round · ${status.replaceAll('_', ' ')}',
            style: PixelType.title(context),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            '${_plan?['reward_points'] ?? 0} points per completion · ${_plan?['mode'] ?? _mode} model',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          Text(
            'Target ${_plan?['target_points'] ?? 0} points · $committed committed · $held currently held',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          Text(
            'Ends ${_dateLabel(_plan?['ends_at']?.toString())}',
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          if (canContribute) ...[
            SizedBox(height: grid.px(3)),
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
          if (['pending_sponsors', 'scheduled'].contains(status)) ...[
            SizedBox(height: grid.px(2)),
            Text(
              'Use the web merchant workspace to invite sponsors. You can cancel this round here.',
              style: PixelType.body(context, color: PixelPalette.slate),
            ),
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
