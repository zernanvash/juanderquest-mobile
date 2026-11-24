import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/app_language.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/pixel/generated/pixel_palette.g.dart';
import '../../../core/pixel/pixel_background.dart';
import '../../../core/pixel/pixel_box.dart';
import '../../../core/pixel/pixel_controls.dart';
import '../../../core/pixel/pixel_feedback.dart';
import '../../../core/pixel/pixel_grid.dart';
import '../../../core/pixel/pixel_input.dart';
import '../../../core/pixel/pixel_nav.dart';
import '../../../core/pixel/pixel_text.dart';
import '../../../core/pixel/pixel_text_3d.dart';
import '../../../core/theme/app_theme.dart';
import '../../spots/models/spot_model.dart';
import '../builder/builder_models.dart';
import '../builder/quest_builder_repository.dart';
import '../builder/quest_wizard_logic.dart';
import '../builder/task_validation.dart';
import '../builder/widgets/location_fence_map_picker.dart';
import '../builder/widgets/nearby_merchants_section.dart';
import '../builder/widgets/quest_traveler_preview_card.dart';

enum _WizardStep {
  name, // 1 / 7
  about, // 2 / 7
  taskType, // 3 / 7
  taskWhere, // 4 / 7
  taskDetails, // 4 / 7 (extra, only for qr / photo / ar / action)
  taskList, // 5 / 7
  reward, // 6 / 7
  review, // 7 / 7
}

const _kArObjects = <MapEntry<String, String>>[
  MapEntry('token', 'Token'),
  MapEntry('gem', 'Gem'),
  MapEntry('beacon', 'Beacon'),
  MapEntry('box', 'Chest'),
];

const _kArColors = <MapEntry<String, String>>[
  MapEntry('#FFB703', 'Gold'),
  MapEntry('#2D6A4F', 'Emerald'),
  MapEntry('#3B82F6', 'Sapphire'),
  MapEntry('#E11D48', 'Ruby'),
];

