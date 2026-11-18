import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/l10n/app_language.dart';
import '../auth/providers/auth_provider.dart';
import '../../core/pixel/generated/pixel_palette.g.dart';
import '../../core/pixel/pixel_box.dart';
import '../../core/pixel/pixel_controls.dart';
import '../../core/pixel/pixel_feedback.dart';
import '../../core/pixel/pixel_grid.dart';
import '../../core/pixel/pixel_input.dart';
import '../../core/pixel/pixel_text.dart';
import '../../core/theme/app_theme.dart';
import '../cosmetics/widgets/cosmetic_avatar.dart';

class PlazaComment {
  const PlazaComment({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorHandle,
    this.authorAvatar,
    required this.body,
    this.canDelete = false,
    this.canReport = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorHandle;
  final String? authorAvatar;
  final String body;
  final bool canDelete;
  final bool canReport;

  factory PlazaComment.fromJson(Map<String, dynamic> json) {
    final author = json['author'] is Map
        ? Map<String, dynamic>.from(json['author'] as Map)
        : const <String, dynamic>{};
    return PlazaComment(
      id: '${json['id'] ?? ''}',
      authorId: '${author['user_id'] ?? ''}',
      authorName: author['display_name'] as String? ?? 'Explorer',
      authorHandle: author['handle'] as String?,
      authorAvatar: author['avatar_url'] as String?,
      body: json['body'] as String? ?? '',
      canDelete: json['can_delete'] == true,
      canReport: json['can_report'] == true,
    );
  }
}

/// Owner 2026-11-18 (Plaza "Comments back"). Calls [onCountChanged] with the
/// new number of comments after an add or delete.
Future<void> showPlazaComments(
  BuildContext context, {
  required String activityId,
  required ValueChanged<int> onCountChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Theme(
      data: AppTheme.pixel,
      child: _CommentsSheet(
          activityId: activityId, onCountChanged: onCountChanged),
    ),
  );
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet(
      {required this.activityId, required this.onCountChanged});

  final String activityId;
  final ValueChanged<int> onCountChanged;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  List<PlazaComment>? _comments;
  String? _error;
  bool _sending = false;

  Dio get _dio => ref.read(apiClientProvider).dio;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await _dio.get(
          '/plaza/activities/${widget.activityId}/comments',
          queryParameters: {'limit': 50});
      final items = (res.data?['data']?['items'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => PlazaComment.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (mounted) setState(() => _comments = items);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load comments.');
      }
    }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final res = await _dio.post(
        '/plaza/activities/${widget.activityId}/comments',
        data: {'body': body, 'idempotency_key': const Uuid().v4()},
      );
      final data = res.data?['data'];
      if (data is Map) {
        final comment = PlazaComment.fromJson(Map<String, dynamic>.from(data));
        _input.clear();
        setState(() => _comments = [...?_comments, comment]);
        widget.onCountChanged(_comments!.length);
      }
    } on DioException catch (e) {
      if (mounted) {
        final message = e.response?.data is Map
            ? (e.response!.data['error']?['message'] as String?)
            : null;
        showPixelToast(context, message ?? 'Could not post your comment.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _delete(PlazaComment comment) async {
    try {
      await _dio.delete('/plaza/comments/${comment.id}');
      setState(() =>
          _comments = _comments?.where((c) => c.id != comment.id).toList());
      widget.onCountChanged(_comments?.length ?? 0);
    } catch (_) {
      if (mounted) showPixelToast(context, 'Could not delete the comment.');
    }
  }

  Future<void> _report(PlazaComment comment) async {
    try {
      await _dio.post('/plaza/comments/${comment.id}/report',
          data: {'reason': 'other'});
      if (mounted) {
        showPixelToast(
            context,
            tr(context,
                en: 'Thanks. A moderator will review it.',
                tl: 'Salamat. Susuriin ito ng moderator.'));
      }
    } catch (_) {
      if (mounted) showPixelToast(context, 'Could not send the report.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    final comments = _comments;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
        child: PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr(context, en: 'Comments', tl: 'Mga komento'),
                  style:
                      PixelType.title(context, color: PixelPalette.woodDeep)),
              SizedBox(height: grid.px(2)),
              Flexible(
                child: _error != null
                    ? Text(_error!,
                        style: PixelType.body(context, color: PixelPalette.red))
                    : comments == null
                        ? const Center(child: PixelLoader(label: 'Loading'))
                        : comments.isEmpty
                            ? Text(
                                tr(context,
                                    en: 'No comments yet. Say something nice!',
                                    tl: 'Wala pang komento.'),
                                key: const ValueKey('plaza_comments_empty'),
                                style: PixelType.body(context,
                                    color: PixelPalette.slate),
                              )
                            : ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final c in comments) _row(context, c),
                                ],
                              ),
              ),
              SizedBox(height: grid.px(2)),
              Row(
                children: [
                  Expanded(
                    child: PixelTextField(
                      key: const ValueKey('plaza_comment_input'),
                      controller: _input,
                      hint: tr(context,
                          en: 'Add a comment', tl: 'Magdagdag ng komento'),
                      textInputAction: TextInputAction.send,
                    ),
                  ),
                  SizedBox(width: grid.px(2)),
                  PixelButton(
                    key: const ValueKey('plaza_comment_send'),
                    label: tr(context, en: 'Send', tl: 'Ipadala'),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, PlazaComment c) {
    final grid = PixelGrid.of(context);
    return Padding(
      key: ValueKey('plaza_comment_${c.id}'),
      padding: EdgeInsets.symmetric(vertical: grid.px(1)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: c.authorId.isEmpty
                ? null
                : () => context.push(
                    '/profile/${Uri.encodeComponent(c.authorHandle ?? c.authorId)}'),
            child: CosmeticAvatar(
                name: c.authorName,
                imageUrl: c.authorAvatar,
                size: grid.px(10)),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.authorName,
                    style: PixelType.small(context, color: PixelPalette.ink)),
                Text(c.body,
                    style: PixelType.body(context, color: PixelPalette.wood)),
              ],
            ),
          ),
          if (c.canDelete)
            PixelChip(
              tr(context, en: 'Delete', tl: 'Burahin'),
              style: PixelBoxStyle.parchment,
              textColor: PixelPalette.red,
              onTap: () => _delete(c),
            )
          else if (c.canReport)
            PixelChip(
              tr(context, en: 'Report', tl: 'I-report'),
              style: PixelBoxStyle.parchment,
              textColor: PixelPalette.slate,
              onTap: () => _report(c),
            ),
        ],
      ),
    );
  }
}
