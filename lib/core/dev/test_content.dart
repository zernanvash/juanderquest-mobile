import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Owner 2026-11-05 (Plan 75n): QA/test content (quests and spots the server
/// marks `is_test`, e.g. "SIM ·" quests, the ARTEST spot) is hidden from
/// travelers. Settings → Developer tools → "Show test content" brings it back
/// for testing. Session-only on purpose: it resets to hidden on restart.
final showTestContentProvider = StateProvider<bool>((ref) => false);

/// Drops test items unless the developer switch is on.
List<T> withoutTestContent<T>(
  List<T> items,
  bool Function(T item) isTest, {
  required bool showTest,
}) =>
    showTest ? items : items.where((item) => !isTest(item)).toList();