/// Plan 118: 7-page step-by-step quest creation & edit wizard.
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

  late QuestBuilderState _state;
  SpotModel? _spot;
  String? _activeQuestId;
  List<NearbySponsorInvite> _sponsorInvites = const [];

  _WizardStep _step = _WizardStep.name;

  // Task currently being added or edited across pages 3 -> 4 -> (extra).
  int? _editingTaskIndex;
  String? _draftTaskType;
  BuilderTask? _draftTask;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _photoPromptCtrl;
  late final TextEditingController _actionQuizIdCtrl;

  bool get isEditMode =>
      (widget.questId != null && widget.questId!.isNotEmpty) ||
      (_activeQuestId != null && _activeQuestId!.isNotEmpty);

  String? get _effectiveQuestId => _activeQuestId ?? widget.questId;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _descCtrl = TextEditingController();
    _photoPromptCtrl = TextEditingController();
    _actionQuizIdCtrl = TextEditingController();
    _loadInitialData();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _photoPromptCtrl.dispose();
    _actionQuizIdCtrl.dispose();
    super.dispose();
  }

  int get _displayPageNumber => switch (_step) {
        _WizardStep.name => 1,
        _WizardStep.about => 2,
        _WizardStep.taskType => 3,
        _WizardStep.taskWhere => 4,
        _WizardStep.taskDetails => 4, // Extra details keeps "4 / 7"
        _WizardStep.taskList => 5,
        _WizardStep.reward => 6,
        _WizardStep.review => 7,
      };

  _WizardStep _stepForPageNumber(int page) => switch (page) {
        1 => _WizardStep.name,
        2 => _WizardStep.about,
        3 => _WizardStep.taskType,
        4 => _WizardStep.taskWhere,
        5 => _WizardStep.taskList,
        6 => _WizardStep.reward,
        _ => _WizardStep.review,
      };

  Future<void> _loadInitialData() async {
    setState(() {
      _loading = true;
      _initError = null;
    });

    try {
      if (widget.questId != null && widget.questId!.isNotEmpty) {
        final repo = ref.read(questBuilderRepositoryProvider);
        final editData = await repo.getQuestForEdit(widget.questId!);

        final tasksList = (editData['tasks'] as List<dynamic>? ??
                editData['steps'] as List<dynamic>? ??
                [])
            .whereType<Map<String, dynamic>>()
            .map(BuilderTask.fromJson)
            .toList()
          ..sort((a, b) => a.stepOrder.compareTo(b.stepOrder));

        _activeQuestId = widget.questId;
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

        _nameCtrl.text = _state.title;
        _descCtrl.text = _state.description;

        // Plan 118: edit mode opens straight on page 7 when complete,
        // or resumes at the first incomplete page for an unfinished draft.
        final resumePage = _state.status == 'published'
            ? 7
            : QuestWizardLogic.firstIncompletePage(_state);
        _step = _stepForPageNumber(resumePage);
      } else {
        _spot = widget.initialSpot;
        _state = const QuestBuilderState(
          title: '',
          description: '',
          category: 'eco',
          rewardPoints: 50,
          stepOrderMode: 'sequential',
          status: 'draft',
          tasks: [],
          version: 1,
        );
        _nameCtrl.text = '';
        _descCtrl.text = '';
        _step = _WizardStep.name;
      }

      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _initError = e.toString();
        });
      }
    }
  }

  double get _spotLat => _spot?.gpsLat ?? 16.03;
  double get _spotLng => _spot?.gpsLng ?? 120.33;
  String get _spotName => _spot?.name ?? 'Destination';

  void _prepareNewTask() {
    _editingTaskIndex = null;
    _draftTaskType = null;
    _draftTask = null;
    _photoPromptCtrl.text = '';
    _actionQuizIdCtrl.text = '';
  }

  void _prepareEditTask(int index) {
    final existing = _state.tasks[index];
    _editingTaskIndex = index;
    _draftTaskType = existing.checkpointType;
    _draftTask = existing;
    if (existing.verification is PhotoVerification) {
      _photoPromptCtrl.text = (existing.verification as PhotoVerification).prompt;
    } else {
      _photoPromptCtrl.text = '';
    }
    if (existing.verification is ActionVerification) {
      final t = (existing.verification as ActionVerification).task;
      _actionQuizIdCtrl.text = t['quiz_id']?.toString() ?? '';
    } else {
      _actionQuizIdCtrl.text = '';
    }
  }

  void _selectTaskType(String type) {
    setState(() {
      _draftTaskType = type;
      if (_draftTask == null || _draftTask!.checkpointType != type) {
        final order = _editingTaskIndex != null
            ? _editingTaskIndex! + 1
            : _state.tasks.length + 1;
        _draftTask = QuestWizardLogic.buildDefaultTask(
          type: type,
          stepOrder: order,
          lat: _spotLat,
          lng: _spotLng,
          spotName: _spotName,
          spotId: _spot?.id,
        );
        if (_draftTask!.verification is PhotoVerification) {
          _photoPromptCtrl.text =
              (_draftTask!.verification as PhotoVerification).prompt;
        }
      }
    });
  }

  void _commitDraftTaskToList() {
    final task = _draftTask;
    if (task == null) return;
    final next = [..._state.tasks];
    if (_editingTaskIndex != null &&
        _editingTaskIndex! >= 0 &&
        _editingTaskIndex! < next.length) {
      next[_editingTaskIndex!] = task.copyWith(stepOrder: _editingTaskIndex! + 1);
    } else {
      next.add(task.copyWith(stepOrder: next.length + 1));
    }
    final reindexed = next
        .asMap()
        .entries
        .map((e) => e.value.copyWith(stepOrder: e.key + 1))
        .toList();
    _state = _state.copyWith(tasks: reindexed);
    _editingTaskIndex = null;
    _draftTask = null;
    _draftTaskType = null;
  }

  String? _currentStepError() {
    switch (_step) {
      case _WizardStep.name:
        return QuestWizardLogic.validateName(_nameCtrl.text);
      case _WizardStep.about:
        return QuestWizardLogic.validateAbout(_descCtrl.text, _state.category);
      case _WizardStep.taskType:
        return QuestWizardLogic.isValidTaskType(_draftTaskType)
            ? null
            : 'Pick a task type.';
      case _WizardStep.taskWhere:
        final task = _draftTask;
        if (task == null) return 'Pick a location on the map.';
        final fence = QuestWizardLogic.fenceForTask(task, _spotLat, _spotLng);
        return QuestWizardLogic.validateTaskLocation(
          lat: fence.lat,
          lng: fence.lng,
          spotLat: _spot?.gpsLat,
          spotLng: _spot?.gpsLng,
        );
      case _WizardStep.taskDetails:
        final task = _draftTask;
        if (task == null) return 'Complete the task details.';
        return QuestWizardLogic.validateTaskDetails(task);
      case _WizardStep.taskList:
        return QuestWizardLogic.validateTaskList(_state.tasks);
      case _WizardStep.reward:
        return QuestWizardLogic.validateReward(_state.rewardPoints);
      case _WizardStep.review:
        return null;
    }
  }

  /// Auto-saves the draft silently on NEXT so leaving loses nothing.
  Future<void> _autoSaveDraft() async {
    if (_state.title.trim().isEmpty) return;
    final spotTarget = widget.spotSlug ?? _spot?.slug ?? _spot?.id ?? '';
    if (_effectiveQuestId == null && spotTarget.isEmpty) return;

    try {
      final repo = ref.read(questBuilderRepositoryProvider);
      if (_effectiveQuestId != null && _effectiveQuestId!.isNotEmpty) {
        final payload = _state.toPatchPayload(
          targetStatus: _state.status == 'published' ? 'published' : 'draft',
          expectedVersion: _state.version,
        );
        final newVersion = await repo.patchQuest(
          questId: _effectiveQuestId!,
          payload: payload,
        );
        if (mounted && newVersion != null) {
          setState(() => _state = _state.copyWith(version: newVersion));
        }
      } else {
        final payload = _state.toCreatePayload(targetStatus: 'draft');
        final createdId = await repo.createQuest(
          spotIdOrSlug: spotTarget,
          payload: payload,
        );
        if (mounted) {
          setState(() => _activeQuestId = createdId);
        }
      }
    } catch (_) {
      // Non-blocking auto-save; explicit Save Draft / Publish surfaces errors.
    }
  }

  Future<void> _handleNext() async {
    if (_currentStepError() != null) return;

    setState(() {
      _serverError = null;
      if (_step == _WizardStep.name) {
        _state = _state.copyWith(title: _nameCtrl.text.trim());
        _step = _WizardStep.about;
      } else if (_step == _WizardStep.about) {
        _state = _state.copyWith(description: _descCtrl.text.trim());
        if (_state.tasks.isEmpty) {
          _prepareNewTask();
          _step = _WizardStep.taskType;
        } else {
          _step = _WizardStep.taskList;
        }
      } else if (_step == _WizardStep.taskType) {
        _step = _WizardStep.taskWhere;
      } else if (_step == _WizardStep.taskWhere) {
        final type = _draftTaskType ?? 'location';
        if (QuestWizardLogic.needsTaskDetailsPage(type)) {
          _step = _WizardStep.taskDetails;
        } else {
          _commitDraftTaskToList();
          _step = _WizardStep.taskList;
        }
      } else if (_step == _WizardStep.taskDetails) {
        _commitDraftTaskToList();
        _step = _WizardStep.taskList;
      } else if (_step == _WizardStep.taskList) {
        _step = _WizardStep.reward;
      } else if (_step == _WizardStep.reward) {
        _step = _WizardStep.review;
      }
    });

    await _autoSaveDraft();
  }

  void _handleBack() {
    setState(() {
      _serverError = null;
      switch (_step) {
        case _WizardStep.name:
          Navigator.of(context).maybePop();
          break;
        case _WizardStep.about:
          _step = _WizardStep.name;
          break;
        case _WizardStep.taskType:
          _step = _state.tasks.isNotEmpty
              ? _WizardStep.taskList
              : _WizardStep.about;
          break;
        case _WizardStep.taskWhere:
          _step = _WizardStep.taskType;
          break;
        case _WizardStep.taskDetails:
          _step = _WizardStep.taskWhere;
          break;
        case _WizardStep.taskList:
          _step = _WizardStep.about;
          break;
        case _WizardStep.reward:
          _step = _WizardStep.taskList;
          break;
        case _WizardStep.review:
          _step = _WizardStep.reward;
          break;
      }
    });
  }

  Future<void> _handleSaveOrPublish(String targetStatus) async {
    final testState = _state.copyWith(status: targetStatus);
    final errors = validateQuestBuilder(testState);
    if (errors.isNotEmpty) {
      setState(() => _serverError = errors.first.message);
      return;
    }

    setState(() {
      _serverError = null;
      if (targetStatus == 'published') {
        _publishing = true;
      } else {
        _saving = true;
      }
    });

    try {
      final repo = ref.read(questBuilderRepositoryProvider);
      if (_effectiveQuestId != null && _effectiveQuestId!.isNotEmpty) {
        final payload = _state.toPatchPayload(
          targetStatus: targetStatus,
          expectedVersion: _state.version,
        );
        final newVersion = await repo.patchQuest(
          questId: _effectiveQuestId!,
          payload: payload,
        );
        if (mounted) {
          setState(() {
            _state = _state.copyWith(status: targetStatus, version: newVersion);
          });
          showPixelToast(
            context,
            targetStatus == 'published'
                ? tr(context, en: 'Quest published!', tl: 'Na-publish na ang quest!')
                : tr(context, en: 'Draft saved!', tl: 'Na-save ang draft!'),
          );
          if (targetStatus == 'published') {
            context.go('/quests/${_effectiveQuestId!}');
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
          setState(() => _activeQuestId = newQuestId);
          showPixelToast(
            context,
            targetStatus == 'published'
                ? tr(context, en: 'Quest created & published!', tl: 'Na-publish na ang quest!')
                : tr(context, en: 'Draft saved!', tl: 'Na-save ang draft!'),
          );
          if (targetStatus == 'published') {
            context.go('/quests/$newQuestId');
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      final failure = ApiFailure.from(
        e,
        fallback: tr(
          context,
          en: 'Could not save the quest. Please try again.',
          tl: 'Hindi na-save ang quest. Subukan muli.',
        ),
      );
      setState(() {
        _serverError = switch (failure.code) {
          'DESTINATION_OWNER_ONLY' =>
            'Only the person who posted this destination can add quests to it.',
          'DESTINATION_NOT_PUBLISHED' =>
            'You can add quests here once this place is published.',
          'FORBIDDEN_NOT_DESTINATION_AUTHOR' =>
            'Only the person who posted this destination can add quests to it.',
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

  void _openPartnersSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PixelPalette.paper,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: PixelSectionTitle(
                        tr(context, en: 'ADD PARTNERS', tl: 'MAGDAGDAG NG PARTNER'),
                        colors: PixelText3DColors.gold,
                      ),
                    ),
                    PixelButton(
                      label: tr(context, en: 'CLOSE', tl: 'ISARA'),
                      variant: PixelButtonVariant.ghost,
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                NearbyMerchantsSection(
                  questId: _effectiveQuestId,
                  pinLat: _spotLat,
                  pinLng: _spotLng,
                  onInvitesChanged: (invites) {
                    if (mounted) setState(() => _sponsorInvites = invites);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
                              tr(
                                context,
                                en: 'Could not load the quest builder',
                                tl: 'Hindi ma-load ang quest builder',
                              ),
                              style: PixelType.title(context),
                            ),
                            SizedBox(height: grid.px(2)),
                            Text(
                              _initError!,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.slate,
                              ),
                            ),
                            SizedBox(height: grid.px(3)),
                            PixelButton(
                              label: tr(context, en: 'RETRY', tl: 'ULITIN'),
                              variant: PixelButtonVariant.primary,
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

    final grid = PixelGrid.of(context);
    final stepError = _currentStepError();

    return Theme(
      data: AppTheme.pixel,
      child: Scaffold(
        backgroundColor: PixelPalette.paper,
        body: DitherBackground(
          top: PixelPalette.paper,
          bottom: PixelPalette.parchment,
          child: SafeArea(
            child: Column(
              children: [
                PixelAppBar(
                  title: isEditMode
                      ? tr(context, en: 'EDIT QUEST', tl: 'I-EDIT ANG QUEST')
                      : tr(context, en: 'NEW QUEST', tl: 'BAGONG QUEST'),
                  onBack: () => Navigator.of(context).maybePop(),
                  actions: [
                    Padding(
                      padding: EdgeInsets.only(right: grid.px(1)),
                      child: Center(
                        child: Text(
                          '$_displayPageNumber / ${QuestWizardLogic.totalPages}',
                          key: const Key('quest_wizard_progress'),
                          style: PixelType.title(
                            context,
                            color: PixelPalette.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(grid.px(3)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_serverError != null) ...[
                          PixelPanel(
                            key: const Key('quest_wizard_error_panel'),
                            style: PixelBoxStyle.parchment,
                            child: Text(
                              _serverError!,
                              style: PixelType.body(
                                context,
                                color: PixelPalette.red,
                              ),
                            ),
                          ),
                          SizedBox(height: grid.px(2)),
                        ],
                        PixelPanel(
                          child: _buildStepPanel(context, stepError),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(context, stepError),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepPanel(BuildContext context, String? stepError) {
    final grid = PixelGrid.of(context);
    switch (_step) {
      case _WizardStep.name:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: "WHAT'S YOUR QUEST CALLED?", tl: 'ANO ANG PAMAGAT NG QUEST?'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              key: const Key('wizard_name_input'),
              controller: _nameCtrl,
              label: tr(context, en: 'Quest name (3–60 chars)', tl: 'Pangalan ng quest (3–60 letra)'),
              onChanged: (v) => setState(() {
                _state = _state.copyWith(title: v.trim());
              }),
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.about:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'WHAT WILL TRAVELERS DO?', tl: 'ANO ANG GAGAWIN NG MANLALAKBAY?'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            PixelTextField(
              key: const Key('wizard_about_input'),
              controller: _descCtrl,
              label: tr(context, en: 'Short summary (10–280 chars)', tl: 'Maikling paglalarawan (10–280 letra)'),
              maxLines: 3,
              onChanged: (v) => setState(() {
                _state = _state.copyWith(description: v.trim());
              }),
            ),
            SizedBox(height: grid.px(2)),
            Text(
              tr(context, en: 'Category', tl: 'Kategorya'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            DropdownButtonFormField<String>(
              key: const Key('wizard_category_dropdown'),
              initialValue: _state.category,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              items: questCategories
                  .map(
                    (c) => DropdownMenuItem(
                      value: c.value,
                      child: Text(c.label, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                if (v != null) {
                  setState(() => _state = _state.copyWith(category: v));
                }
              },
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.taskType:
        final chips = <MapEntry<String, String>>[
          MapEntry('location', tr(context, en: 'Arrive', tl: 'Dumating')),
          MapEntry('qr', tr(context, en: 'Scan QR', tl: 'Mag-scan ng QR')),
          MapEntry('photo', tr(context, en: 'Photo', tl: 'Larawan')),
          MapEntry('ar', tr(context, en: 'AR', tl: 'AR')),
          MapEntry('action', tr(context, en: 'Action', tl: 'Aksyon')),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'PICK A TASK TYPE', tl: 'PUMILI NG URI NG TASK'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(1.5),
              runSpacing: grid.px(1.5),
              children: [
                for (final chip in chips)
                  PixelButton(
                    key: Key('wizard_task_type_${chip.key}'),
                    label: chip.value,
                    variant: _draftTaskType == chip.key
                        ? PixelButtonVariant.primary
                        : PixelButtonVariant.secondary,
                    onPressed: () => _selectTaskType(chip.key),
                  ),
              ],
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1.5)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.taskWhere:
        final task = _draftTask ??
            QuestWizardLogic.buildDefaultTask(
              type: _draftTaskType ?? 'location',
              stepOrder: _state.tasks.length + 1,
              lat: _spotLat,
              lng: _spotLng,
              spotName: _spotName,
              spotId: _spot?.id,
            );
        _draftTask = task;
        final fence = QuestWizardLogic.fenceForTask(task, _spotLat, _spotLng);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'WHERE IS THIS TASK?', tl: 'SAAN ANG TASK NA ITO?'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(1.5)),
            Text(
              tr(
                context,
                en: 'Drag the map under the pin.',
                tl: 'I-drag ang mapa sa ilalim ng pin.',
              ),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1.5)),
            LocationFenceMapPicker(
              fence: fence,
              pinLabel: tr(context, en: 'Task pin', tl: 'Pin ng task'),
              onChanged: (nextFence) {
                setState(() {
                  _draftTask = QuestWizardLogic.withFence(task, nextFence);
                });
              },
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.taskDetails:
        return _buildTaskDetailsStep(context, stepError);

      case _WizardStep.taskList:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'QUEST TASKS', tl: 'MGA TASK NG QUEST'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            if (_state.tasks.isEmpty)
              Text(
                tr(context, en: 'No tasks yet.', tl: 'Wala pang task.'),
                style: PixelType.body(context, color: PixelPalette.slate),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _state.tasks.length,
                onReorder: (oldIndex, newIndex) {
                  setState(() {
                    var target = newIndex;
                    if (target > oldIndex) target -= 1;
                    final next = [..._state.tasks];
                    final moved = next.removeAt(oldIndex);
                    next.insert(target, moved);
                    _state = _state.copyWith(
                      tasks: next
                          .asMap()
                          .entries
                          .map((e) => e.value.copyWith(stepOrder: e.key + 1))
                          .toList(),
                    );
                  });
                },
                itemBuilder: (context, idx) {
                  final t = _state.tasks[idx];
                  return Padding(
                    key: ValueKey('wizard_task_row_${t.key}_$idx'),
                    padding: EdgeInsets.only(bottom: grid.px(1.5)),
                    child: PixelPanel(
                      style: PixelBoxStyle.parchment,
                      child: Row(
                        children: [
                          const Icon(Icons.drag_handle, size: 18),
                          SizedBox(width: grid.px(1)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${idx + 1}. ${t.title}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: PixelType.body(context)
                                      .copyWith(fontWeight: FontWeight.w700),
                                ),
                                Text(
                                  t.checkpointType.toUpperCase(),
                                  style: PixelType.small(
                                    context,
                                    color: PixelPalette.slate,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            key: Key('wizard_task_edit_$idx'),
                            tooltip: tr(context, en: 'Edit task', tl: 'I-edit'),
                            icon: const Text('✎'),
                            onPressed: () {
                              setState(() {
                                _prepareEditTask(idx);
                                _step = _WizardStep.taskType;
                              });
                            },
                          ),
                          IconButton(
                            key: Key('wizard_task_delete_$idx'),
                            tooltip: tr(context, en: 'Delete task', tl: 'Burahin'),
                            icon: const Text('✕'),
                            onPressed: () {
                              setState(() {
                                final next = [..._state.tasks]..removeAt(idx);
                                _state = _state.copyWith(
                                  tasks: next
                                      .asMap()
                                      .entries
                                      .map((e) =>
                                          e.value.copyWith(stepOrder: e.key + 1))
                                      .toList(),
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            SizedBox(height: grid.px(1.5)),
            if (_state.tasks.length < 10)
              PixelButton(
                key: const Key('wizard_add_another_task_btn'),
                label: tr(
                  context,
                  en: '+ ADD ANOTHER TASK',
                  tl: '+ MAGDAGDAG NG TASK',
                ),
                variant: PixelButtonVariant.secondary,
                expand: true,
                onPressed: () {
                  setState(() {
                    _prepareNewTask();
                    _step = _WizardStep.taskType;
                  });
                },
              ),
            SizedBox(height: grid.px(2)),
            Text(
              tr(context, en: 'Task order', tl: 'Pagkakasunod-sunod'),
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
            SizedBox(height: grid.px(1)),
            Wrap(
              spacing: grid.px(1.5),
              runSpacing: grid.px(1),
              children: [
                PixelButton(
                  key: const Key('wizard_order_sequential'),
                  label: tr(context, en: 'In order', tl: 'Sunod-sunod'),
                  variant: _state.stepOrderMode == 'sequential'
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () => setState(
                    () => _state = _state.copyWith(stepOrderMode: 'sequential'),
                  ),
                ),
                PixelButton(
                  key: const Key('wizard_order_any'),
                  label: tr(context, en: 'Any order', tl: 'Kahit anong sunod'),
                  variant: _state.stepOrderMode == 'any'
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () => setState(
                    () => _state = _state.copyWith(stepOrderMode: 'any'),
                  ),
                ),
              ],
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.reward:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'CHOOSE A REWARD', tl: 'PUMILI NG REWARD'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            Wrap(
              spacing: grid.px(1.5),
              runSpacing: grid.px(1.5),
              children: [
                for (final pts in [50, 75, 100])
                  PixelButton(
                    key: Key('wizard_reward_$pts'),
                    label: '$pts pts',
                    variant: _state.rewardPoints == pts
                        ? PixelButtonVariant.primary
                        : PixelButtonVariant.secondary,
                    onPressed: () => setState(
                      () => _state = _state.copyWith(rewardPoints: pts),
                    ),
                  ),
              ],
            ),
            if (stepError != null) ...[
              SizedBox(height: grid.px(1.5)),
              Text(
                stepError,
                key: const Key('wizard_field_error'),
                style: PixelType.small(context, color: PixelPalette.red),
              ),
            ],
          ],
        );

      case _WizardStep.review:
        final nameOk = QuestWizardLogic.validateName(_state.title) == null;
        final tasksOk = _state.tasks.isNotEmpty;
        final rewardOk =
            QuestWizardLogic.validateReward(_state.rewardPoints) == null;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PixelSectionTitle(
              tr(context, en: 'CHECK & PUBLISH', tl: 'SURIIN AT I-PUBLISH'),
              colors: PixelText3DColors.gold,
            ),
            SizedBox(height: grid.px(2)),
            QuestTravelerPreviewCard(
              state: _state,
              locationName: _spotName,
              sponsorInvites: _sponsorInvites,
            ),
            SizedBox(height: grid.px(2)),
            _ChecklistTile(
              key: const Key('wizard_check_name'),
              ok: nameOk,
              label: tr(
                context,
                en: 'Name: ${_state.title.isEmpty ? "Missing" : _state.title}',
                tl: 'Pangalan: ${_state.title.isEmpty ? "Kulang" : _state.title}',
              ),
              onTap: () => setState(() => _step = _WizardStep.name),
            ),
            _ChecklistTile(
              key: const Key('wizard_check_tasks'),
              ok: tasksOk,
              label: tr(
                context,
                en: '${_state.tasks.length} ${_state.tasks.length == 1 ? "task" : "tasks"}',
                tl: '${_state.tasks.length} na task',
              ),
              onTap: () => setState(() => _step = _WizardStep.taskList),
            ),
            _ChecklistTile(
              key: const Key('wizard_check_reward'),
              ok: rewardOk,
              label: tr(
                context,
                en: 'Reward: ${_state.rewardPoints} points',
                tl: 'Reward: ${_state.rewardPoints} puntos',
              ),
              onTap: () => setState(() => _step = _WizardStep.reward),
            ),
            SizedBox(height: grid.px(2)),
            PixelButton(
              key: const Key('wizard_add_partners_btn'),
              label: tr(context, en: 'ADD PARTNERS', tl: 'MAGDAGDAG NG PARTNER'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _openPartnersSheet,
            ),
          ],
        );
    }
  }

  Widget _buildTaskDetailsStep(BuildContext context, String? stepError) {
    final grid = PixelGrid.of(context);
    final task = _draftTask!;
    final type = task.checkpointType;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PixelSectionTitle(
          tr(context, en: 'TASK DETAILS', tl: 'DETALYE NG TASK'),
          colors: PixelText3DColors.gold,
        ),
        SizedBox(height: grid.px(2)),
        if (type == 'qr') ...[
          Text(
            tr(context, en: 'Scan mode', tl: 'Paraan ng pag-scan'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1.5),
            runSpacing: grid.px(1),
            children: [
              for (final mode in const [
                MapEntry('traveler_scans', 'Traveler scans QR'),
                MapEntry('host_scans_traveler', 'Host scans traveler'),
              ])
                PixelButton(
                  label: mode.value,
                  variant: (task.verification is QrVerification &&
                          (task.verification as QrVerification).scanMode ==
                              mode.key)
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () {
                    final qr = task.verification as QrVerification;
                    setState(() {
                      _draftTask = task.copyWith(
                        verification: QrVerification(
                          fence: qr.fence,
                          markerCode: qr.markerCode,
                          scanMode: mode.key,
                        ),
                      );
                    });
                  },
                ),
            ],
          ),
        ] else if (type == 'photo') ...[
          PixelTextField(
            key: const Key('wizard_photo_prompt_input'),
            controller: _photoPromptCtrl,
            label: tr(
              context,
              en: 'What should travelers photograph?',
              tl: 'Ano ang kukunan ng larawan?',
            ),
            maxLines: 2,
            onChanged: (v) {
              final pv = task.verification as PhotoVerification;
              setState(() {
                _draftTask = task.copyWith(
                  verification: PhotoVerification(
                    prompt: v,
                    fence: pv.fence,
                    requireGps: pv.requireGps,
                  ),
                );
              });
            },
          ),
        ] else if (type == 'ar') ...[
          Text(
            tr(context, en: '3D Object', tl: '3D na Bagay'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final obj in _kArObjects)
                PixelButton(
                  label: obj.value,
                  variant: (task.verification is ArVerification &&
                          (task.verification as ArVerification).object ==
                              obj.key)
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () {
                    final ar = task.verification as ArVerification;
                    setState(() {
                      _draftTask = task.copyWith(
                        verification: ar.copyWith(object: obj.key),
                      );
                    });
                  },
                ),
            ],
          ),
          SizedBox(height: grid.px(2)),
          Text(
            tr(context, en: 'Colour', tl: 'Kulay'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final c in _kArColors)
                PixelButton(
                  label: c.value,
                  variant: (task.verification is ArVerification &&
                          (task.verification as ArVerification).color == c.key)
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () {
                    final ar = task.verification as ArVerification;
                    setState(() {
                      _draftTask = task.copyWith(
                        verification: ar.copyWith(color: c.key),
                      );
                    });
                  },
                ),
            ],
          ),
        ] else if (type == 'action') ...[
          Text(
            tr(context, en: 'Action type', tl: 'Uri ng aksyon'),
            style: PixelType.small(context, color: PixelPalette.slate),
          ),
          SizedBox(height: grid.px(1)),
          Wrap(
            spacing: grid.px(1),
            runSpacing: grid.px(1),
            children: [
              for (final kind in const [
                MapEntry('save_spot', 'Save place'),
                MapEntry('like_spot', 'Like place'),
                MapEntry('complete_quiz', 'Complete quiz'),
              ])
                PixelButton(
                  label: kind.value,
                  variant: (task.verification is ActionVerification &&
                          (task.verification as ActionVerification)
                                  .task['kind'] ==
                              kind.key)
                      ? PixelButtonVariant.primary
                      : PixelButtonVariant.secondary,
                  onPressed: () {
                    setState(() {
                      _draftTask = task.copyWith(
                        verification: ActionVerification(
                          task: {
                            'kind': kind.key,
                            if (kind.key == 'save_spot' ||
                                kind.key == 'like_spot')
                              'spot_id': _spot?.id ?? 'spot-local',
                            if (kind.key == 'complete_quiz')
                              'quiz_id': _actionQuizIdCtrl.text.trim(),
                          },
                        ),
                      );
                    });
                  },
                ),
            ],
          ),
          if (task.verification is ActionVerification &&
              (task.verification as ActionVerification).task['kind'] ==
                  'complete_quiz') ...[
            SizedBox(height: grid.px(1.5)),
            PixelTextField(
              controller: _actionQuizIdCtrl,
              label: tr(context, en: 'Quiz ID', tl: 'Quiz ID'),
              onChanged: (v) {
                setState(() {
                  _draftTask = task.copyWith(
                    verification: ActionVerification(
                      task: {'kind': 'complete_quiz', 'quiz_id': v.trim()},
                    ),
                  );
                });
              },
            ),
          ],
        ],
        if (stepError != null) ...[
          SizedBox(height: grid.px(1.5)),
          Text(
            stepError,
            key: const Key('wizard_field_error'),
            style: PixelType.small(context, color: PixelPalette.red),
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, String? stepError) {
    final grid = PixelGrid.of(context);
    final busy = _saving || _publishing;

    if (_step == _WizardStep.review) {
      return Container(
        padding: EdgeInsets.all(grid.px(2.5)),
        decoration: const BoxDecoration(
          color: PixelPalette.parchment,
          border: Border(top: BorderSide(color: PixelPalette.ink, width: 2)),
        ),
        child: Wrap(
          spacing: grid.px(1.5),
          runSpacing: grid.px(1.5),
          alignment: WrapAlignment.spaceBetween,
          children: [
            PixelButton(
              key: const Key('wizard_back_btn'),
              label: tr(context, en: 'BACK', tl: 'BALIK'),
              variant: PixelButtonVariant.ghost,
              onPressed: busy ? null : _handleBack,
            ),
            PixelButton(
              key: const Key('wizard_save_draft_btn'),
              label: _saving
                  ? tr(context, en: 'SAVING…', tl: 'SINE-SAVE…')
                  : tr(context, en: 'SAVE DRAFT', tl: 'I-SAVE DRAFT'),
              variant: PixelButtonVariant.secondary,
              onPressed: busy ? null : () => _handleSaveOrPublish('draft'),
            ),
            PixelButton(
              key: const Key('wizard_publish_btn'),
              label: _publishing
                  ? tr(context, en: 'PUBLISHING…', tl: 'PINA-PUBLISH…')
                  : tr(context, en: 'PUBLISH', tl: 'I-PUBLISH'),
              variant: PixelButtonVariant.primary,
              onPressed: busy ? null : () => _handleSaveOrPublish('published'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(grid.px(2.5)),
      decoration: const BoxDecoration(
        color: PixelPalette.parchment,
        border: Border(top: BorderSide(color: PixelPalette.ink, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: PixelButton(
              key: const Key('wizard_back_btn'),
              label: tr(context, en: 'BACK', tl: 'BALIK'),
              variant: PixelButtonVariant.secondary,
              expand: true,
              onPressed: _handleBack,
            ),
          ),
          SizedBox(width: grid.px(2)),
          Expanded(
            child: PixelButton(
              key: const Key('wizard_next_btn'),
              label: tr(context, en: 'NEXT', tl: 'SUNOD'),
              variant: PixelButtonVariant.primary,
              expand: true,
              onPressed: stepError == null ? _handleNext : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    super.key,
    required this.ok,
    required this.label,
    required this.onTap,
  });

  final bool ok;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final grid = PixelGrid.of(context);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: grid.px(1)),
        child: Row(
          children: [
            Text(
              ok ? '✓' : '!',
              style: PixelType.body(
                context,
                color: ok ? PixelPalette.greenBright : PixelPalette.red,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            SizedBox(width: grid.px(1.5)),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: PixelType.body(context, color: PixelPalette.ink),
              ),
            ),
            Text(
              '✎',
              style: PixelType.small(context, color: PixelPalette.slate),
            ),
          ],
        ),
      ),
    );
  }
}
