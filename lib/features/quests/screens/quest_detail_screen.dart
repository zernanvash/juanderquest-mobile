import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_art.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import '../../celebrations/celebration.dart';
import '../models/quest_model.dart';
import '../pixel/checkpoint_map_preview.dart';
import '../pixel/pixel_tag.dart';
import '../pixel/saved_quest_heart.dart';
import '../pixel/saved_quests.dart';
import '../pixel/task_icons.dart';
import 'qr_scan_screen.dart';
import 'quest_pass_host.dart';

class QuestDetailScreen extends ConsumerWidget {
  final QuestModel? quest;
  final String? questId;

  const QuestDetailScreen({super.key, this.quest, this.questId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (quest != null) return _DetailContent(quest: quest!);
    if (questId == null) return const _NotFound();
    return _QuestDetailById(questId: questId!);
  }
}

class _QuestDetailById extends ConsumerStatefulWidget {
  final String questId;
  const _QuestDetailById({required this.questId});

  @override
  ConsumerState<_QuestDetailById> createState() => _QuestDetailByIdState();
}

class _QuestDetailByIdState extends ConsumerState<_QuestDetailById> {
  Future<QuestModel?>? _fetchFuture;

  @override
  void initState() {
    super.initState();
    _fetchFuture = _fetchQuest();
  }

