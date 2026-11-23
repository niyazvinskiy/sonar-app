import 'dart:async';

enum RecoveryConnection { unavailable, disconnected, connecting, connected, disconnecting }

bool shouldStartSonarRecovery({
  required bool autoConnect,
  required bool? wanted,
  required String? previousBoot,
  required String? currentBoot,
}) {
  if (!autoConnect) return false;
  final newBoot = currentBoot != null && previousBoot != null && currentBoot != previousBoot;
  return newBoot || (wanted ?? true);
}

/// Owns the connection intent independently of the native core's transient state.
class ConnectionRecovery {
  ConnectionRecovery({
    required this.prepare,
    required this.connect,
    required this.disconnect,
    required this.saveWanted,
    required this.onChanged,
  });

  final Future<bool> Function() prepare;
  final Future<void> Function() connect;
  final Future<void> Function() disconnect;
  final Future<void> Function(bool) saveWanted;
  final void Function() onChanged;
  bool wanted = false;
  bool paused = false;
  int failures = 0;
  RecoveryConnection _connection = RecoveryConnection.unavailable;
  Timer? _retry;
  bool _preparing = false;
  bool _submitted = false;
  bool _stopping = false;
  bool _enforceStop = false;
  bool _disposed = false;
  int _generation = 0;
  Future<void> _writes = Future.value();

  bool get retryScheduled => _retry != null;
  bool get _active => !_disposed && wanted && !paused;

  void update(RecoveryConnection connection) {
    if (_disposed) return;
    final previous = _connection;
    _connection = connection;
    if (connection == RecoveryConnection.connected) {
      _submitted = false;
      failures = 0;
      _cancelRetry();
    } else if (connection == RecoveryConnection.disconnected) {
      if (_submitted || previous == RecoveryConnection.connected || previous == RecoveryConnection.connecting) {
        failures++;
      }
      _submitted = false;
      _schedule(immediate: failures == 0);
    } else if (connection == RecoveryConnection.unavailable) {
      _submitted = false;
      _cancelRetry();
    }
    if (_enforceStop &&
        !_active &&
        (connection == RecoveryConnection.connected || connection == RecoveryConnection.connecting)) {
      unawaited(_abort().catchError((Object _) {}));
    }
    _notify();
  }

  Future<void> _save(bool value) {
    // Keep rapid stop/start writes in the same order as the user's actions.
    final next = _writes.then((_) => saveWanted(value));
    _writes = next.catchError((Object _) {});
    return next;
  }

  Future<void> start() async {
    if (_disposed) return;
    if (!wanted) {
      _generation++;
      failures = 0;
    }
    wanted = true;
    _enforceStop = paused;
    _notify();
    final generation = _generation;
    await _save(true);
    if (generation == _generation) _schedule(immediate: true);
  }

  Future<void> stop() async {
    if (_disposed) return;
    wanted = false;
    _enforceStop = true;
    _generation++;
    _cancelRetry();
    _notify();
    await Future.wait([_save(false), _abort()]);
  }

  /// Suspend native work for an installer without changing next-start intent.
  Future<void> pause() async {
    paused = true;
    _enforceStop = true;
    _generation++;
    _cancelRetry();
    _notify();
    await _abort();
  }

  void resume() {
    if (_disposed) return;
    paused = false;
    _enforceStop = !wanted;
    _schedule(immediate: true);
    _notify();
  }

  Future<void> _abort() async {
    if (_disposed || _stopping) return;
    if (_connection != RecoveryConnection.connecting && _connection != RecoveryConnection.connected) return;
    _stopping = true;
    try {
      await disconnect();
    } finally {
      _stopping = false;
    }
  }

  void _schedule({bool immediate = false}) {
    if (!_active || _preparing || _submitted || _retry != null || _connection != RecoveryConnection.disconnected) {
      return;
    }
    if (immediate) {
      unawaited(_attempt());
      return;
    }
    const seconds = [2, 4, 8, 16, 30];
    final index = (failures - 1).clamp(0, seconds.length - 1);
    _retry = Timer(Duration(seconds: seconds[index]), () {
      _retry = null;
      unawaited(_attempt());
      _notify();
    });
    _notify();
  }

  Future<void> _attempt() async {
    if (!_active || _preparing || _submitted || _connection != RecoveryConnection.disconnected) return;
    _preparing = true;
    final generation = _generation;
    try {
      final ready = await prepare();
      if (!_active || generation != _generation || _connection != RecoveryConnection.disconnected) return;
      if (!ready) {
        failures++;
        return;
      }
      _submitted = true;
      await connect();
    } catch (_) {
      if (generation == _generation && _active) {
        _submitted = false;
        failures++;
      }
    } finally {
      _preparing = false;
      if (_active) _schedule(immediate: generation != _generation);
      _notify();
    }
  }

  void _cancelRetry() {
    _retry?.cancel();
    _retry = null;
  }

  void _notify() {
    if (!_disposed) onChanged();
  }

  void dispose() {
    _disposed = true;
    _generation++;
    _cancelRetry();
  }
}
