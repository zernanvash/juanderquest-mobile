import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/cultural_quiz_model.dart';
import '../providers/cultural_quiz_provider.dart';

class CulturalQuizDetailScreen extends ConsumerStatefulWidget {
  final String quizId;

  const CulturalQuizDetailScreen({
    super.key,
    required this.quizId,
  });

  @override
  ConsumerState<CulturalQuizDetailScreen> createState() =>
      _CulturalQuizDetailScreenState();
}

class _CulturalQuizDetailScreenState
    extends ConsumerState<CulturalQuizDetailScreen> {
  bool _isStarting = false;
  String? _errorMessage;

  Future<void> _startAttempt(CulturalQuizModel quiz) async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      showPixelToast(context, 'Please sign in to take cultural quizzes.');
      context.push('/login');
      return;
    }

    setState(() {
      _isStarting = true;
      _errorMessage = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw Exception('Location services are disabled on your device.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception(
              'Location permission is required to start a location-triggered quiz.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception(
            'Location permissions are permanently denied. Please enable them in system settings.');
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final session =
          await ref.read(culturalQuizControllerProvider.notifier).startAttempt(
                quizId: quiz.id,
                lat: position.latitude,
                lng: position.longitude,
              );

      if (!mounted) return;

      context.push(
        '/cultural-quizzes/${quiz.id}/play',
        extra: session,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          _isStarting = false;
        });
      }
    }
  }

  void _reload() => ref.invalidate(culturalQuizDetailProvider(widget.quizId));

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(culturalQuizDetailProvider(widget.quizId));
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
                    title: 'Cultural Quiz',
                    onBack: canPop
                        ? () => Navigator.of(context).maybePop()
                        : null,
                  ),
                  Expanded(
                    child: quizAsync.when(
                      loading: () =>
                          const Center(child: PixelLoader(label: 'Loading quiz')),
                      error: (err, _) => _error(context, grid, 'Failed to load quiz: $err'),
                      data: (quiz) {
                        if (quiz == null) {
                          return _error(context, grid, 'Cultural Quiz not found.');
                        }
                        return _quiz(context, grid, quiz);
                      },
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

  Widget _error(BuildContext context, PixelGrid grid, String message) {
    return ListView(
      padding: EdgeInsets.all(grid.px(4)),
      children: [
        PixelPanel(
          style: PixelBoxStyle.red,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: PixelType.body(context, color: PixelPalette.white),
              ),
              SizedBox(height: grid.px(3)),
              Align(
                alignment: Alignment.centerRight,
                child: PixelButton(
                  key: const ValueKey('quiz_detail_retry'),
                  label: 'Retry',
                  onPressed: _reload,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _quiz(BuildContext context, PixelGrid grid, CulturalQuizModel quiz) {
    final isCooldownActive = quiz.cooldownUntil != null;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        grid.px(4),
        grid.px(3),
        grid.px(4),
        grid.px(8) + MediaQuery.paddingOf(context).bottom,
      ),
      children: [
        PixelPanel(
          style: PixelBoxStyle.wood,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${quiz.destinationName} · ${quiz.municipality}',
                style: PixelType.small(context, color: PixelPalette.sun),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                quiz.title,
                style: PixelType.title(context, color: PixelPalette.paper),
              ),
              SizedBox(height: grid.px(1)),
              Text(
                quiz.description,
                style: PixelType.body(context, color: PixelPalette.cream),
              ),
            ],
          ),
        ),
        SizedBox(height: grid.px(3)),
        PixelPanel(
          style: PixelBoxStyle.parchment,
          child: Column(
            children: [
              _param(
                context,
                grid,
                'Reward',
                quiz.isCompleted
                    ? 'Learning Only (XP already earned)'
                    : '+${quiz.xpReward} Explorer XP',
              ),
              _divider(grid),
              _param(context, grid, 'Questions',
                  '5 multiple-choice (4/5 to pass)'),
              _divider(grid),
              _param(context, grid, 'Time Limit',
                  '${quiz.timeLimitMinutes} minutes to submit'),
              _divider(grid),
              _param(context, grid, 'Start Location',
                  'Within ${quiz.radiusMeters}m of destination'),
            ],
          ),
        ),
        if (_errorMessage != null) ...[
          SizedBox(height: grid.px(3)),
          PixelPanel(
            style: PixelBoxStyle.red,
            child: Text(
              _errorMessage!,
              style: PixelType.body(context, color: PixelPalette.white),
            ),
          ),
        ],
        SizedBox(height: grid.px(3)),
        if (isCooldownActive)
          PixelPanel(
            style: PixelBoxStyle.gold,
            child: Text(
              'Retry cooldown active until:\n${quiz.cooldownUntil}',
              style: PixelType.body(context),
            ),
          )
        else
          PixelButton(
            key: const ValueKey('quiz_start'),
            label: _isStarting ? 'Verifying location' : 'Start Quiz',
            expand: true,
            loading: _isStarting,
            onPressed: _isStarting ? null : () => _startAttempt(quiz),
          ),
        SizedBox(height: grid.px(2)),
        Text(
          'Note: You must be physically within ${quiz.radiusMeters}m to start. You may freely move outside the radius while completing the quiz before the timer expires.',
          textAlign: TextAlign.center,
          style: PixelType.body(context, color: PixelPalette.slate),
        ),
      ],
    );
  }

  Widget _divider(PixelGrid grid) => SizedBox(height: grid.px(2));

  Widget _param(
    BuildContext context,
    PixelGrid grid,
    String title,
    String value,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: grid.px(26),
          child: Text(title, style: PixelType.body(context)),
        ),
        SizedBox(width: grid.px(2)),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
        ),
      ],
    );
  }
}