  Future<QuestModel?> _fetchQuest() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.dio.get('/quests/${widget.questId}');
      if (response.statusCode == 200 && response.data['success'] == true) {
        return QuestModel.fromJson(response.data['data']);
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<QuestModel?>(
      future: _fetchFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const JdqScaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }
        if (snapshot.data == null) return const _NotFound();
        return _DetailContent(quest: snapshot.data!);
      },
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) {
    return JdqScaffold(
      appBar: AppBar(
        title: const Text('Quest Not Found'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.explore_off_rounded,
                size: 64, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Quest Not Found',
              style: AppTypography.headlineSmall
                  .copyWith(color: AppColors.woodBrown),
            ),
            const SizedBox(height: 6),
            Text(
              'This quest details could not be retrieved.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: 160,
              child: SecondaryButton(
                label: 'Back',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailContent extends ConsumerStatefulWidget {
  final QuestModel quest;
  const _DetailContent({required this.quest});

  @override
  ConsumerState<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends ConsumerState<_DetailContent> {
  QuestAttemptModel? _attempt;
  bool _completed = false;
  bool _loading = false;
  bool _stepSubmitting = false;
  String? _error;

  String _messageFromDio(DioException error, String fallback) {
    final body = error.response?.data;
    if (body is Map && body['error'] is Map) {
      final message = (body['error'] as Map)['message'];
      if (message is String && message.isNotEmpty) return message;
    }
    return fallback;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadProgress);
  }

  Future<void> _loadProgress() async {
    if (!ref.read(authProvider).isAuthenticated) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .get('/quests/${widget.quest.id}/progress');
      final data = response.data['data'];
      if (response.data['success'] != true || data is! Map) {
        throw StateError('Quest progress is unavailable.');
      }
      if (!mounted) return;
      setState(() {
        _completed = data['has_completed'] == true;
        final rawAttempt = data['active_attempt'];
        if (rawAttempt is Map<String, dynamic>) {
          _attempt = QuestAttemptModel.fromJson(rawAttempt);
        } else if (rawAttempt is Map) {
          _attempt =
              QuestAttemptModel.fromJson(Map<String, dynamic>.from(rawAttempt));
        } else {
          _attempt = null;
        }
      });
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFromDio(
            error, 'Could not load quest progress. Retry when connected.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load quest progress. Retry when connected.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _acceptQuest() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref
          .read(apiClientProvider)
          .dio
          .post('/quests/${widget.quest.id}/attempts');
      if (response.data['success'] != true) {
        throw StateError('Quest enrollment was not confirmed.');
      }
      if (!mounted) return;
      await _loadProgress();
    } on DioException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = _messageFromDio(
            error, 'Could not accept this quest. Please retry.');
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not accept this quest. Please retry.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<Position?> _safeGetPosition() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        final requested = await Geolocator.requestPermission();
        if (requested == LocationPermission.denied ||
            requested == LocationPermission.deniedForever) {
          return null;
        }
      }
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 12),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _verifyLocation(QuestStepModel step) async {
    setState(() => _stepSubmitting = true);
    try {
      final pos = await _safeGetPosition();
      if (pos == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(_noGpsMessage)),
          );
        }
        return;
      }
      final res = await ref.read(apiClientProvider).dio.post(
        '/quests/${widget.quest.id}/steps/${step.order}/evidence',
        data: {
          'idempotency_key': const Uuid().v4(),
          'checkpoint_type': 'location',
          'captured_lat': pos.latitude,
          'captured_lng': pos.longitude,
          'captured_accuracy': pos.accuracy,
        },
      );
      if (res.data['success'] == true) {
        await _loadProgress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Location verified successfully!')),
          );
        }
      }
    } on DioException catch (dioErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _messageFromDio(dioErr, 'Location verification failed.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not verify location. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _stepSubmitting = false);
    }
  }

  void _showQrVerificationModal(QuestStepModel step) {
    final textController = TextEditingController();
    String? modalError;
    bool modalLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> verify(StateSetter setModalState) async {
              final code = textController.text.trim();
              if (code.isEmpty) {
                setModalState(() => modalError = 'Please enter a marker code.');
                return;
              }
              setModalState(() {
                modalLoading = true;
                modalError = null;
              });
              try {
                final pos = await _safeGetPosition();
                if (pos == null) {
                  setModalState(() => modalError = _noGpsMessage);
                  return;
                }
                final res = await ref.read(apiClientProvider).dio.post(
                  '/quests/${widget.quest.id}/steps/${step.order}/evidence',
                  data: {
                    'idempotency_key': const Uuid().v4(),
                    'checkpoint_type': 'qr',
                    'qr_code': code,
                    'captured_lat': pos.latitude,
                    'captured_lng': pos.longitude,
                    'captured_accuracy': pos.accuracy,
                  },
                );
                if (res.data['success'] == true) {
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadProgress();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('QR code verified successfully!')),
                    );
                  }
                } else {
                  setModalState(() => modalError = 'QR verification failed.');
                }
              } on DioException catch (dioErr) {
                setModalState(() => modalError = _messageFromDio(
                    dioErr, 'Invalid QR code or out of radius.'));
              } catch (_) {
                setModalState(
                    () => modalError = 'Verification failed. Try again.');
              } finally {
                setModalState(() => modalLoading = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.gutter,
                right: AppSpacing.gutter,
                top: AppSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.qr_code_scanner_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Scan Checkpoint QR',
                            style: AppTypography.headlineSmall
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Scan the physical destination QR code or enter the code below.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      key: const ValueKey('qr_scan_camera'),
                      label: 'Scan with camera',
                      icon: Icons.qr_code_scanner_rounded,
                      onPressed: modalLoading
                          ? null
                          : () async {
                              final code = await Navigator.of(ctx).push<String>(
                                MaterialPageRoute(
                                  builder: (_) => const QrScanScreen(),
                                ),
                              );
                              if (code == null) return;
                              textController.text = code;
                              await verify(setModalState);
                            },
                    ),
                    const SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: textController,
                      decoration: const InputDecoration(
                        labelText: 'Marker Code',
                        hintText: 'e.g. BOLINAO_LIGHTHOUSE_QR_2026',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.qr_code_rounded),
                      ),
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 8),
                      Text(modalError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: modalLoading ? 'Verifying...' : 'Verify QR',
                      icon: Icons.check_circle_outline_rounded,
                      onPressed:
                          modalLoading ? null : () => verify(setModalState),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showPhotoVerificationModal(QuestStepModel step) {
    XFile? pickedFile;
    bool galleryOptIn = false;
    String? modalError;
    bool modalLoading = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: AppSpacing.gutter,
                right: AppSpacing.gutter,
                top: AppSpacing.lg,
                bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.camera_alt_rounded,
                            color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Submit Photo Proof',
                            style: AppTypography.headlineSmall
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Capture or upload a photo fulfilling the objective.',
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                    source: ImageSource.camera,
                                    maxWidth: 1920,
                                    maxHeight: 1080);
                                if (file != null) {
                                  setModalState(() => pickedFile = file);
                                }
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.camera_rounded),
                            label: const Text('Camera'),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              try {
                                final picker = ImagePicker();
                                final file = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 1920,
                                    maxHeight: 1080);
                                if (file != null) {
                                  setModalState(() => pickedFile = file);
                                }
                              } catch (_) {}
                            },
                            icon: const Icon(Icons.photo_library_rounded),
                            label: const Text('Gallery'),
                          ),
                        ),
                      ],
                    ),
                    if (pickedFile != null) ...[
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.image_rounded,
                                size: 20, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                pickedFile!.name,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.check_circle_rounded,
                                size: 18, color: AppColors.success),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    CheckboxListTile(
                      value: galleryOptIn,
                      onChanged: (val) =>
                          setModalState(() => galleryOptIn = val ?? false),
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: const Text(
                        'Feature photo in destination gallery upon review approval',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Photos remain private evidence for moderation unless checked.',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.textSecondary),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (modalError != null) ...[
                      const SizedBox(height: 6),
                      Text(modalError!,
                          style: const TextStyle(
                              color: AppColors.danger, fontSize: 12)),
                    ],
                    const SizedBox(height: AppSpacing.md),
                    PrimaryButton(
                      label: modalLoading
                          ? 'Uploading Proof...'
                          : 'Submit Photo Proof',
                      icon: Icons.upload_rounded,
                      onPressed: (pickedFile == null || modalLoading)
                          ? null
                          : () async {
                              setModalState(() {
                                modalLoading = true;
                                modalError = null;
                              });
                              try {
                                final bytes = await pickedFile!.readAsBytes();
                                final pos = await _safeGetPosition();
                                final formData = FormData.fromMap({
                                  'idempotency_key': const Uuid().v4(),
                                  'checkpoint_type': 'photo',
                                  'gallery_opt_in': galleryOptIn.toString(),
                                  if (pos != null) ...{
                                    'captured_lat': pos.latitude,
                                    'captured_lng': pos.longitude,
                                    'captured_accuracy': pos.accuracy,
                                  },
                                  'photo': MultipartFile.fromBytes(bytes,
                                      filename: pickedFile!.name),
                                });
                                final res =
                                    await ref.read(apiClientProvider).dio.post(
                                          '/quests/${widget.quest.id}/steps/${step.order}/evidence',
                                          data: formData,
                                        );
                                if (res.data['success'] == true) {
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  await _loadProgress();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Photo proof submitted for independent review!')),
                                    );
                                  }
                                } else {
                                  setModalState(() =>
                                      modalError = 'Photo submission failed.');
                                }
                              } on DioException catch (dioErr) {
                                setModalState(() => modalError =
                                    _messageFromDio(
                                        dioErr, 'Photo upload failed.'));
                              } catch (_) {
                                setModalState(() => modalError =
                                    'Photo upload failed. Try again.');
                              } finally {
                                setModalState(() => modalLoading = false);
                              }
                            },
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Finishes the quest: official quests whose tasks were all checked by the server pay at once;
  /// everything else goes to review (the server decides).
  Future<void> _finishQuest() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post('/quests/${widget.quest.id}/complete');
      if (res.data['success'] == true) {
        final data = res.data['data'];
        final awarded = data is Map && data['reward_awarded'] == true;
        final points = data is Map && data['awarded_points'] is num
            ? (data['awarded_points'] as num).toInt()
            : 0;
        // Celebrate only a paid reward; a quest sent to review gets just the dialog.
        if (awarded && mounted) {
          await showCelebration(
            context,
            QuestComplete(questTitle: widget.quest.title, reward: points),
          );
        }
        if (!mounted) return;
        await _loadProgress();
        if (mounted) {
          await showQuestFinishedDialog(context,
              rewardAwarded: awarded, awardedPoints: points);
        }
      }
    } on DioException catch (dioErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  _messageFromDio(dioErr, 'Could not finish this quest.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not finish this quest. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Host-scan QR task: show the traveler's one-use pass until the host verifies it.
  Future<void> _showQuestPass(QuestStepModel step) async {
    final verified = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuestPassSheet(questId: widget.quest.id, step: step),
    );
    if (!mounted) return;
    await _loadProgress();
    if (verified == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The host verified your pass!')),
      );
    }
  }

  bool get _isQuestHost {
    final user = ref.read(authProvider).user;
    if (user == null) return false;
    return user.role == 'admin' ||
        user.role == 'qa' ||
        (widget.quest.authorId != null && widget.quest.authorId == user.id);
  }

  static const _noGpsMessage =
      'We need a fresh GPS reading. Turn on location, step outside if you can, and try again.';

  Future<void> _launchAR(QuestStepModel step) async {
    final completed = await context.push<bool>(
      '/quests/${widget.quest.id}/ar?step=${step.order}',
      extra: widget.quest,
    );
    if (!mounted) return;
    await _loadProgress();
    if (completed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AR task verified!')),
      );
    }
  }

  /// In-app task (Plan 43 `action`): the server checks the traveler really
  /// did it (quiz finished, destination saved/liked, JuanChoice vote).
  Future<void> _checkInAppTask(QuestStepModel step) async {
    setState(() => _stepSubmitting = true);
    try {
      final task = step.verification?['task'];
      final res = await ref.read(apiClientProvider).dio.post(
        '/quests/${widget.quest.id}/steps/${step.order}/evidence',
        data: {
          'idempotency_key': const Uuid().v4(),
          if (task is Map && task['kind'] is String)
            'action_name': task['kind'],
        },
      );
      if (res.data['success'] == true) {
        await _loadProgress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Task complete!')),
          );
        }
      }
    } on DioException catch (dioErr) {
      if (!mounted) return;
      final route = inAppTaskRoute(step);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_messageFromDio(dioErr, 'This task is not done yet.')),
          action: route == null
              ? null
              : SnackBarAction(
                  label: 'Go',
                  onPressed: () => context.push(route),
                ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not check this task. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _stepSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final displaySteps = _attempt != null && _attempt!.steps.isNotEmpty
        ? _attempt!.steps
        : quest.steps;
    final saved = ref.watch(savedQuestsProvider).contains(quest.id);
    final user = ref.watch(authProvider).user;
    final isAuthor = user != null && quest.authorId == user.id;

    return Theme(
      data: AppTheme.pixel,
      child: Builder(
        builder: (context) {
          final grid = PixelGrid.of(context);
          return Scaffold(
            backgroundColor: PixelPalette.paper,
            body: DitherBackground(
              top: PixelPalette.paper,
              bottom: PixelPalette.parchment,
              child: SafeArea(
                bottom: false,
                child: Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.only(bottom: grid.px(3)),
                        children: [
                          _hero(context, grid, quest, saved),
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              grid.px(4),
                              grid.px(3),
                              grid.px(4),
                              grid.px(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _objectives(context, grid, quest),
                                SizedBox(height: grid.px(3)),
                                if (quest.funding != null) ...[
                                  _funded(context, grid, quest.funding!),
                                  SizedBox(height: grid.px(3)),
                                ],
                                if (quest.crowdStatus == 'estimated_busy') ...[
                                  _crowd(context, grid),
                                  SizedBox(height: grid.px(3)),
                                ],
                                _checkpoint(context, grid, quest),
                                SizedBox(height: grid.px(3)),
                                _tasks(context, grid, displaySteps),
                                SizedBox(height: grid.px(3)),
                                if (_isQuestHost) ...[
                                  _hostScan(context, grid),
                                  SizedBox(height: grid.px(3)),
                                ],
                                if (isAuthor) ...[
                                  _authorTools(context, grid),
                                  SizedBox(height: grid.px(3)),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _bottomBar(context, grid, displaySteps),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    PixelGrid grid,
    QuestModel quest,
    bool saved,
  ) {
    final hasImage = quest.imageUrl != null &&
        quest.imageUrl!.isNotEmpty &&
        (quest.imageUrl!.startsWith('http://') ||
            quest.imageUrl!.startsWith('https://'));
    final topInset = grid.px(2);
    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          Positioned.fill(
            child: hasImage
                ? Image.network(
                    quest.imageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _heroPlaceholder(context, quest),
                  )
                : _heroPlaceholder(context, quest),
          ),
          Positioned.fill(
            child: ColoredBox(
              color: PixelPalette.ink.withValues(alpha: 0.18),
            ),
          ),
          Positioned(
            top: topInset,
            left: grid.px(2),
            child: PixelIconButton(
              icon: _questBackIcon,
              semanticLabel: 'Back',
              iconHeight: 24,
              style: PixelBoxStyle.parchment,
              onPressed: () => context.pop(),
            ),
          ),
          Positioned(
            top: topInset,
            right: grid.px(2),
            child: SavedQuestHeart(
              saved: saved,
              questTitle: quest.title,
              onToggle: () =>
                  ref.read(savedQuestsProvider.notifier).toggle(quest.id),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              color: PixelPalette.ink.withValues(alpha: 0.78),
              padding: EdgeInsets.fromLTRB(
                grid.px(3),
                grid.px(2),
                grid.px(3),
                grid.px(2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PixelTag(
                    '${quest.categoryDisplay} · Eco-Quest',
                    style: PixelBoxStyle.gold,
                    textColor: PixelPalette.ink,
                    maxWidth: grid.px(140),
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    quest.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.title(context, color: PixelPalette.paper),
                  ),
                  SizedBox(height: grid.px(1)),
                  Text(
                    quest.locationName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: PixelType.small(
                      context,
                      color: PixelPalette.paperDim,
                    ),
                  ),
                  SizedBox(height: grid.px(2)),
                  PixelButton(
                    label: 'Directions',
                    style: PixelBoxStyle.wood,
                    textColor: PixelPalette.white,
                    onPressed: _openDirections,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// No photo: the dither pattern only. The title panel already shows the
  /// town, and a centred marker sat behind that panel.
  Widget _heroPlaceholder(BuildContext context, QuestModel quest) =>
      const DitherBackground(
        top: PixelPalette.woodDeep,
        bottom: PixelPalette.wood,
      );

  Widget _objectives(BuildContext context, PixelGrid grid, QuestModel quest) {
    final base = _baseReward(quest.baseRewardPhp);
    final difficulty = _difficulty(quest.difficultyFactor);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Mission objectives',
            style:
                PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(1)),
          PixelText.rich(
            quest.description,
            style: PixelType.body(context, color: PixelPalette.slate),
          ),
          if (quest.campaignId != null) ...[
            SizedBox(height: grid.px(2)),
            Align(
              alignment: Alignment.centerLeft,
              child: PixelTag(
                'Sponsored campaign · ${quest.remainingSlots ?? 'open'} slots',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
                maxWidth: grid.px(110),
              ),
            ),
          ],
          SizedBox(height: grid.px(3)),
          LayoutBuilder(
            builder: (context, constraints) {
              final gap = grid.px(2);
              final width = ((constraints.maxWidth - gap) / 2)
                  .clamp(1.0, 400.0)
                  .toDouble();
              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  _statSlot(
                    context,
                    grid,
                    width,
                    'Reward bounty',
                    '+${quest.rewardPoints} mJDQ',
                  ),
                  _statSlot(
                    context,
                    grid,
                    width,
                    'Base reward',
                    'P$base',
                    semantics: '$base pesos',
                  ),
                  _statSlot(
                    context,
                    grid,
                    width,
                    'GPS radius',
                    '${quest.radiusMeters}m',
                  ),
                  _statSlot(
                    context,
                    grid,
                    width,
                    'Difficulty',
                    '${difficulty}x',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _statSlot(
    BuildContext context,
    PixelGrid grid,
    double width,
    String label,
    String value, {
    String? semantics,
  }) {
    final text = Text(
      value,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: PixelType.title(
        context,
        color: label == 'Reward bounty' ? PixelPalette.gold : PixelPalette.ink,
      ),
    );
    return SizedBox(
      width: width,
      child: PixelPanel(
        style: PixelBoxStyle.slot,
        sunken: true,
        padding: 2,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: grid.px(16),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: semantics == null
                    ? text
                    : Semantics(label: semantics, child: text),
              ),
            ),
            SizedBox(height: grid.px(1)),
            Text(
              label,
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
        ),
      ),
    );
  }

  Widget _funded(
    BuildContext context,
    PixelGrid grid,
    QuestFundingSummary funding,
  ) {
    final sponsors = funding.sponsors
        .map((sponsor) => sponsor['name']?.toString())
        .whereType<String>()
        .join(', ');
    final perk = funding.perk;
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              Text(
                'Funded Eco-Quest',
                style: PixelType.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              PixelChip(
                '${funding.rewardPoints} pts each',
                style: PixelBoxStyle.gold,
                textColor: PixelPalette.ink,
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'About ${funding.completionsLeftEstimate} funded rewards left.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          if (funding.endsAt != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Round closes ${funding.endsAt!.toIso8601String().split('T').first}.',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
          if (sponsors.isNotEmpty) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Supported by $sponsors.',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
          if (perk != null) ...[
            SizedBox(height: grid.px(1)),
            Text(
              'Sponsor perk: ${perk['title'] ?? 'available'} · ${perk['remaining'] ?? 0} available',
              style: PixelType.small(context, color: PixelPalette.greenBright),
            ),
          ],
          SizedBox(height: grid.px(2)),
          Text(
            'Prototype reward points are simulated and have no cash or blockchain value.',
            style: PixelType.small(context, color: PixelPalette.stone),
          ),
        ],
      ),
    );
  }

  Widget _crowd(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'High tourist activity detected',
            style: PixelType.body(context, color: PixelPalette.white)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'This destination is currently experiencing high foot traffic. Explore quieter hidden gems in the Explore tab for bonus rewards!',
            style: PixelType.small(context, color: PixelPalette.paper),
          ),
          SizedBox(height: grid.px(2)),
          PixelButton(
            label: 'Explore quieter gems',
            style: PixelBoxStyle.parchment,
            textColor: PixelPalette.ink,
            onPressed: () => context.go('/explore'),
          ),
        ],
      ),
    );
  }

  Widget _checkpoint(BuildContext context, PixelGrid grid, QuestModel quest) {
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              Text(
                'Checkpoint map',
                style: PixelType.body(context)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
              _actionLink(
                context,
                'Full map',
                () => context.go('/map?quest=${quest.id}'),
              ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          CheckpointMapPreview(
            quest: quest,
            onTap: () => context.go('/map?quest=${quest.id}'),
          ),
          SizedBox(height: grid.px(2)),
          Text(
            'Check-ins count within ${quest.radiusMeters}m of the pin.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
        ],
      ),
    );
  }

  Widget _tasks(
    BuildContext context,
    PixelGrid grid,
    List<QuestStepModel> steps,
  ) {
    final shown = steps.isEmpty
        ? const [
            QuestStepModel(
              order: 1,
              title: 'Destination check-in',
              description: 'Submit location proof for independent review.',
              checkpointType: 'location',
              required: true,
              status: 'ready',
            ),
          ]
        : steps;
    final done = shown.where((step) => step.isVerified).length;
    final orderMode = _attempt?.stepOrderMode ?? widget.quest.stepOrderMode;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Your tasks · $done / ${shown.length} done',
          style: PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
        ),
        SizedBox(height: grid.px(1)),
        Text(
          orderMode == 'sequential' ? 'Do them in order.' : 'Any order.',
          style: PixelType.small(context, color: PixelPalette.slate),
        ),
        SizedBox(height: grid.px(2)),
        for (final step in shown) ...[
          _taskCard(context, grid, step),
          SizedBox(height: grid.px(2)),
        ],
      ],
    );
  }

  Widget _taskCard(BuildContext context, PixelGrid grid, QuestStepModel step) {
    final hasAttempt = _attempt != null;
    final isVerified = step.isVerified;
    final isPendingReview = step.isPendingReview;
    final isNeedsChanges = step.isNeedsChanges;
    final isReady = step.isReady;
    final isLocked = step.isLocked;
    final readyStyle = PixelBoxStyle.parchment.copyWith(
      outline: PixelPalette.sun,
    );
    final style = isReady
        ? readyStyle
        : isLocked
            ? PixelBoxStyle.slot
            : PixelBoxStyle.parchment;
    final actionVisible = hasAttempt &&
        (isReady || isNeedsChanges) &&
        !_completed &&
        !(_attempt?.isSubmitted ?? false);
    return PixelPanel(
      key: ValueKey('quest_task_${step.order}'),
      style: style,
      padding: 2,
      child: Opacity(
        opacity: isLocked && !isVerified ? 0.72 : 1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PixelSprite(
                  QuestTaskIcons.forCheckpoint(step.checkpointType),
                  scale: 2,
                ),
                SizedBox(width: grid.px(2)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: grid.px(2),
                        runSpacing: grid.px(1),
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Step ${step.order} · ${_taskTypeLabel(step.checkpointType)}',
                            style: PixelType.small(
                              context,
                              color: PixelPalette.slate,
                            ),
                          ),
                          _taskStateChip(
                            isVerified: isVerified,
                            isPendingReview: isPendingReview,
                            isNeedsChanges: isNeedsChanges,
                            isReady: isReady,
                          ),
                        ],
                      ),
                      SizedBox(height: grid.px(1)),
                      Text(
                        step.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.body(context)
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: grid.px(1)),
                      PixelText.rich(
                        step.description,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: PixelType.small(
                          context,
                          color: PixelPalette.slate,
                        ),
                      ),
                      if (step.rejectionReason != null &&
                          step.rejectionReason!.isNotEmpty) ...[
                        SizedBox(height: grid.px(1)),
                        PixelStatRow(
                          'Feedback',
                          step.rejectionReason!,
                          labelColor: PixelPalette.alert,
                          valueColor: PixelPalette.alert,
                          style: PixelType.small(context),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (actionVisible) ...[
              SizedBox(height: grid.px(2)),
              PixelButton(
                key: ValueKey('quest_task_action_${step.order}'),
                label: _taskActionLabel(step),
                expand: true,
                onPressed: _stepSubmitting ? null : () => _taskAction(step),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static const _readyChipStyle = PixelBoxStyle(
    fill: PixelPalette.sunLight,
    highlight: PixelPalette.cream,
    shade: PixelPalette.sun,
    outline: PixelPalette.sun,
    corner: 1,
    shadowPx: 0,
  );

  Widget _taskStateChip({
    required bool isVerified,
    required bool isPendingReview,
    required bool isNeedsChanges,
    required bool isReady,
  }) {
    if (isVerified) {
      return const PixelTag(
        'Verified',
        style: PixelBoxStyle.green,
        textColor: PixelPalette.white,
        maxWidth: 140,
      );
    }
    if (isPendingReview) {
      return const PixelTag(
        'Pending review',
        style: PixelBoxStyle.gold,
        textColor: PixelPalette.ink,
        maxWidth: 140,
      );
    }
    if (isNeedsChanges) {
      return const PixelTag(
        'Needs changes',
        style: PixelBoxStyle.red,
        textColor: PixelPalette.white,
        maxWidth: 140,
      );
    }
    if (isReady) {
      return const PixelTag(
        'Ready',
        style: _readyChipStyle,
        textColor: PixelPalette.goldDeep,
        maxWidth: 140,
      );
    }
    return const PixelTag(
      'Locked',
      style: PixelBoxStyle.stone,
      textColor: PixelPalette.white,
      maxWidth: 140,
    );
  }

  Widget _hostScan(BuildContext context, PixelGrid grid) {
    final hostSteps = widget.quest.steps.where(isHostScanStep).toList();
    if (hostSteps.isEmpty || !_isQuestHost) return const SizedBox.shrink();
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You host this quest',
            style:
                PixelType.body(context).copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(1)),
          Text(
            'Scan each traveler\'s quest pass on site to verify their check-in.',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(2)),
          for (final step in hostSteps) ...[
            PixelButton(
              label: 'Scan traveler pass · step ${step.order}',
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: () => hostScanTravelerPass(
                context: context,
                ref: ref,
                quest: widget.quest,
                step: step,
                getPosition: _safeGetPosition,
              ),
            ),
            SizedBox(height: grid.px(1)),
          ],
        ],
      ),
    );
  }

  Widget _authorTools(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.wood,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'You made this quest',
            style: PixelType.body(context, color: PixelPalette.paper)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(2)),
          Wrap(
            spacing: grid.px(2),
            runSpacing: grid.px(1),
            children: [
              PixelButton(
                key: const ValueKey('quest_edit_btn'),
                label: 'Edit',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    context.push('/quests/${widget.quest.id}/edit'),
              ),
              PixelButton(
                key: const ValueKey('quest_qr_sheet_btn'),
                label: 'QR sheet',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    context.push('/quests/${widget.quest.id}/qr-sheet'),
              ),
              PixelButton(
                key: const ValueKey('quest_funding_btn'),
                label: 'Funding',
                variant: PixelButtonVariant.secondary,
                onPressed: () =>
                    context.push('/quests/${widget.quest.id}/funding'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(
    BuildContext context,
    PixelGrid grid,
    List<QuestStepModel> displaySteps,
  ) {
    final signedIn = ref.watch(authProvider).isAuthenticated;
    final hasAttempt = _attempt != null;
    final isSubmitted = _attempt?.isSubmitted ?? false;
    final canSubmitReview = hasAttempt &&
        _attempt!.isInProgress &&
        _attempt!.steps.isNotEmpty &&
        _attempt!.steps
            .where((step) => step.required)
            .every((step) => step.isVerified || step.isPendingReview);
    final done = displaySteps
        .where((step) => step.isVerified || step.isPendingReview)
        .length;
    final total = displaySteps.length;
    final status = _completed
        ? 'Quest completed and reviewed. Your reward is recorded in your account.'
        : isSubmitted
            ? 'Proof submitted. Waiting for independent review; no reward has been granted yet.'
            : hasAttempt
                ? 'Quest accepted. ${_attempt!.verifiedSteps} of ${_attempt!.requiredSteps} required tasks done. Finish them all, then tap Finish quest.'
                : null;
    return Container(
      color: PixelPalette.ink,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            grid.px(3),
            grid.px(2),
            grid.px(3),
            grid.px(2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '$done / $total tasks done',
                style: PixelType.small(
                  context,
                  color: PixelPalette.paperDim,
                ),
              ),
              if (status != null) ...[
                SizedBox(height: grid.px(1)),
                Text(
                  status,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.paper,
                  ),
                ),
              ],
              if (_error != null) ...[
                SizedBox(height: grid.px(1)),
                Text(
                  _error!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: PixelType.small(
                    context,
                    color: PixelPalette.redSoft,
                  ),
                ),
                SizedBox(height: grid.px(1)),
                PixelButton(
                  key: const ValueKey('quest_retry_progress_btn'),
                  label: 'Retry progress',
                  variant: PixelButtonVariant.secondary,
                  onPressed: _loading ? null : _loadProgress,
                ),
              ],
              SizedBox(height: grid.px(2)),
              if (_loading)
                const Center(child: PixelLoader())
              else if (!signedIn)
                PixelButton(
                  key: const ValueKey('quest_signin_btn'),
                  label: 'Sign in to accept',
                  expand: true,
                  onPressed: () => context.push('/login'),
                )
              else if (!_completed && !hasAttempt)
                PixelButton(
                  key: const ValueKey('quest_accept_btn'),
                  label: 'Accept quest',
                  expand: true,
                  onPressed: _error == null ? _acceptQuest : null,
                )
              else if (canSubmitReview)
                PixelButton(
                  key: const ValueKey('quest_finish_btn'),
                  label: 'Finish quest',
                  expand: true,
                  onPressed: _finishQuest,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionLink(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return Semantics(
      button: true,
      label: label,
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: 1,
              child: Text(
                '$label >',
                style: PixelType.small(
                  context,
                  color: PixelPalette.blueBright,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _openDirections() {
    context.push(
      '/navigate?name=${Uri.encodeComponent(widget.quest.title)}&lat=${widget.quest.gpsLat}&lng=${widget.quest.gpsLng}&address=${Uri.encodeComponent(widget.quest.locationName)}',
    );
  }

  static String _baseReward(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(2);

  static String _difficulty(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  static String _taskTypeLabel(String type) => switch (type) {
        'qr' => 'QR code',
        'photo' => 'Photo',
        'ar' => 'AR finder',
        'action' => 'In-app action',
        _ => 'Location',
      };

  String _taskActionLabel(QuestStepModel step) {
    if (isHostScanStep(step)) return 'Show my pass';
    return switch (step.checkpointType) {
      'location' => 'Verify location',
      'qr' => 'Scan QR code',
      'photo' => 'Submit photo proof',
      'ar' => 'Open AR',
      _ => 'Check task',
    };
  }

  void _taskAction(QuestStepModel step) {
    if (isHostScanStep(step)) {
      _showQuestPass(step);
      return;
    }
    switch (step.checkpointType) {
      case 'location':
        _verifyLocation(step);
        break;
      case 'qr':
        _showQrVerificationModal(step);
        break;
      case 'photo':
        _showPhotoVerificationModal(step);
        break;
      case 'ar':
        _launchAR(step);
        break;
      default:
        _checkInAppTask(step);
    }
  }
}

const _questBackIcon = PixelArt('questBack', [
  '..0....',
  '.00....',
  '0000000',
  '.00....',
  '..0....',
]);

/// Where the traveler can go to do an in-app task, if the app has a screen
/// for it.
String? inAppTaskRoute(QuestStepModel step) {
  final task = step.verification?['task'];
  if (task is! Map) return null;
  switch (task['kind']) {
    case 'complete_quiz':
      final id = task['quiz_id'];
      return id is String && id.isNotEmpty ? '/cultural-quizzes/$id' : null;
    case 'vote_juanchoice':
      final id = task['campaign_id'];
      return id is String && id.isNotEmpty ? '/choice/$id' : '/choice';
    default:
      return null;
  }
}
