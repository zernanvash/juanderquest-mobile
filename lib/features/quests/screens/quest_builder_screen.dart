import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_failure.dart';
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
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../spots/models/spot_model.dart';
import '../builder/builder_models.dart';
import '../builder/quest_builder_repository.dart';
import '../builder/task_validation.dart';
import '../builder/widgets/quest_traveler_preview_card.dart';
import '../builder/widgets/task_item_card.dart';
import '../builder/widgets/task_settings_panel.dart';
import '../pixel/dashed_button.dart';

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

        final tasksList = (editData['tasks'] as List<dynamic>? ??
                editData['steps'] as List<dynamic>? ??
                [])
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
          description:
              'Discover the cultural and scenic highlights of $defaultName.',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [
            BuilderTask(
              key: 'task_loc_1',
              stepOrder: 1,
              title: 'Arrive at $defaultName',
              description:
                  'Check in near the main landmark or visitor entrance.',
              required: true,
              checkpointType: 'location',
              verification: LocationVerification(
                fence: GeoFence(
                    lat: defaultLat, lng: defaultLng, radiusMeters: 100),
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
        tasks: next
            .asMap()
            .entries
            .map((e) => e.value.copyWith(stepOrder: e.key + 1))
            .toList(),
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
        tasks: next
            .asMap()
            .entries
            .map((e) => e.value.copyWith(stepOrder: e.key + 1))
            .toList(),
      );
      if (_expandedTaskIndex == index) {
        _expandedTaskIndex = index + 1;
      }
    });
  }

  void _handleDeleteTask(int index) {
    final next = _state.tasks
        .asMap()
        .entries
        .where((e) => e.key != index)
        .map((e) => e.value)
        .toList();
    setState(() {
      _state = _state.copyWith(
        tasks: next
            .asMap()
            .entries
            .map((e) => e.value.copyWith(stepOrder: e.key + 1))
            .toList(),
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
        final newVersion =
            await repo.patchQuest(questId: widget.questId!, payload: payload);
        if (mounted) {
          setState(() {
            _state = _state.copyWith(status: targetStatus, version: newVersion);
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(targetStatus == 'published'
                  ? 'Quest published!'
                  : 'Draft saved!'),
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
              content: Text(targetStatus == 'published'
                  ? 'Quest created & published!'
                  : 'Draft quest created!'),
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
      final failure = ApiFailure.from(e,
          fallback: 'Could not save the quest. Please try again.');
      if (!mounted) return;
      setState(() {
        _serverError = switch (failure.code) {
          'FORBIDDEN_NOT_DESTINATION_AUTHOR' =>
            'Only the scout who posted this place can add quests.',
          'TASK_TOO_FAR' =>
            'One or more tasks are too far from the destination: ${failure.message}',
          'VERSION_CONFLICT' =>
            'This quest was changed somewhere else. Reload it and try again.',
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
      return Theme(
        data: AppTheme.pixel,
        child: const Scaffold(
          backgroundColor: PixelPalette.paper,
          body: Center(child: PixelLoader()),
        ),
      );
    }

    if (_initError != null) {
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
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(grid.px(4)),
                      child: PixelPanel(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Could not load the quest builder',
                              style: PixelType.title(context),
                            ),
                            SizedBox(height: grid.px(2)),
                            Text(
                              _initError!,
                              style: PixelType.small(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            SizedBox(height: grid.px(3)),
                            PixelButton(
                              label: 'Retry',
                              expand: true,
                              onPressed: _loadInitialData,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    }

    final defaultFence = GeoFence(
      lat: _spot?.gpsLat ?? 16.03,
      lng: _spot?.gpsLng ?? 120.33,
      radiusMeters: 100,
    );
    final spotId = _spot?.id ?? '';

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
              child: Column(
                children: [
                  PixelAppBar(
                    title: isEditMode ? 'Edit quest' : 'Create a quest',
                    onBack: () => Navigator.of(context).pop(),
                    actions: [
                      if (isEditMode)
                        PixelButton(
                          label: 'QR',
                          variant: PixelButtonVariant.secondary,
                          onPressed: () => context
                              .push('/quests/${widget.questId}/qr-sheet'),
                        ),
                    ],
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        grid.px(4),
                        grid.px(3),
                        grid.px(4),
                        grid.px(6) + MediaQuery.paddingOf(context).bottom,
                      ),
                      children: [
                        if (_serverError != null) ...[
                          _serverErrorPanel(context, grid),
                          SizedBox(height: grid.px(3)),
                        ],
                        if (_clientErrors.isNotEmpty) ...[
                          _validationPanel(context, grid),
                          SizedBox(height: grid.px(3)),
                        ],
                        _basicsPanel(context, grid),
                        SizedBox(height: grid.px(3)),
                        _tasksSection(context, grid, defaultFence, spotId),
                        SizedBox(height: grid.px(3)),
                        QuestTravelerPreviewCard(
                          state: _state,
                          locationName: _spot?.name ?? 'Pangasinan Destination',
                        ),
                      ],
                    ),
                  ),
                  _bottomBar(context, grid),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _serverErrorPanel(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.red,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PixelSprite(DesignerArt.notifBell, scale: 2),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: Text(
              _serverError!,
              style: PixelType.small(context, color: PixelPalette.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _validationPanel(BuildContext context, PixelGrid grid) {
    return PixelPanel(
      style: PixelBoxStyle.parchment.copyWith(outline: PixelPalette.red),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FIX BEFORE PUBLISHING',
            style: PixelType.body(context, color: PixelPalette.red)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: grid.px(2)),
          for (final error in _clientErrors)
            Padding(
              padding: EdgeInsets.only(bottom: grid.px(1)),
              child: Text(
                error.message,
                style: PixelType.small(
                  context,
                  color: PixelPalette.redDeep,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _basicsPanel(BuildContext context, PixelGrid grid) {
    final categoryIndex =
        questCategories.indexWhere((c) => c.value == _state.category);
    const rewardOptions = [50, 75, 100];
    final rewardIndex = rewardOptions.indexOf(_state.rewardPoints);
    return PixelPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quest basics',
            style: PixelType.title(context),
          ),
          SizedBox(height: grid.px(2)),
          PixelTextField(
            key: const Key('quest_title_input'),
            initialValue: _state.title,
            label: 'Quest title',
            hint: 'e.g. Hundred Islands Eco-Discovery',
            onChanged: (value) =>
                setState(() => _state = _state.copyWith(title: value)),
          ),
          SizedBox(height: grid.px(2)),
          PixelTextField(
            initialValue: _state.description,
            label: 'Description',
            hint: 'Describe what travelers will experience.',
            maxLines: 3,
            onChanged: (value) =>
                setState(() => _state = _state.copyWith(description: value)),
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'Category',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelSegmented(
            key: const ValueKey('builder_category_segmented'),
            items: questCategories.map((c) => c.label).toList(),
            selectedIndex: categoryIndex < 0 ? 0 : categoryIndex,
            onChanged: (index) => setState(
              () => _state = _state.copyWith(
                category: questCategories[index].value,
              ),
            ),
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'Reward',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelSegmented(
            key: const ValueKey('builder_reward_segmented'),
            items: const ['50 pts', '75 pts', '100 pts'],
            selectedIndex: rewardIndex < 0 ? 0 : rewardIndex,
            onChanged: (index) => setState(
              () => _state = _state.copyWith(
                rewardPoints: rewardOptions[index],
              ),
            ),
          ),
          SizedBox(height: grid.px(3)),
          Text(
            'Order mode',
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          PixelSegmented(
            key: const ValueKey('builder_order_segmented'),
            items: const ['In order', 'Any order'],
            selectedIndex: _state.stepOrderMode == 'any' ? 1 : 0,
            onChanged: (index) => setState(
              () => _state = _state.copyWith(
                stepOrderMode: index == 1 ? 'any' : 'sequential',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tasksSection(
    BuildContext context,
    PixelGrid grid,
    GeoFence defaultFence,
    String spotId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: grid.px(2),
          runSpacing: grid.px(1),
          children: [
            Text(
              'Tasks (${_state.tasks.length}/10)',
              style: PixelType.title(context),
            ),
            if (_state.tasks.length < 10)
              PixelDashedButton(
                key: const ValueKey('builder_add_task_btn'),
                label: '+ Add task',
                onPressed: _handleAddTask,
              ),
          ],
        ),
        SizedBox(height: grid.px(2)),
        for (final entry in _state.tasks.asMap().entries) ...[
          TaskItemCard(
            key: ValueKey(entry.value.key),
            task: entry.value,
            index: entry.key,
            totalTasks: _state.tasks.length,
            isExpanded: _expandedTaskIndex == entry.key,
            onToggleExpand: () {
              setState(() {
                _expandedTaskIndex =
                    _expandedTaskIndex == entry.key ? null : entry.key;
              });
            },
            onMoveUp: () => _handleMoveUp(entry.key),
            onMoveDown: () => _handleMoveDown(entry.key),
            onDelete: () => _handleDeleteTask(entry.key),
            onChanged: (updated) => _handleUpdateTask(entry.key, updated),
            destinationDefaultFence: defaultFence,
            destinationSpotId: spotId,
            settingsPanel: TaskSettingsPanel(
              task: entry.value,
              destinationDefaultFence: defaultFence,
              destinationSpotId: spotId,
              onChanged: (updated) => _handleUpdateTask(entry.key, updated),
            ),
          ),
          SizedBox(height: grid.px(2)),
        ],
      ],
    );
  }

  Widget _bottomBar(BuildContext context, PixelGrid grid) {
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
          child: Row(
            children: [
              Expanded(
                child: PixelButton(
                  key: const ValueKey('builder_save_draft_btn'),
                  label: 'Save draft',
                  style: PixelBoxStyle.wood,
                  textColor: PixelPalette.white,
                  expand: true,
                  loading: _saving,
                  onPressed: _saving || _publishing
                      ? null
                      : () => _handleSaveOrPublish('draft'),
                ),
              ),
              SizedBox(width: grid.px(2)),
              Expanded(
                child: PixelButton(
                  key: const ValueKey('builder_publish_btn'),
                  label: 'Publish',
                  expand: true,
                  loading: _publishing,
                  onPressed: _saving || _publishing
                      ? null
                      : () => _handleSaveOrPublish('published'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
