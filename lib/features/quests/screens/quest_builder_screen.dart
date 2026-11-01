import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../spots/models/spot_model.dart';
import '../builder/builder_models.dart';
import '../builder/quest_builder_repository.dart';
import '../builder/task_validation.dart';
import '../builder/widgets/quest_traveler_preview_card.dart';
import '../builder/widgets/task_item_card.dart';
import '../builder/widgets/task_settings_panel.dart';

class QuestBuilderScreen extends ConsumerStatefulWidget {
  final String? spotSlug;
  final String? questId;
  final SpotModel? initialSpot;

  const QuestBuilderScreen({
    super.key,
    this.spotSlug,
    this.questId,
    this.initialSpot,
  });

  @override
  ConsumerState<QuestBuilderScreen> createState() => _QuestBuilderScreenState();
}

class _QuestBuilderScreenState extends ConsumerState<QuestBuilderScreen> {
  bool _loading = true;
  String? _initError;
  bool _saving = false;
  bool _publishing = false;
  String? _serverError;
  List<ValidationError> _clientErrors = [];
  int? _expandedTaskIndex = 0;

  late QuestBuilderState _state;
  SpotModel? _spot;

  bool get isEditMode => widget.questId != null && widget.questId!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _initError = null;
    });

    try {
      if (isEditMode) {
        final repo = ref.read(questBuilderRepositoryProvider);
        final editData = await repo.getQuestForEdit(widget.questId!);

        final tasksList = (editData['tasks'] as List<dynamic>? ?? editData['steps'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(BuilderTask.fromJson)
            .toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

        _state = QuestBuilderState(
          title: editData['title'] as String? ?? '',
          description: editData['description'] as String? ?? '',
          category: questCategoryOrDefault(editData['category'] as String?),
          rewardPoints: (editData['reward_points'] as num?)?.toInt() ?? 50,
          stepOrderMode: editData['step_order_mode'] as String? ?? 'sequential',
          status: editData['status'] as String? ?? 'draft',
          tasks: tasksList,
          version: (editData['version'] as num?)?.toInt() ?? 1,
        );

        if (editData['spot'] is Map<String, dynamic>) {
          _spot = SpotModel.fromJson(editData['spot'] as Map<String, dynamic>);
        } else {
          _spot = widget.initialSpot;
        }
      } else {
        _spot = widget.initialSpot;

        final defaultLat = _spot?.gpsLat ?? 16.03;
        final defaultLng = _spot?.gpsLng ?? 120.33;
        final defaultName = _spot?.name ?? 'Destination';

        _state = QuestBuilderState(
          title: 'Explore $defaultName',
          description: 'Discover the cultural and scenic highlights of $defaultName.',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [
            BuilderTask(
              key: 'task_loc_1',
              stepOrder: 1,
              title: 'Arrive at $defaultName',
              description: 'Check in near the main landmark or visitor entrance.',
              required: true,
              checkpointType: 'location',
              verification: LocationVerification(
                fence: GeoFence(lat: defaultLat, lng: defaultLng, radiusMeters: 100),
              ),
            ),
          ],
          version: 1,
        );
      }

      setState(() {
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _initError = e.toString();
      });
    }
  }

  void _handleAddTask() {
    if (_state.tasks.length >= 10) return;
    final defaultLat = _spot?.gpsLat ?? 16.03;
    final defaultLng = _spot?.gpsLng ?? 120.33;

    final nextIndex = _state.tasks.length + 1;
    final newTask = BuilderTask(
      key: 'task_new_$nextIndex',
      stepOrder: nextIndex,
      title: 'Task $nextIndex',
      description: 'Follow the checkpoint instructions.',
      required: true,
      checkpointType: 'location',
      verification: LocationVerification(
        fence: GeoFence(lat: defaultLat, lng: defaultLng, radiusMeters: 100),
      ),
    );

    setState(() {
      _state = _state.copyWith(tasks: [..._state.tasks, newTask]);
      _expandedTaskIndex = _state.tasks.length - 1;
    });
  }

  void _handleUpdateTask(int index, BuilderTask updated) {
    final next = [..._state.tasks];
    next[index] = updated.copyWith(stepOrder: index + 1);
    setState(() {
      _state = _state.copyWith(tasks: next);
    });
  }

  void _handleMoveUp(int index) {
    if (index <= 0) return;
    final next = [..._state.tasks];
    final temp = next[index - 1];
    next[index - 1] = next[index];
    next[index] = temp;
    setState(() {
      _state = _state.copyWith(
        tasks: next.asMap().entries.map((e) => e.value.copyWith(stepOrder: e.key + 1)).toList(),
      );
      if (_expandedTaskIndex == index) {
        _expandedTaskIndex = index - 1;
      }
    });
  }

  void _handleMoveDown(int index) {
    if (index >= _state.tasks.length - 1) return;
    final next = [..._state.tasks];
    final temp = next[index + 1];
    next[index + 1] = next[index];
    next[index] = temp;
    setState(() {
      _state = _state.copyWith(
        tasks: next.asMap().entries.map((e) => e.value.copyWith(stepOrder: e.key + 1)).toList(),
      );
      if (_expandedTaskIndex == index) {
        _expandedTaskIndex = index + 1;
      }
    });
  }

  void _handleDeleteTask(int index) {
    final next = _state.tasks.asMap().entries.where((e) => e.key != index).map((e) => e.value).toList();
    setState(() {
      _state = _state.copyWith(
        tasks: next.asMap().entries.map((e) => e.value.copyWith(stepOrder: e.key + 1)).toList(),
      );
      if (_expandedTaskIndex == index) {
        _expandedTaskIndex = null;
      } else if (_expandedTaskIndex != null && _expandedTaskIndex! > index) {
        _expandedTaskIndex = _expandedTaskIndex! - 1;
      }
    });
  }

  Future<void> _handleSaveOrPublish(String targetStatus) async {
    final testState = _state.copyWith(status: targetStatus);
    final errors = validateQuestBuilder(testState);
    if (errors.isNotEmpty) {
      setState(() {
        _clientErrors = errors;
      });
      return;
    }

    setState(() {
      _clientErrors = [];
      _serverError = null;
      if (targetStatus == 'published') {
        _publishing = true;
      } else {
        _saving = true;
      }
    });

    try {
      final repo = ref.read(questBuilderRepositoryProvider);
      if (isEditMode) {
        final payload = _state.toPatchPayload(
          targetStatus: targetStatus,
          expectedVersion: _state.version,
        );
        final newVersion = await repo.patchQuest(questId: widget.questId!, payload: payload);
        if (mounted) {
          setState(() {
            _state = _state.copyWith(status: targetStatus, version: newVersion);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(targetStatus == 'published' ? 'Quest published!' : 'Draft saved!'),
              backgroundColor: AppColors.primary,
            ),
          );
          if (targetStatus == 'published') {
            context.go('/quests/${widget.questId}');
          }
        }
      } else {
        final spotTarget = widget.spotSlug ?? _spot?.slug ?? _spot?.id ?? '';
        final payload = _state.toCreatePayload(targetStatus: targetStatus);
        final newQuestId = await repo.createQuest(
          spotIdOrSlug: spotTarget,
          payload: payload,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(targetStatus == 'published' ? 'Quest created & published!' : 'Draft quest created!'),
              backgroundColor: AppColors.primary,
            ),
          );
          if (targetStatus == 'published') {
            context.go('/quests/$newQuestId');
          } else {
            context.go('/quests/$newQuestId/edit');
          }
        }
      }
    } catch (e) {
      // Map by the server's error code; never show raw exception text.
      final failure = ApiFailure.from(e, fallback: 'Could not save the quest. Please try again.');
      if (!mounted) return;
      setState(() {
        _serverError = switch (failure.code) {
          'FORBIDDEN_NOT_DESTINATION_AUTHOR' => 'Only the scout who posted this place can add quests.',
          'TASK_TOO_FAR' => 'One or more tasks are too far from the destination: ${failure.message}',
          'VERSION_CONFLICT' => 'This quest was changed somewhere else. Reload it and try again.',
          _ => failure.message,
        };
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _publishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (_initError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Quest Builder')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                const SizedBox(height: 12),
                Text('Error: $_initError', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: _loadInitialData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final defaultFence = GeoFence(
      lat: _spot?.gpsLat ?? 16.03,
      lng: _spot?.gpsLng ?? 120.33,
      radiusMeters: 100,
    );
    final spotId = _spot?.id ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.woodBrown),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditMode ? 'Edit Quest' : 'Create a Quest',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColors.woodBrown,
          ),
        ),
        actions: [
          if (isEditMode)
            IconButton(
              icon: const Icon(Icons.qr_code_2_rounded, color: AppColors.primary),
              tooltip: 'QR Sheet',
              onPressed: () => context.push('/quests/${widget.questId}/qr-sheet'),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.md),
                children: [
                  // Server / Client Errors Banner
                  if (_serverError != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _serverError!,
                              style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_clientErrors.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Please resolve the following before publishing:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF78350F)),
                          ),
                          const SizedBox(height: 4),
                          ..._clientErrors.map((e) => Text('• ${e.message}', style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // 1. Quest Basics Section
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE7E5E4)),
                      ),
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Quest Basics',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: AppColors.woodBrown,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Title
                        const Text('Quest Title', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                        const SizedBox(height: 4),
                        TextFormField(
                          key: const Key('quest_title_input'),
                          initialValue: _state.title,
                          onChanged: (val) => setState(() => _state = _state.copyWith(title: val)),
                          decoration: InputDecoration(
                            hintText: 'e.g. Hundred Islands Eco-Discovery',
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        const Text('Description', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                        const SizedBox(height: 4),
                        TextFormField(
                          initialValue: _state.description,
                          maxLines: 3,
                          onChanged: (val) => setState(() => _state = _state.copyWith(description: val)),
                          decoration: InputDecoration(
                            hintText: 'Describe what travelers will experience and accomplish.',
                            contentPadding: const EdgeInsets.all(10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category & Reward Points Row
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Category', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _state.category,
                                    isExpanded: true,
                                    onChanged: (val) {
                                      if (val != null) setState(() => _state = _state.copyWith(category: val));
                                    },
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: questCategories.map((c) => DropdownMenuItem(value: c.value, child: Text(c.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis))).toList(),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Reward', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<int>(
                                    value: _state.rewardPoints,
                                    isExpanded: true,
                                    onChanged: (val) {
                                      if (val != null) setState(() => _state = _state.copyWith(rewardPoints: val));
                                    },
                                    decoration: InputDecoration(
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                    ),
                                    items: const [
                                      DropdownMenuItem(value: 50, child: Text('50 pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 75, child: Text('75 pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                      DropdownMenuItem(value: 100, child: Text('100 pts', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Step Order Mode
                        const Text('Order Mode', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.woodBrown)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'sequential',
                                groupValue: _state.stepOrderMode,
                                title: const Text('In order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  if (val != null) setState(() => _state = _state.copyWith(stepOrderMode: val));
                                },
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                value: 'any',
                                groupValue: _state.stepOrderMode,
                                title: const Text('Any order', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                activeColor: AppColors.primary,
                                onChanged: (val) {
                                  if (val != null) setState(() => _state = _state.copyWith(stepOrderMode: val));
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  ),
                  const SizedBox(height: 16),

                  // 2. Tasks List Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'TASKS (${_state.tasks.length}/10)',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          color: AppColors.woodBrown,
                        ),
                      ),
                      if (_state.tasks.length < 10)
                        TextButton.icon(
                          key: const Key('builder_add_task_btn'),
                          style: TextButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: _handleAddTask,
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add Task', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  ..._state.tasks.asMap().entries.map((entry) {
                    final index = entry.key;
                    final task = entry.value;
                    final isExpanded = _expandedTaskIndex == index;

                    return TaskItemCard(
                      key: ValueKey(task.key),
                      task: task,
                      index: index,
                      totalTasks: _state.tasks.length,
                      isExpanded: isExpanded,
                      onToggleExpand: () {
                        setState(() {
                          _expandedTaskIndex = isExpanded ? null : index;
                        });
                      },
                      onMoveUp: () => _handleMoveUp(index),
                      onMoveDown: () => _handleMoveDown(index),
                      onDelete: () => _handleDeleteTask(index),
                      onChanged: (updated) => _handleUpdateTask(index, updated),
                      settingsPanel: TaskSettingsPanel(
                        task: task,
                        destinationDefaultFence: defaultFence,
                        destinationSpotId: spotId,
                        onChanged: (updated) => _handleUpdateTask(index, updated),
                      ),
                    );
                  }),

                  const SizedBox(height: 16),

                  // 3. Traveler Preview Section
                  QuestTravelerPreviewCard(
                    state: _state,
                    locationName: _spot?.name ?? 'Pangasinan Destination',
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),

            // Sticky Bottom Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white,
                border: const Border(top: BorderSide(color: Color(0xFFE7E5E4))),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('builder_save_draft_btn'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        foregroundColor: AppColors.woodBrown,
                        side: const BorderSide(color: Color(0xFFD6D3D1)),
                      ),
                      onPressed: _saving || _publishing ? null : () => _handleSaveOrPublish('draft'),
                      child: Text(_saving ? 'Saving…' : 'Save draft'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('builder_publish_btn'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: _saving || _publishing ? null : () => _handleSaveOrPublish('published'),
                      icon: const Icon(Icons.send_rounded, size: 16),
                      label: Text(_publishing ? 'Publishing…' : 'Publish'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
