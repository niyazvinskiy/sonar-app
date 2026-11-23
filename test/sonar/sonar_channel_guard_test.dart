import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/features/proxy/data/proxy_repository.dart';
import 'package:hiddify/features/proxy/model/proxy_failure.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/sonar/sonar_channel_guard.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _ConnectedCore extends ConnectionNotifier {
  @override
  Stream<ConnectionStatus> build() => Stream.value(const Connected());
}

OutboundGroup _channels() => OutboundGroup(
  tag: 'select',
  selected: 'main',
  items: [
    OutboundInfo(tag: 'main', tagDisplay: 'Основной', isVisible: true),
    OutboundInfo(tag: 'backup', tagDisplay: 'Запасной', isVisible: true, urlTestDelay: 100),
  ],
);

class _Channels extends ProxiesOverviewNotifier {
  _Channels([this.updates]);
  final Stream<OutboundGroup?>? updates;
  @override
  Stream<OutboundGroup?> build() => updates ?? Stream.value(_channels());
}

class _Repository implements ProxyRepository {
  int checks = 0;
  final selected = <String>[];

  @override
  TaskEither<ProxyFailure, Unit> urlTest(String groupTag) => TaskEither(() async {
    expectSync(groupTag, 'select');
    checks++;
    return right(unit);
  });

  @override
  TaskEither<ProxyFailure, Unit> selectProxy(String groupTag, String outboundTag) => TaskEither(() async {
    expectSync(groupTag, 'select');
    selected.add(outboundTag);
    return right(unit);
  });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('keeps a responding 45-second channel instead of interrupting the session', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final updates = StreamController<OutboundGroup?>();
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        connectionNotifierProvider.overrideWith(_ConnectedCore.new),
        proxiesOverviewNotifierProvider.overrideWith(() => _Channels(updates.stream)),
        proxyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await container.read(sharedPreferencesProvider.future);
    container.listen(sonarChannelGuardProvider, (_, next) {});
    updates.add(_channels());
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    await tester.pump(const Duration(seconds: 39));
    final responding = _channels();
    responding.items.first.urlTestDelay = 45000;
    updates.add(responding);
    await tester.pump();
    await tester.pump(const Duration(seconds: 35));
    expect(repo.selected, isEmpty);
    expect(container.read(sonarChannelGuardProvider).current, 'main');
    container.dispose();
    unawaited(updates.close());
    await tester.pump();
  });

  testWidgets('waits for slow probes and never overlaps them or switches on the first miss', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        connectionNotifierProvider.overrideWith(_ConnectedCore.new),
        proxiesOverviewNotifierProvider.overrideWith(_Channels.new),
        proxyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await container.read(sharedPreferencesProvider.future);
    container.listen(sonarChannelGuardProvider, (_, next) {});
    await tester.pump();
    await tester.pump(const Duration(seconds: 6));
    expect(repo.checks, 1);
    await tester.pump(const Duration(seconds: 64));
    expect(repo.checks, 1, reason: 'a probe may need the full native 65-second timeout');
    expect(repo.selected, isEmpty, reason: 'one unmeasured sample cannot interrupt an open session');
    await tester.pump(const Duration(seconds: 10));
    expect(repo.selected, isEmpty, reason: 'the first completed failure must not switch channels');
    container.dispose();
    await tester.pump();
  });

  testWidgets('disconnect cancels the delayed initial probe', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repository();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        connectionNotifierProvider.overrideWith(_ConnectedCore.new),
        proxiesOverviewNotifierProvider.overrideWith(_Channels.new),
        proxyRepositoryProvider.overrideWithValue(repo),
      ],
    );
    await container.read(sharedPreferencesProvider.future);
    container.listen(sonarChannelGuardProvider, (_, next) {});
    await tester.pump();
    container.dispose();
    await tester.pump(const Duration(seconds: 10));
    expect(repo.checks, 0);
    expect(tester.takeException(), isNull);
  });
}
