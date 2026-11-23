import 'dart:async';

import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Порядок для автовыбора по замеру 22.10.2026 (UDP, как голос Discord, из сети
/// Никиты): XHTTP на 443 96 мс без потерь, XHTTP на 8443 109 мс, Hysteria 193–372 мс
/// и до 6% потерь, провайдеры притормаживают UDP до зарубежных серверов.
int _rank(OutboundInfo o) {
  final name = o.tagDisplay.isNotEmpty ? o.tagDisplay : o.tag;
  if (name.contains('Основной')) return 0;
  if (name.contains('UDP') || name.contains('Игры')) return 2;
  if (name.contains('Запасной')) return 1;
  return 3;
}

/// Каналы подписки без групп ядра, в порядке автовыбора.
List<OutboundInfo> sonarChannels(OutboundGroup g) =>
    g.items.where((o) => !o.isGroup && o.isVisible).toList()..sort((a, b) => _rank(a).compareTo(_rank(b)));

class SonarChannelState {
  const SonarChannelState({this.auto = true, this.current = ''});

  /// true: канал выбирает Sonar; false: человек выбрал канал руками
  final bool auto;

  /// тег канала, через который сейчас идёт трафик
  final String current;
}

/// Автовыбор канала Sonar вместо групп ядра Hiddify.
///
/// Ядро по умолчанию раскидывает соединения по всем каналам по очереди (round-robin)
/// и рвёт открытые соединения при каждой смене. 22.10.2026 из-за этого пропадал голос
/// в Discord, а задушенный провайдером канал портил каждое третье соединение. Здесь
/// Sonar держит один канал и переходит на следующий, только когда текущий три раза
/// подряд не ответил на проверку. На лучший канал обратно не прыгает, пока текущий
/// живой: звонок и игра важнее лишних миллисекунд.
class SonarChannelGuard extends Notifier<SonarChannelState> {
  static const _prefKey = 'sonar_channel';
  static const _every = Duration(minutes: 1);

  Timer? _timer;
  Timer? _firstCheck;
  Timer? _probeTimer;
  Completer<void>? _probeFinished;
  int _fails = 0;
  bool _busy = false;
  bool _checking = false;
  bool _disposed = false;
  bool _applyPending = false;
  bool _forcePending = false;
  int _session = 0;
  int _revision = 0;

  @override
  SonarChannelState build() {
    ref.onDispose(() {
      _disposed = true;
      _stop();
    });
    ref.listen(connectionNotifierProvider, (previous, next) {
      if (next.valueOrNull is Connected && !next.hasError) {
        if (previous?.valueOrNull is! Connected) _start();
      } else {
        _stop();
      }
    }, fireImmediately: true);
    ref.listen(proxiesOverviewNotifierProvider, (_, next) {
      final g = next.valueOrNull;
      if (g != null) unawaited(_apply(g));
    });
    final manual = ref.read(sharedPreferencesProvider).valueOrNull?.getString(_prefKey) ?? '';
    return SonarChannelState(auto: manual.isEmpty);
  }

  void _start() {
    _stop();
    // Первая проверка вскоре после подключения, дальше раз в минуту
    _firstCheck = Timer(const Duration(seconds: 6), () => unawaited(_check()));
    _timer = Timer.periodic(_every, (_) => unawaited(_check()));
  }

  void _stop() {
    _session++;
    _timer?.cancel();
    _firstCheck?.cancel();
    _probeTimer?.cancel();
    final finished = _probeFinished;
    if (finished != null && !finished.isCompleted) finished.complete();
    _probeFinished = null;
    _fails = 0;
  }

  String get _manual => ref.read(sharedPreferencesProvider).valueOrNull?.getString(_prefKey) ?? '';

  /// Выбор из окна каналов: '' — снова автовыбор.
  Future<void> choose(String tag) async {
    _revision++;
    final prefs = await ref.read(sharedPreferencesProvider.future);
    if (_disposed) return;
    await prefs.setString(_prefKey, tag);
    if (_disposed) return;
    state = SonarChannelState(auto: tag.isEmpty, current: state.current);
    _fails = 0;
    final g = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    if (g != null) await _apply(g, force: true);
  }

  Future<bool> _select(OutboundGroup g, String tag) async {
    if (g.selected == tag) return true;
    final result = await ref.read(proxyRepositoryProvider).selectProxy(g.tag, tag).run();
    return result.isRight();
  }

  /// Держит выбранный канал: руками выбранный, а при автовыборе первый живой по порядку.
  Future<void> _apply(OutboundGroup g, {bool force = false}) async {
    if (_disposed || ref.read(connectionNotifierProvider).valueOrNull is! Connected) return;
    if (_busy) {
      _applyPending = true;
      _forcePending = _forcePending || force;
      return;
    }
    final channels = sonarChannels(g);
    if (channels.isEmpty) return;
    _busy = true;
    final revision = _revision;
    final session = _session;
    try {
      final manual = _manual;
      final pinned = channels.where((o) => o.tag == manual).firstOrNull;
      if (pinned != null) {
        if (await _select(g, pinned.tag) && _current(session, revision)) {
          state = SonarChannelState(auto: false, current: pinned.tag);
        }
        return;
      }
      final current = channels.where((o) => o.tag == g.selected).firstOrNull;
      // Стоит группа ядра (round-robin) или канала больше нет: берём первый по порядку
      if (current == null || force) {
        final target = channels.firstWhere((o) => o.urlTestDelay == 0 || _valid(o), orElse: () => channels.first);
        if (await _select(g, target.tag) && _current(session, revision)) {
          state = SonarChannelState(current: target.tag);
        }
        return;
      }
      state = SonarChannelState(current: current.tag);
    } finally {
      _busy = false;
      if (!_disposed && _applyPending) {
        _applyPending = false;
        final force = _forcePending;
        _forcePending = false;
        final latest = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
        if (latest != null) unawaited(_apply(latest, force: force));
      }
    }
  }

  bool _valid(OutboundInfo o) => ConnectionConst.isValidDelay(o.urlTestDelay);

  bool _current(int session, int revision) => !_disposed && session == _session && revision == _revision;

  /// Give native URL tests their full timeout, including slow responding links.
  /// Only one probe can run; a manual selection invalidates its result.
  Future<void> _check() async {
    if (_disposed || _checking || _busy || ref.read(connectionNotifierProvider).valueOrNull is! Connected) return;
    final before = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    if (before == null) return;
    _checking = true;
    final session = _session;
    final revision = _revision;
    try {
      final result = await ref.read(proxyRepositoryProvider).urlTest(before.tag).run();
      if (!_current(session, revision) || result.isLeft()) return;
      final finished = Completer<void>();
      _probeFinished = finished;
      _probeTimer = Timer(const Duration(milliseconds: ConnectionConst.maxDelay + 5000), finished.complete);
      await finished.future;
      if (!_current(session, revision)) return;
      final g = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
      if (g == null || g.selected != before.selected || !state.auto || _manual.isNotEmpty) return;
      final channels = sonarChannels(g);
      final current = channels.where((o) => o.tag == g.selected).firstOrNull;
      if (current == null) return _apply(g);
      if (_valid(current)) {
        _fails = 0;
        return;
      }
      if (++_fails < 3) return;
      final next = channels.where((o) => o.tag != current.tag && _valid(o)).firstOrNull;
      if (next == null) return;
      _fails = 0;
      if (_busy) return;
      _busy = true;
      try {
        if (await _select(g, next.tag) && _current(session, revision)) {
          state = SonarChannelState(current: next.tag);
        }
      } finally {
        _busy = false;
        if (_applyPending && !_disposed) {
          _applyPending = false;
          final force = _forcePending;
          _forcePending = false;
          final latest = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
          if (latest != null) unawaited(_apply(latest, force: force));
        }
      }
    } finally {
      _checking = false;
      _probeTimer?.cancel();
      _probeFinished = null;
    }
  }
}

final sonarChannelGuardProvider = NotifierProvider<SonarChannelGuard, SonarChannelState>(SonarChannelGuard.new);
