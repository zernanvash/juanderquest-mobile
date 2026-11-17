import 'builder_models.dart';

class ValidationError {
  final String field;
  final String message;
  final int? taskIndex;

  const ValidationError({
    required this.field,
    required this.message,
    this.taskIndex,
  });

  @override
  String toString() =>
      'ValidationError(field: $field, message: $message, taskIndex: $taskIndex)';
}

List<ValidationError> validateQuestBuilder(QuestBuilderState state) {
  final errors = <ValidationError>[];

  // Plan 56: a draft saves with any title; publishing needs the checklist
  // (same limits as the server's publishChecklist: title 5+, description 15+).
  final publishing = state.status == 'published';
  final title = state.title.trim();
  if (title.isEmpty) {
    errors.add(const ValidationError(
        field: 'title', message: 'Give your quest a title.'));
  } else if (title.length > 100) {
    errors.add(const ValidationError(
        field: 'title', message: 'Title cannot exceed 100 characters.'));
  } else if (publishing && title.length < 5) {
    errors.add(const ValidationError(
        field: 'title',
        message: 'To publish: title needs at least 5 characters.'));
  }

  if (publishing && state.description.trim().length < 15) {
    errors.add(const ValidationError(
        field: 'description',
        message: 'To publish: description needs at least 15 characters.'));
  }

  if (state.tasks.length > 10) {
    errors.add(const ValidationError(
        field: 'tasks', message: 'A quest cannot have more than 10 tasks.'));
  }

  if (state.status == 'published') {
    if (state.tasks.isEmpty) {
      errors.add(const ValidationError(
          field: 'tasks',
          message: 'At least one task is required to publish.'));
    } else {
      final hasRequired = state.tasks.any((t) => t.required);
      if (!hasRequired) {
        errors.add(const ValidationError(
            field: 'tasks',
            message:
                'At least one task must be marked as required to publish.'));
      }
    }
  }

  for (var idx = 0; idx < state.tasks.length; idx++) {
    final task = state.tasks[idx];

    if (task.title.trim().isEmpty || task.title.trim().length < 3) {
      errors.add(ValidationError(
        field: 'tasks.$idx.title',
        message: 'Task title must be at least 3 characters.',
        taskIndex: idx,
      ));
    }

    if (task.description.trim().isEmpty || task.description.trim().length < 5) {
      errors.add(ValidationError(
        field: 'tasks.$idx.description',
        message: 'Task instructions must be at least 5 characters.',
        taskIndex: idx,
      ));
    }

    if (task.checkpointType == 'photo') {
      final ver = task.verification;
      if (ver is PhotoVerification) {
        if (ver.prompt.trim().isEmpty || ver.prompt.trim().length < 5) {
          errors.add(ValidationError(
            field: 'tasks.$idx.prompt',
            message: 'Photo prompt must be at least 5 characters.',
            taskIndex: idx,
          ));
        }
      }
    }

    if (task.checkpointType == 'action') {
      final ver = task.verification;
      if (ver is ActionVerification) {
        final kind = ver.task['kind'] as String?;
        if (kind == 'complete_quiz') {
          final quizId = ver.task['quiz_id'] as String?;
          if (quizId == null || quizId.trim().isEmpty) {
            errors.add(ValidationError(
              field: 'tasks.$idx.quiz_id',
              message: 'Please select a cultural quiz.',
              taskIndex: idx,
            ));
          }
        }
        if (kind == 'save_spot' || kind == 'like_spot') {
          final spotId = ver.task['spot_id'] as String?;
          if (spotId == null || spotId.trim().isEmpty) {
            errors.add(ValidationError(
              field: 'tasks.$idx.spot_id',
              message: 'Please select a destination spot.',
              taskIndex: idx,
            ));
          }
        }
      }
    }
  }

  return errors;
}
