import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../auth/providers/auth_provider.dart';

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

/// Likes, comments ("field logs") and problem reports for a destination —
/// the community section the web destination page has (Plan 47 B3).
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
        _loadError = 'Comments could not load.';
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
      if (mounted) _snack(_errorText(e, 'Your comment was not posted.'));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openReport() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
    return Column(
      key: const ValueKey('spot_community'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              key: const ValueKey('spot_like'),
              selected: _liked,
              onSelected: (_) => _toggleLike(),
              avatar: Icon(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                size: 18,
                color: _liked ? AppColors.danger : AppColors.textSecondary,
              ),
              showCheckmark: false,
              label: Text(_liked ? 'Liked' : 'Like'),
            ),
            ActionChip(
              key: const ValueKey('spot_report'),
              onPressed: _openReport,
              avatar: const Icon(Icons.flag_outlined, size: 18),
              label: const Text('Report a problem'),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Explorer notes',
          style: AppTypography.headlineSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Tips and updates from people who visited.',
          style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        _buildComposer(),
        const SizedBox(height: AppSpacing.md),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_loadError != null)
          Row(
            children: [
              Expanded(child: Text(_loadError!)),
              TextButton(onPressed: _load, child: const Text('Retry')),
            ],
          )
        else if (_comments.isEmpty)
          Text(
            'No notes yet. Be the first to share a tip.',
            style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
          )
        else
          for (final c in _comments) _buildComment(c),
      ],
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('spot_comment_input'),
            controller: _composer,
            minLines: 1,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(
              hintText: 'Share a tip for other explorers…',
              border: InputBorder.none,
              counterText: '',
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              DropdownButton<String>(
                key: const ValueKey('spot_comment_tag'),
                value: _tag,
                underline: const SizedBox.shrink(),
                items: [
                  for (final e in spotCommentTags.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _tag = v ?? 'general'),
              ),
              FilledButton(
                key: const ValueKey('spot_comment_post'),
                onPressed: _posting ? null : _post,
                child: Text(_posting ? 'Posting…' : 'Post'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildComment(SpotComment c) {
    final voted = _helpfulVoted.contains(c.id);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(color: AppColors.borderLowContrast),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(c.authorName,
                  style: AppTypography.labelLarge
                      .copyWith(fontWeight: FontWeight.bold)),
              if (c.verifiedVisit)
                const Icon(Icons.verified_rounded,
                    size: 16, color: AppColors.success),
              Text(
                '${spotCommentTags[c.tag] ?? 'General'} · ${_relative(c.createdAt)}',
                style:
                    AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(c.content, style: AppTypography.bodyMedium),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: voted ? null : () => _markHelpful(c),
              icon: Icon(
                voted ? Icons.thumb_up_alt_rounded : Icons.thumb_up_alt_outlined,
                size: 16,
              ),
              label: Text('Helpful (${c.helpfulCount})'),
            ),
          ),
        ],
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
    return Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.gutter,
        right: AppSpacing.gutter,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report a problem',
                style: AppTypography.headlineSmall
                    .copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.spotName,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in spotReportReasons.entries)
                    RadioListTile<String>(
                      key: ValueKey('report_${e.key}'),
                      value: e.key,
                      contentPadding: EdgeInsets.zero,
                      title: Text(e.value),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              key: const ValueKey('report_send'),
              onPressed: _reason == null || _sending ? null : _send,
              child: Text(_sending ? 'Sending…' : 'Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
