import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/jdq_scaffold.dart';
import '../../../core/widgets/jdq_section_header.dart';
import '../../../core/widgets/primary_button.dart';
import '../../auth/providers/auth_provider.dart';
import 'qr_scan_screen.dart';
import '../models/quest_model.dart';
import '../../../core/widgets/designer_guide.dart';

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
          _attempt = QuestAttemptModel.fromJson(Map<String, dynamic>.from(rawAttempt));
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
        _error = _messageFromDio(error, 'Could not accept this quest. Please retry.');
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
              content: Text(_messageFromDio(dioErr, 'Location verification failed.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not verify location. Please retry.')),
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Future<void> verify(StateSetter setModalState) async {
                              final code = textController.text.trim();
                              if (code.isEmpty) {
                                setModalState(() =>
                                    modalError = 'Please enter a marker code.');
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
                                final res = await ref
                                    .read(apiClientProvider)
                                    .dio
                                    .post(
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
                                          content: Text(
                                              'QR code verified successfully!')),
                                    );
                                  }
                                } else {
                                  setModalState(() =>
                                      modalError = 'QR verification failed.');
                                }
                              } on DioException catch (dioErr) {
                                setModalState(() => modalError =
                                    _messageFromDio(dioErr,
                                        'Invalid QR code or out of radius.'));
                              } catch (_) {
                                setModalState(() => modalError =
                                    'Verification failed. Try again.');
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(8),
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
                      label: modalLoading ? 'Uploading Proof...' : 'Submit Photo Proof',
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
                                final res = await ref
                                    .read(apiClientProvider)
                                    .dio
                                    .post(
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
                                    _messageFromDio(dioErr, 'Photo upload failed.'));
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

  Future<void> _submitForReview() async {
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(apiClientProvider)
          .dio
          .post('/quests/${widget.quest.id}/submit-for-review');
      if (res.data['success'] == true) {
        await _loadProgress();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Quest submitted for review! Rewards will be granted once approved.')),
          );
        }
      }
    } on DioException catch (dioErr) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_messageFromDio(
                  dioErr, 'Could not submit quest for review.'))),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Could not submit quest for review. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
          if (task is Map && task['kind'] is String) 'action_name': task['kind'],
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
          const SnackBar(content: Text('Could not check this task. Please retry.')),
        );
      }
    } finally {
      if (mounted) setState(() => _stepSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quest = widget.quest;
    final hasImage = quest.imageUrl != null &&
        quest.imageUrl!.isNotEmpty &&
        (quest.imageUrl!.startsWith('http://') ||
            quest.imageUrl!.startsWith('https://'));

    // If attempt has live steps, use those; otherwise use default quest steps
    final displaySteps = _attempt != null && _attempt!.steps.isNotEmpty
        ? _attempt!.steps
        : quest.steps;

    return JdqScaffold(
      padding: EdgeInsets.zero,
      appBar: AppBar(
        title: Text(quest.title),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Image
            UiSpecContainer(
              spec: const UiSpec(
                title: 'Quest Hero Photography & Bounty Pills',
                figmaLayer: '#Quest_Detail_Hero_Image',
                dimensions: 'Full width hero image, Height: 240dp',
                dataBinding: 'quest.markerImageUrl / quest.category',
                stateNotes: 'Displays curated destination photography with category badge overlay',
                uxNotes: 'Hero visual provides strong sense of place and local Pangasinan heritage.',
              ),
              child: Stack(
                children: [
                  Container(
                    height: 240,
                    width: double.infinity,
                    color: AppColors.woodBrown,
                    child: hasImage
                        ? Image.network(
                            quest.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildHeaderPlaceholder(),
                          )
                        : _buildHeaderPlaceholder(),
                  ),
                  Positioned(
                    top: AppSpacing.gutter,
                    left: AppSpacing.gutter,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.woodBrown.withOpacity(0.85),
                        borderRadius: AppSpacing.roundedSm,
                      ),
                      child: Text(
                        quest.categoryDisplay,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content Body
            Padding(
              padding: const EdgeInsets.all(AppSpacing.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    quest.title,
                    style: AppTypography.displayMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: AppColors.primary, size: 16),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          quest.locationName,
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  if (quest.crowdStatus == 'estimated_busy') ...[
                    const SizedBox(height: AppSpacing.md),
                    UiSpecContainer(
                      spec: const UiSpec(
                        title: 'Live Overcrowding Diversion Card',
                        figmaLayer: '#Quest_Crowd_Pressure_Alert',
                        dimensions: 'Full width, Padding: 16dp, Radius: 16dp',
                        dataBinding:
                            'quest.crowdStatus (estimated_busy / tranquil / moderate)',
                        stateNotes:
                            'Displays warning alert when tourist congestion is high to redirect visitors',
                        uxNotes:
                            'Amber/Coral alert container with warning icon and link to tranquil gems.',
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.crowdBusyBg,
                          borderRadius: AppSpacing.roundedLg,
                          border: Border.all(
                              color: AppColors.crowdBusy.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                color: AppColors.crowdBusy, size: 22),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'High Tourist Activity Detected',
                                    style: TextStyle(
                                      color: AppColors.crowdBusy,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This destination is currently experiencing high foot traffic. Explore quieter hidden gems in the Explore tab for bonus rewards!',
                                    style: AppTypography.bodySmall.copyWith(
                                      color:
                                          AppColors.crowdBusy.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  if (quest.campaignId != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.sunGold.withOpacity(0.15),
                        borderRadius: AppSpacing.roundedMd,
                        border: Border.all(color: AppColors.sunGold),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.campaign_rounded,
                              color: AppColors.woodBrown, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            'Sponsored Campaign: ${quest.remainingSlots ?? "Open"} reward slots available',
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.woodBrown),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.lg),

                  // Quest Parameters Card
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'Quest Reward & GPS Guard Parameters Card',
                      figmaLayer: '#Quest_Specs_Metrics_Card',
                      dimensions:
                          'Full width split card, Height: ~84dp, Radius: 16dp',
                      dataBinding:
                          'quest.rewardPoints / quest.allowedRadiusMeters',
                      stateNotes:
                          'Points pill + Radar icon with server-enforced radius constraint',
                      uxNotes:
                          'Prominently clarifies physical verification constraints before travel.',
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: AppSpacing.roundedLg,
                        border: Border.all(color: AppColors.borderLowContrast),
                        boxShadow: AppSpacing.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QUEST REWARD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.stars_rounded,
                                  color: AppColors.sunGold, size: 20),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  '${quest.rewardPoints} Points',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.woodBrown,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (quest.funding != null) ...[
                            const SizedBox(height: AppSpacing.sm),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Funded Eco-Quest · ${quest.funding!.completionsLeftEstimate} estimated rewards left',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  if (quest.funding!.sponsors.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Supported by ${quest.funding!.sponsors.map((sponsor) => sponsor['name']?.toString()).whereType<String>().join(', ')}',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary),
                                    ),
                                  ],
                                  if (quest.funding!.perk case final perk?) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      'Sponsor perk: ${perk['title'] ?? 'available'} · ${perk['remaining'] ?? 0} available',
                                      style: AppTypography.bodySmall.copyWith(color: AppColors.primary),
                                    ),
                                  ],
                                  const SizedBox(height: 4),
                                  Text(
                                    'Simulated points only; no cash or blockchain value.',
                                    style: AppTypography.bodySmall.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (quest.authorId != null &&
                              ref.watch(authProvider).user?.id == quest.authorId) ...[
                            const SizedBox(height: AppSpacing.sm),
                            OutlinedButton.icon(
                              onPressed: () => context.push('/quests/${quest.id}/funding'),
                              icon: const Icon(Icons.account_balance_wallet_outlined),
                              label: const Text('Manage funding'),
                            ),
                          ],
                          const Divider(height: AppSpacing.lg * 2),
                          const Text(
                            'GPS RADIUS GUARD',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textMuted,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.radar_rounded,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Within ${quest.allowedRadiusMeters}m',
                                  style: AppTypography.labelLarge.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Overview
                  const JdqSectionHeader(
                    title: 'Quest Overview',
                  ),
                  Text(
                    quest.description,
                    style: AppTypography.bodyLarge,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // Objective Steps
                  const JdqSectionHeader(
                    title: 'Quest Objectives',
                    subtitle: 'Requirements set by the destination quest author.',
                  ),

                  if (displaySteps.isEmpty)
                    _buildStepCard(
                      step: const QuestStepModel(
                        order: 1,
                        title: 'Destination check-in',
                        description: 'Submit location proof for independent review.',
                        checkpointType: 'location',
                        required: true,
                        status: 'ready',
                      ),
                    )
                  else
                    for (final step in displaySteps) ...[
                      _buildStepCard(step: step),
                      const SizedBox(height: AppSpacing.sm),
                    ],

                  const SizedBox(height: AppSpacing.sectionGap),

                  // Enrollment and Progress CTA
                  UiSpecContainer(
                    spec: const UiSpec(
                      title: 'Start Quest Experience CTA',
                      figmaLayer: '#Quest_Start_Action_Button',
                      dimensions: 'Full width button, Height: 52dp, Radius: 12dp',
                      dataBinding: 'POST /quests/:id/attempts and GET /quests/:id/progress',
                      stateNotes: 'Shows the server-confirmed enrollment or completion state',
                      uxNotes: 'Prominent primary CTA to begin interactive verification with in-app navigation shortcut.',
                      deferred: false,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildParticipationSection(),
                        const SizedBox(height: AppSpacing.sm),
                        InkWell(
                          onTap: () {
                            context.push(
                              '/navigate?lat=${quest.gpsLat}&lng=${quest.gpsLng}&name=${Uri.encodeComponent(quest.title)}&address=${Uri.encodeComponent(quest.locationName)}',
                            );
                          },
                          borderRadius: AppSpacing.roundedMd,
                          child: Container(
                            height: 50,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLow,
                              borderRadius: AppSpacing.roundedMd,
                              border: Border.all(
                                  color: AppColors.borderLowContrast),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.navigation_rounded,
                                    size: 18, color: AppColors.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Route',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.woodBrown),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.sectionGap),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepCard({required QuestStepModel step}) {
    final hasAttempt = _attempt != null;
    final isVerified = step.isVerified;
    final isPendingReview = step.isPendingReview;
    final isNeedsChanges = step.isNeedsChanges;
    final isReady = step.isReady;

    Color badgeBg;
    Color badgeFg;
    String badgeText;
    IconData badgeIcon;

    if (isVerified) {
      badgeBg = AppColors.success.withOpacity(0.15);
      badgeFg = AppColors.success;
      badgeText = 'Verified';
      badgeIcon = Icons.check_circle_rounded;
    } else if (isPendingReview) {
      badgeBg = AppColors.sunGold.withOpacity(0.18);
      badgeFg = AppColors.woodBrown;
      badgeText = 'Pending Review';
      badgeIcon = Icons.hourglass_top_rounded;
    } else if (isNeedsChanges) {
      badgeBg = AppColors.danger.withOpacity(0.15);
      badgeFg = AppColors.danger;
      badgeText = 'Needs Changes';
      badgeIcon = Icons.error_outline_rounded;
    } else if (isReady) {
      badgeBg = AppColors.primary.withOpacity(0.15);
      badgeFg = AppColors.primary;
      badgeText = 'Ready';
      badgeIcon = Icons.play_circle_fill_rounded;
    } else {
      badgeBg = AppColors.borderLowContrast;
      badgeFg = AppColors.textMuted;
      badgeText = 'Locked';
      badgeIcon = Icons.lock_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: AppSpacing.roundedMd,
        border: Border.all(
          color: isReady
              ? AppColors.primary.withOpacity(0.4)
              : AppColors.borderLowContrast,
          width: isReady ? 1.5 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isVerified
                      ? AppColors.success.withOpacity(0.15)
                      : AppColors.crowdModerateBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  switch (step.checkpointType) {
                    'qr' => Icons.qr_code_scanner_rounded,
                    'photo' => Icons.camera_alt_rounded,
                    'location' => Icons.location_on_rounded,
                    'ar' => Icons.view_in_ar_rounded,
                    _ => Icons.touch_app_rounded,
                  },
                  color: isVerified ? AppColors.success : AppColors.woodBrown,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          'Step ${step.order}: ${step.title}',
                          style: AppTypography.labelLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hasAttempt)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(badgeIcon, size: 12, color: badgeFg),
                                const SizedBox(width: 4),
                                Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: badgeFg,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      step.description,
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (step.rejectionReason != null &&
                        step.rejectionReason!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Feedback: ${step.rejectionReason}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.danger,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (hasAttempt &&
              (isReady || isNeedsChanges) &&
              !_completed &&
              !(_attempt?.isSubmitted ?? false)) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: _buildStepActionButton(step),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStepActionButton(QuestStepModel step) {
    final label = switch (step.checkpointType) {
      'location' => 'Verify Location (GPS)',
      'qr' => 'Scan QR Code',
      'photo' => 'Submit Photo Proof',
      'ar' => 'Open AR',
      _ => 'Check task',
    };
    final icon = switch (step.checkpointType) {
      'location' => Icons.my_location_rounded,
      'qr' => Icons.qr_code_scanner_rounded,
      'photo' => Icons.camera_alt_rounded,
      'ar' => Icons.view_in_ar_rounded,
      _ => Icons.check_circle_outline_rounded,
    };

    return SizedBox(
      height: 36,
      child: ElevatedButton.icon(
        onPressed: _stepSubmitting
            ? null
            : () {
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
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildParticipationSection() {
    final signedIn = ref.watch(authProvider).isAuthenticated;
    final hasAttempt = _attempt != null;
    final isSubmitted = _attempt?.isSubmitted ?? false;

    final canSubmitReview = hasAttempt &&
        _attempt!.isInProgress &&
        _attempt!.steps.isNotEmpty &&
        _attempt!.steps
            .where((s) => s.required)
            .every((s) => s.isVerified || s.isPendingReview);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_completed)
          const Text(
              'Quest completed and reviewed. Your reward is recorded in your account.')
        else if (isSubmitted)
          const Text(
              'Proof submitted. Your quest is waiting for independent review; no reward has been granted yet.')
        else if (hasAttempt)
          Text(
              'Quest accepted. ${_attempt!.verifiedSteps} of ${_attempt!.requiredSteps} required steps verified. Submit required proof for review.')
        else if (signedIn && !_loading && _error == null)
          const Text('Accept this quest to register your attempt.'),
        if (_error != null) ...[
          const SizedBox(height: 4),
          Text(_error!, style: const TextStyle(color: AppColors.danger)),
          TextButton(
            onPressed: _loading ? null : _loadProgress,
            child: const Text('Retry progress'),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        if (_loading)
          const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
        else if (!signedIn)
          PrimaryButton(
            label: 'Sign in to accept',
            icon: Icons.login_rounded,
            onPressed: () => context.push('/login'),
          )
        else if (!_completed && !hasAttempt)
          PrimaryButton(
            label: 'Accept quest',
            icon: Icons.play_arrow_rounded,
            onPressed: _error == null ? _acceptQuest : null,
          )
        else if (canSubmitReview)
          PrimaryButton(
            label: 'Submit Quest for Review',
            icon: Icons.send_rounded,
            onPressed: _submitForReview,
          ),
      ],
    );
  }

  Widget _buildHeaderPlaceholder() {
    return Container(
      color: AppColors.primaryDark,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.stars_rounded, size: 64, color: AppColors.sunGold),
            const SizedBox(height: AppSpacing.sm),
            Text(
              widget.quest.locationName,
              style: AppTypography.bodyMedium.copyWith(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

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
