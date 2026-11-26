import 'dart:async';

/// Plan 123b: batches Explore spot impressions for signed-in users.
///
/// A spot is queued after remaining >= 50% visible for >= 1 s, and flushed
/// every 5 s, at 10 queued IDs, or on app pause (fire-and-forget, no retries).
class ExploreImpressionBatcher {
  static const Duration dwellDuration = Duration(seconds: 1);
  static const Duration flushInterval = Duration(seconds: 5);
  static const int maxBatchBeforeFlush = 10;
  static const int maxRequestBatchSize = 30;

  final bool Function() _isAuthenticated;
  final Future<void> Function(List<String> spotIds) _sendBatch;

  final Map<String, Timer> _dwellTimers = <String, Timer>{};
  final Set<String> _queuedIds = <String>{};
  final Set<String> _reportedIds = <String>{};
  Timer? _flushTimer;

  ExploreImpressionBatcher({
    required bool Function() isAuthenticated,
    required Future<void> Function(List<String> spotIds) sendBatch,
  })  : _isAuthenticated = isAuthenticated,
        _sendBatch = sendBatch;

  int get queuedCount => _queuedIds.length;
  int get pendingDwellCount => _dwellTimers.length;

  void onVisibilityChanged(String spotId, double visibleFraction) {
    if (spotId.isEmpty || !_isAuthenticated()) return;
    if (visibleFraction >= 0.5) {
      if (_reportedIds.contains(spotId) ||
          _queuedIds.contains(spotId) ||
          _dwellTimers.containsKey(spotId)) {
        return;
      }
      _dwellTimers[spotId] = Timer(dwellDuration, () => _enqueue(spotId));
    } else {
      _dwellTimers.remove(spotId)?.cancel();
    }
  }

  void _enqueue(String spotId) {
    _dwellTimers.remove(spotId);
    if (!_isAuthenticated() || _reportedIds.contains(spotId)) return;
    if (!_queuedIds.add(spotId)) return;

    if (_queuedIds.length >= maxBatchBeforeFlush) {
      flush();
    } else {
      _flushTimer ??= Timer(flushInterval, flush);
    }
  }

  void flush() {
    _flushTimer?.cancel();
    _flushTimer = null;
    if (_queuedIds.isEmpty) return;
    if (!_isAuthenticated()) {
      _queuedIds.clear();
      return;
    }

    final batch = _queuedIds.take(maxRequestBatchSize).toList(growable: false);
    for (final id in batch) {
      _queuedIds.remove(id);
      _reportedIds.add(id);
    }

    // Fire-and-forget; never retry on failure.
    unawaited(_sendBatch(batch).then((_) {}, onError: (_) {}));

    if (_queuedIds.isNotEmpty) {
      _flushTimer = Timer(flushInterval, flush);
    }
  }

  void onAppPaused() {
    flush();
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    for (final timer in _dwellTimers.values) {
      timer.cancel();
    }
    _dwellTimers.clear();
    _queuedIds.clear();
  }
}
