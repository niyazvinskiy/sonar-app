import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/features/profile/data/profile_data_providers.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/sonar/sonar.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

sealed class SonarKeyStatus {
  const SonarKeyStatus();
}

class SonarKeyIdle extends SonarKeyStatus {
  const SonarKeyIdle();
}

class SonarKeyIssuing extends SonarKeyStatus {
  const SonarKeyIssuing();
}

class SonarKeyFailed extends SonarKeyStatus {
  const SonarKeyFailed(this.message);

  final String message;
}

/// Личный ключ: получить с сервера и добавить подпиской «Sonar», если ключа ещё нет.
class SonarKeyNotifier extends Notifier<SonarKeyStatus> {
  @override
  SonarKeyStatus build() => const SonarKeyIdle();

  /// true, когда ключ есть и можно подключаться.
  Future<bool> ensure() async {
    if (state is SonarKeyIssuing) return false;
    if (await ref.read(hasAnyProfileProvider.future)) return true;
    state = const SonarKeyIssuing();
    try {
      final prefs = await ref.read(sharedPreferencesProvider.future);
      final key = await sonarIssueKey(prefs);
      final repo = await ref.read(profileRepositoryProvider.future);
      final added = await repo
          .upsertRemote(key.subscription, userOverride: const UserOverride(name: Sonar.profileName))
          .run();
      added.match((failure) => throw SonarKeyException('Ключ получен, но не добавился: $failure'), (_) {});
      state = const SonarKeyIdle();
      return true;
    } on SonarKeyException catch (e) {
      state = SonarKeyFailed(e.message);
    } catch (e) {
      state = SonarKeyFailed('Не удалось получить ключ: $e');
    }
    return false;
  }
}

final sonarKeyProvider = NotifierProvider<SonarKeyNotifier, SonarKeyStatus>(SonarKeyNotifier.new);
