import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../auth/providers/auth_provider.dart';
import '../theater/theater_panel.dart';

/// One field log ("comment") on a destination, as returned by
/// `GET /spots/:id/comments`.
class SpotComment {
  final String id;
  final String authorName;
  final String? authorBadge;
  final String tag;
  final String content;
  final int helpfulCount;
  final DateTime? createdAt;
  final bool verifiedVisit;

  const SpotComment({
    required this.id,
    required this.authorName,
    this.authorBadge,
    required this.tag,
    required this.content,
    required this.helpfulCount,
    this.createdAt,
    this.verifiedVisit = false,
  });

  factory SpotComment.fromJson(Map<String, dynamic> j) => SpotComment(
        id: '${j['id']}',
        authorName: (j['author_name'] as String?)?.trim().isNotEmpty == true
            ? j['author_name'] as String
            : 'Explorer',
        authorBadge: j['author_badge'] as String?,
        tag: j['tag'] as String? ?? 'general',
        content: j['content'] as String? ?? '',
        helpfulCount: (j['helpful_count'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse('${j['created_at']}'),
        verifiedVisit: j['is_verified_visit'] == true,
      );

  SpotComment copyWith({int? helpfulCount}) => SpotComment(
        id: id,
        authorName: authorName,
        authorBadge: authorBadge,
        tag: tag,
        content: content,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        createdAt: createdAt,
        verifiedVisit: verifiedVisit,
      );
}

/// Comment tags offered by the API (`createFieldLogSchema`).
const spotCommentTags = <String, String>{
  'general': 'General',
  'local_tip': 'Local tip',
  'food_find': 'Food find',
  'heritage': 'Heritage',
  'tide_condition': 'Tide / sea',
  'gear_alert': 'What to bring',
  'eco_watch': 'Eco watch',
};

/// Report reasons offered by the API (`createReportSchema`).
const spotReportReasons = <String, String>{
  'inaccurate_location': 'The location is wrong',
  'site_closed_or_hazard': 'Closed or unsafe',
  'misleading_photo': 'Misleading photo',
  'spam_or_scam': 'Spam or scam',
  'environmental_concern': 'Environmental concern',
  'other': 'Something else',
};

String _relative(DateTime? t) {
  if (t == null) return '';
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'just now';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  if (d.inDays < 30) return '${d.inDays}d ago';
  return '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
}

String _errorText(Object e, String fallback) {
  if (e is DioException) {
    final body = e.response?.data;
    if (body is Map && body['error'] is Map) {
      final m = (body['error'] as Map)['message'];
      if (m is String && m.isNotEmpty) return m;
    }
  }
  return fallback;
}

/// Likes, comments ("explorer notes") and problem reports for a destination —
/// restyled for the pixel theater layout.
class SpotCommunitySection extends ConsumerStatefulWidget {
  final String spotId;
  final String spotName;

  const SpotCommunitySection({
    super.key,
    required this.spotId,
    required this.spotName,
  });

  @override
  ConsumerState<SpotCommunitySection> createState() =>
      _SpotCommunitySectionState();
}

class _SpotCommunitySectionState extends ConsumerState<SpotCommunitySection> {
  final _composer = TextEditingController();
  List<SpotComment> _comments = const [];
  final Set<String> _helpfulVoted = {};
  bool _loading = true;
  String? _loadError;
  bool _posting = false;
  bool _liked = false;
  bool _liking = false;
  String _tag = 'general';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Dio get _dio => ref.read(apiClientProvider).dio;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final res = await _dio.get('/spots/${widget.spotId}/comments');
      final data = res.data is Map ? res.data['data'] : null;
      final list = data is List ? data : const [];
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final c in list)
            if (c is Map) SpotComment.fromJson(Map<String, dynamic>.from(c)),
        ];
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = 'Notes could not load.';
      });
    }
  }

  Future<void> _toggleLike() async {
    if (_liking) return;
    final next = !_liked;
    setState(() {
      _liked = next;
      _liking = true;
    });
    try {
      if (next) {
        await _dio.put('/spots/${widget.spotId}/like');
      } else {
        await _dio.delete('/spots/${widget.spotId}/like');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _liked = !next);
        _snack(_errorText(e, 'Could not update your like. Try again.'));
      }
    } finally {
      if (mounted) setState(() => _liking = false);
    }
  }

  Future<void> _post() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _posting) return;
    setState(() => _posting = true);
    try {
      final res = await _dio.post(
        '/spots/${widget.spotId}/comments',
        data: {'content': text, 'tag': _tag},
      );
      final data = res.data is Map ? res.data['data'] : null;
      if (!mounted) return;
      _composer.clear();
      setState(() {
        if (data is Map) {
          _comments = [
            SpotComment.fromJson(Map<String, dynamic>.from(data)),
            ..._comments,
          ];
        }
        _tag = 'general';
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) _snack(_errorText(e, 'Your note was not posted.'));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _markHelpful(SpotComment c) async {
    if (_helpfulVoted.contains(c.id)) return;
    setState(() => _helpfulVoted.add(c.id));
    try {
      final res =
          await _dio.post('/spots/${widget.spotId}/comments/${c.id}/helpful');
      final data = res.data is Map ? res.data['data'] : null;
      final count = data is Map ? (data['helpful_count'] as num?)?.toInt() : null;
      if (!mounted) return;
      setState(() {
        _comments = [
          for (final x in _comments)
            x.id == c.id
                ? x.copyWith(helpfulCount: count ?? x.helpfulCount + 1)
                : x,
        ];
      });
    } catch (e) {
      if (mounted) {
        setState(() => _helpfulVoted.remove(c.id));
        _snack(_errorText(e, 'Could not mark as helpful.'));
      }
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: PixelPalette.ink,
        content: Text(
          text,
          style: const TextStyle(color: PixelPalette.paper),
        ),
      ),
    );
  }

  Future<void> _openReport() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SpotReportSheet(
        spotName: widget.spotName,
        onSubmit: (reason, details) async {
          await _dio.post('/spots/${widget.spotId}/reports', data: {
            'reason': reason,
            if (details.isNotEmpty) 'details': details,
          });
        },
      ),
    );
    if (sent == true && mounted) {
      _snack('Thanks. Our moderators will check this destination.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return TheaterPanel(
      child: Column(
        key: const ValueKey('spot_community'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Text(
            'NOTES',
            style: PixelType.title(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Tips and updates from people who visited.',
            style: PixelType.body(context, color: PixelPalette.mist),
          ),
          SizedBox(height: grid.px(2)),

          // Top Action Buttons: Like & Report Problem
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Semantics(
                button: true,
                label: _liked ? 'Liked spot' : 'Like spot',
                child: InkWell(
                  key: const ValueKey('spot_like'),
                  onTap: _toggleLike,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    alignment: Alignment.center,
                    child: PixelPanel(
                      style: _liked
                          ? PixelBoxStyle.red.copyWith(corner: 0, shadowPx: 0)
                          : PixelBoxStyle.inkDialogue.copyWith(
                              fill: PixelPalette.ink,
                              outline: PixelPalette.paper,
                              corner: 0,
                              shadowPx: 0,
                            ),
                      padding: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: grid.px(3),
                          vertical: grid.px(1),
                        ),
                        child: Text(
                          _liked ? '♥ LIKED' : '♡ LIKE',
                          style: PixelType.small(
                            context,
                            color: _liked ? PixelPalette.white : PixelPalette.paper,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Report a problem',
                child: InkWell(
                  key: const ValueKey('spot_report'),
                  onTap: _openReport,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    alignment: Alignment.center,
                    child: PixelPanel(
                      style: PixelBoxStyle.inkDialogue.copyWith(
                        fill: PixelPalette.ink,
                        outline: PixelPalette.paper,
                        corner: 0,
                        shadowPx: 0,
                      ),
                      padding: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: grid.px(3),
                          vertical: grid.px(1),
                        ),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '⚑ REPORT A PROBLEM',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.paper,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: grid.px(3)),

          // Note Composer
          _buildComposer(grid),

          SizedBox(height: grid.px(3)),

          // Notes List / State
          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: PixelPalette.sun),
              ),
            )
          else if (_loadError != null)
            Row(
              children: [
                Expanded(
                  child: Text(
                    _loadError!,
                    style: PixelType.small(context, color: PixelPalette.red),
                  ),
                ),
                PixelButton(
                  label: 'RETRY',
                  variant: PixelButtonVariant.ghost,
                  onPressed: _load,
                ),
              ],
            )
          else if (_comments.isEmpty)
            Text(
              'No notes yet. Be the first to share a tip.',
              style: PixelType.small(context, color: PixelPalette.stone),
            )
          else
            for (final c in _comments) ...[
              _buildCommentItem(c, grid),
              if (c != _comments.last) SizedBox(height: grid.px(2)),
            ],
        ],
      ),
    );
  }

  Widget _buildComposer(PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.inkDialogue.copyWith(
        fill: PixelPalette.ink,
        outline: PixelPalette.paper,
        corner: 0,
        shadowPx: 0,
      ),
      padding: 1,
      child: Padding(
        padding: EdgeInsets.all(grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('spot_comment_input'),
              controller: _composer,
              minLines: 2,
              maxLines: 4,
              maxLength: 1000,
              style: PixelType.body(context, color: PixelPalette.paper),
              decoration: InputDecoration(
                hintText: 'Share a tip for other explorers…',
                hintStyle: PixelType.body(context, color: PixelPalette.stone),
                border: InputBorder.none,
                counterText: '',
              ),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1),
              runSpacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                DropdownButton<String>(
                  key: const ValueKey('spot_comment_tag'),
                  value: _tag,
                  dropdownColor: PixelPalette.ink,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final e in spotCommentTags.entries)
                      DropdownMenuItem(
                        value: e.key,
                        child: Text(
                          e.value.toUpperCase(),
                          style: PixelType.small(
                            context,
                            color: PixelPalette.paper,
                          ),
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => _tag = v ?? 'general'),
                ),
                PixelButton(
                  key: const ValueKey('spot_comment_post'),
                  label: _posting ? 'POSTING…' : 'POST NOTE',
                  variant: PixelButtonVariant.primary,
                  onPressed: _posting ? null : _post,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentItem(SpotComment c, PixelGrid grid) {
    final voted = _helpfulVoted.contains(c.id);

    return PixelPanel(
      style: PixelBoxStyle.inkDialogue.copyWith(
        fill: PixelPalette.ink,
        outline: PixelPalette.slate,
        corner: 0,
        shadowPx: 0,
      ),
      padding: 1,
      child: Padding(
        padding: EdgeInsets.all(grid.px(2)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: grid.px(1),
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  c.authorName.toUpperCase(),
                  style: PixelType.small(context, color: PixelPalette.paper),
                ),
                if (c.verifiedVisit)
                  const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: PixelChip(
                      'VERIFIED VISIT',
                      style: PixelBoxStyle.green,
                      textColor: PixelPalette.white,
                    ),
                  ),
                Text(
                  '${spotCommentTags[c.tag]?.toUpperCase() ?? 'GENERAL'} · ${_relative(c.createdAt).toUpperCase()}',
                  style: PixelType.small(context, color: PixelPalette.mist),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(
              c.content,
              style: PixelType.body(context, color: PixelPalette.paperDim),
            ),
            SizedBox(height: grid.px(1)),
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Mark note helpful (${c.helpfulCount})',
                child: InkWell(
                  onTap: voted ? null : () => _markHelpful(c),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                    alignment: Alignment.center,
                    child: PixelPanel(
                      style: voted
                          ? PixelBoxStyle.gold.copyWith(corner: 0, shadowPx: 0)
                          : PixelBoxStyle.inkDialogue.copyWith(
                              fill: PixelPalette.slate,
                              outline: PixelPalette.mist,
                              corner: 0,
                              shadowPx: 0,
                            ),
                      padding: 1,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: grid.px(2),
                          vertical: grid.px(1),
                        ),
                        child: Text(
                          '👍 HELPFUL (${c.helpfulCount})',
                          style: PixelType.small(
                            context,
                            color: voted ? PixelPalette.ink : PixelPalette.paper,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet to report a problem with a destination. Pops `true` on send.
class SpotReportSheet extends StatefulWidget {
  final String spotName;
  final Future<void> Function(String reason, String details) onSubmit;

  const SpotReportSheet({
    super.key,
    required this.spotName,
    required this.onSubmit,
  });

  @override
  State<SpotReportSheet> createState() => _SpotReportSheetState();
}

class _SpotReportSheetState extends State<SpotReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final reason = _reason;
    if (reason == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.onSubmit(reason, _details.text.trim());
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = _errorText(e, 'The report was not sent. Try again.');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);

    return Material(
      color: PixelPalette.ink,
      child: Padding(
        padding: EdgeInsets.only(
          left: grid.px(3),
          right: grid.px(3),
          top: grid.px(3),
          bottom: MediaQuery.viewInsetsOf(context).bottom + grid.px(3),
        ),
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'REPORT A PROBLEM',
                      style: PixelType.title(context, color: PixelPalette.paper),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.of(context).pop(false),
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                    alignment: Alignment.center,
                    child: Text(
                      '✕',
                      style: PixelType.title(context, color: PixelPalette.paper),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: grid.px(1)),
            Text(
              widget.spotName.toUpperCase(),
              style: PixelType.small(context, color: PixelPalette.mist),
            ),
            SizedBox(height: grid.px(2)),
            Column(
              children: [
                for (final e in spotReportReasons.entries)
                  RadioListTile<String>(
                    key: ValueKey('report_${e.key}'),
                    value: e.key,
                    groupValue: _reason,
                    activeColor: PixelPalette.sun,
                    onChanged: (v) => setState(() => _reason = v),
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      e.value,
                      style: PixelType.small(context, color: PixelPalette.paper),
                    ),
                  ),
              ],
            ),
            SizedBox(height: grid.px(2)),
            PixelPanel(
              style: PixelBoxStyle.inkDialogue.copyWith(
                fill: PixelPalette.ink,
                outline: PixelPalette.slate,
                corner: 0,
                shadowPx: 0,
              ),
              padding: 1,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: grid.px(2)),
                child: TextField(
                  controller: _details,
                  maxLength: 500,
                  maxLines: 3,
                  style: PixelType.body(context, color: PixelPalette.paper),
                  decoration: InputDecoration(
                    labelText: 'DETAILS (OPTIONAL)',
                    labelStyle: PixelType.small(context, color: PixelPalette.mist),
                    border: InputBorder.none,
                    counterStyle: PixelType.small(context, color: PixelPalette.stone),
                  ),
                ),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                _error!,
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const ValueKey('report_send'),
              label: _sending ? 'SENDING…' : 'SEND REPORT',
              variant: PixelButtonVariant.primary,
              onPressed: _reason == null || _sending ? null : _send,
            ),
          ],
        ),
      ),
    ),
  );
  }
}
