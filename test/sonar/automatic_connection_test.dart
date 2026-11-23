import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/connection/data/connection_data_providers.dart';
import 'package:hiddify/features/connection/data/connection_repository.dart';
import 'package:hiddify/features/connection/model/connection_failure.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Profile extends ActiveProfile {
  @override
  Stream<ProfileEntity?> build() =>
      Stream.value(ProfileEntity.local(id: 'sonar', active: true, name: 'Sonar', lastUpdate: DateTime(2026)));
}

class _Dialogs extends DialogNotifier {
  int alerts = 0;
  @override
  Future<void> showCustomAlertFromErr(({String type, String? message}) err) async {
    alerts++;
  }
}

class _Repository implements ConnectionRepository {
  int attempts = 0;
  final result = Completer<Either<ConnectionFailure, Unit>>();
  @override
  Stream<ConnectionStatus> watchConnectionStatus() => Stream.value(const Disconnected());
  @override
  TaskEither<ConnectionFailure, Unit> connect(ProfileEntity profile, bool disableMemoryLimit) => TaskEither(() {
    expectSync(profile.id, 'sonar');
    attempts++;
    return result.future;
  });
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('automatic connection awaits native result and surfaces failure without a modal', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final repo = _Repository();
    final dialogs = _Dialogs();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWith((ref) => Future.value(prefs)),
        activeProfileProvider.overrideWith(_Profile.new),
        connectionRepositoryProvider.overrideWithValue(repo),
        dialogNotifierProvider.overrideWith(() => dialogs),
        translationsProvider.overrideWith((ref) => AppLocale.en.build()),
      ],
    );
    addTearDown(container.dispose);
    await container.read(sharedPreferencesProvider.future);
    await container.read(translationsProvider.future);
    await container.read(connectionNotifierProvider.future);
    var finished = false;
    final first = container.read(connectionNotifierProvider.notifier).connectAutomatically().then((_) {
      finished = true;
    });
    await tester.pump();
    expect(repo.attempts, 1);
    expect(finished, isFalse, reason: 'recovery must not launch another operation before the native result');
    expect(await container.read(connectionNotifierProvider.notifier).connectAutomatically(), isFalse);
    expect(repo.attempts, 1);
    repo.result.complete(left(const MissingPrivilege()));
    await first;
    await tester.pump();
    expect(container.read(connectionNotifierProvider).hasError, isTrue);
    expect(dialogs.alerts, 0);
  });
}
