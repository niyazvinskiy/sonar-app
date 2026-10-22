import 'dart:async';

import 'package:hiddify/core/model/constants.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Порядок каналов для автовыбора: сначала самый проходимый, дальше запасные.
const _priority = ['Основной', 'Игры', 'Запасной'];

int _rank(OutboundInfo o) {
  final name = o.tagDisplay.isNotEmpty ? o.tagDisplay : o.tag;
  final i = _priority.indexWhere(name.contains);
  return i == -1 ? _priority.length : i;
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
/// Sonar держит один канал и переходит на следующий, только когда текущий два раза
/// подряд не ответил на проверку. На лучший канал обратно не прыгает, пока текущий
/// живой: звонок и игра важнее лишних миллисекунд.
class SonarChannelGuard extends Notifier<SonarChannelState> {
  static const _prefKey = 'sonar_channel';
  static const _every = Duration(minutes: 2);

  Timer? _timer;
  int _fails = 0;
  bool _busy = false;

  @override
  SonarChannelState build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(connectionNotifierProvider, (_, next) {
      if (next.valueOrNull is Connected) {
        _start();
      } else {
        _timer?.cancel();
        _fails = 0;
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
    _timer?.cancel();
    _fails = 0;
    // Первая проверка вскоре после подключения, дальше раз в две минуты
    Future<void>.delayed(const Duration(seconds: 6), _check);
    _timer = Timer.periodic(_every, (_) => _check());
  }

  String get _manual => ref.read(sharedPreferencesProvider).valueOrNull?.getString(_prefKey) ?? '';

  /// Выбор из окна каналов: '' — снова автовыбор.
  Future<void> choose(String tag) async {
    await ref.read(sharedPreferencesProvider).valueOrNull?.setString(_prefKey, tag);
    state = SonarChannelState(auto: tag.isEmpty, current: state.current);
    _fails = 0;
    final g = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    if (g != null) await _apply(g, force: true);
  }

  Future<void> _select(OutboundGroup g, String tag) async {
    if (g.selected == tag) return;
    await ref.read(proxyRepositoryProvider).selectProxy(g.tag, tag).run();
  }

  /// Держит выбранный канал: руками выбранный, а при автовыборе первый живой по порядку.
  Future<void> _apply(OutboundGroup g, {bool force = false}) async {
    if (_busy) return;
    final channels = sonarChannels(g);
    if (channels.isEmpty) return;
    _busy = true;
    try {
      final manual = _manual;
      final pinned = channels.where((o) => o.tag == manual).firstOrNull;
      if (pinned != null) {
        await _select(g, pinned.tag);
        state = SonarChannelState(auto: false, current: pinned.tag);
        return;
      }
      final current = channels.where((o) => o.tag == g.selected).firstOrNull;
      // Стоит группа ядра (round-robin) или канала больше нет: берём первый по порядку
      if (current == null || force) {
        final target = channels.firstWhere((o) => o.urlTestDelay == 0 || _valid(o), orElse: () => channels.first);
        await _select(g, target.tag);
        state = SonarChannelState(current: target.tag);
        return;
      }
      state = SonarChannelState(current: current.tag);
    } finally {
      _busy = false;
    }
  }

  bool _valid(OutboundInfo o) => ConnectionConst.isValidDelay(o.urlTestDelay);

  /// Проверка каналов: текущий дважды подряд без ответа — переход на следующий живой.
  Future<void> _check() async {
    if (ref.read(connectionNotifierProvider).valueOrNull is! Connected) return;
    final before = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    if (before == null) return;
    await ref.read(proxyRepositoryProvider).urlTest(before.tag).run();
    // Результаты проверки приходят потоком, ждём, пока он обновится
    await Future<void>.delayed(const Duration(seconds: 8));
    final g = ref.read(proxiesOverviewNotifierProvider).valueOrNull;
    if (g == null || !state.auto || _manual.isNotEmpty) return;
    final channels = sonarChannels(g);
    final current = channels.where((o) => o.tag == g.selected).firstOrNull;
    if (current == null) return _apply(g);
    if (_valid(current)) {
      _fails = 0;
      return;
    }
    if (++_fails < 2) return;
    final next = channels.where((o) => o.tag != current.tag && _valid(o)).firstOrNull;
    if (next == null) return;
    _fails = 0;
    await _select(g, next.tag);
    state = SonarChannelState(current: next.tag);
  }
}

final sonarChannelGuardProvider = NotifierProvider<SonarChannelGuard, SonarChannelState>(SonarChannelGuard.new);
