import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// A size check alone cannot distinguish a complete installer from corrupt data.
Future<bool> verifySonarUpdate(File file, int size, String? digest) async {
  if (size <= 0) throw const FormatException('Размер обновления не указан');
  if (!await file.exists() || await file.length() != size) return false;
  if (digest == null) return true; // Older GitHub releases may not expose a digest.
  final match = RegExp(r'^sha256:([a-fA-F0-9]{64})$').firstMatch(digest);
  if (match == null) throw const FormatException('Некорректная SHA256 обновления');
  return (await sha256.bind(file.openRead()).first).toString() == match.group(1)!.toLowerCase();
}

/// Privileged installation must never execute a file writable by another user.
Future<File> stageSonarWindowsUpdate({
  required File source,
  required Directory protectedDirectory,
  required int size,
  required String digest,
}) async {
  if (!RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest)) {
    throw const FormatException('Для установки с правами администратора нужна SHA256');
  }
  await protectedDirectory.create(recursive: true);
  final stage = await protectedDirectory.createTemp('stage-');
  final staged = File('${stage.path}${Platform.pathSeparator}setup.exe');
  try {
    await source.copy(staged.path);
    if (!await verifySonarUpdate(staged, size, digest)) {
      throw const FormatException('Повреждена защищённая копия установщика');
    }
    return staged;
  } catch (_) {
    if (await staged.exists()) await staged.delete();
    await stage.delete();
    rethrow;
  }
}

/// One resumable attempt. A failed transfer leaves only .part; callers retry on
/// another route. A 206 must describe the precise bytes that will be appended.
Future<void> downloadSonarUpdate({
  required Dio dio,
  required String url,
  required File file,
  required int size,
  String? digest,
  void Function(int received)? onProgress,
}) async {
  if (size <= 0) throw const FormatException('Размер обновления не указан');
  final part = File('${file.path}.part');
  var have = await part.exists() ? await part.length() : 0;
  if (have == size) {
    if (await verifySonarUpdate(part, size, digest)) {
      await part.rename(file.path);
      return;
    }
    await part.delete();
    have = 0;
  } else if (have > size) {
    await part.delete();
    have = 0;
  }
  final response = await dio.get<ResponseBody>(
    url,
    options: Options(responseType: ResponseType.stream, headers: {if (have > 0) 'Range': 'bytes=$have-'}),
  );
  final body = response.data;
  if (body == null) throw const FormatException('Пустой ответ загрузки обновления');
  final code = response.statusCode;
  final append = have > 0 && code == 206;
  if (code == 206) {
    final range = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(response.headers.value('content-range') ?? '');
    if (!append ||
        range == null ||
        int.parse(range[1]!) != have ||
        int.parse(range[2]!) != size - 1 ||
        int.parse(range[3]!) != size) {
      await body.stream.listen(null).cancel();
      throw const FormatException('Сервер вернул неверный диапазон обновления');
    }
  } else if (code != 200) {
    await body.stream.listen(null).cancel();
    throw HttpException('Сервер обновлений ответил $code', uri: Uri.parse(url));
  }
  final sink = part.openWrite(mode: append ? FileMode.append : FileMode.write);
  var got = append ? have : 0;
  try {
    await for (final chunk in body.stream) {
      got += chunk.length;
      if (got > size) throw const FormatException('Размер обновления больше ожидаемого');
      sink.add(chunk);
      onProgress?.call(got);
    }
  } finally {
    await sink.close();
  }
  if (await part.length() != size) throw const FormatException('Обновление скачалось не целиком');
  if (!await verifySonarUpdate(part, size, digest)) {
    await part.delete();
    throw const FormatException('SHA256 обновления не совпала');
  }
  await part.rename(file.path);
}

String _literal(String value) => "'${value.replaceAll("'", "''")}'";

/// The helper acknowledges startup before the app exits, waits for the original
/// PID, and records the actual installer outcome. Paths never pass through CMD.
String windowsUpdateScript({
  required String installer,
  required String executable,
  required int oldProcessId,
  required String logPath,
  required String acknowledgementPath,
  required String installationDirectory,
  required String taskName,
}) {
  final target = '$installationDirectory\\${File(executable).uri.pathSegments.last}';
  final arguments = [
    '/VERYSILENT',
    '/SUPPRESSMSGBOXES',
    '/NORESTART',
    '/CLOSEAPPLICATIONS',
    '/ALLUSERS',
    '/DIR="$installationDirectory"',
    '/LOG="$logPath.inno.log"',
  ].map(_literal).join(',');
  return '''
\$ErrorActionPreference = 'Stop'
\$log = ${_literal(logPath)}
\$outcome = 1
\$canRestart = \$false
\$restart = ${_literal(executable)}
function Write-UpdateLog([string]\$message) { Add-Content -LiteralPath \$log -Value ((Get-Date -Format o) + ' ' + \$message) -Encoding UTF8 }
try {
  Set-Content -LiteralPath ${_literal(acknowledgementPath)} -Value 'ready' -Encoding UTF8
  \$old = Get-Process -Id $oldProcessId -ErrorAction SilentlyContinue
  if (\$old -and -not \$old.WaitForExit(120000)) { throw 'Sonar did not exit before update' }
  \$canRestart = \$true
  \$process = Start-Process -FilePath ${_literal(installer)} -ArgumentList @($arguments) -PassThru -Wait -WindowStyle Hidden
  \$outcome = \$process.ExitCode
  Write-UpdateLog ("installer exit code: " + \$outcome)
  if (\$outcome -eq 0) { \$restart = ${_literal(target)} }
} catch {
  Write-UpdateLog ("installer failed: " + \$_.Exception.Message)
}
if (\$outcome -ne 0) { Set-Content -LiteralPath (\$log + '.failed') -Value \$outcome -Encoding UTF8 }
else { Remove-Item -LiteralPath (\$log + '.failed') -ErrorAction SilentlyContinue }
if (-not \$canRestart) { exit 1 }
Remove-Item -LiteralPath ${_literal(installer)} -ErrorAction SilentlyContinue
try {
  \$task = Get-ScheduledTask -TaskName ${_literal(taskName)} -ErrorAction SilentlyContinue
  if (\$task -and (@(\$task.Actions).Count -eq 1) -and (\$task.Actions.Execute -eq \$restart)) {
    if (\$task.State -eq 'Running') { Write-UpdateLog 'task already running' }
    else { Start-ScheduledTask -TaskName ${_literal(taskName)} -ErrorAction Stop; Write-UpdateLog 'restarted through task' }
  } else {
    Start-Process -FilePath \$restart -WorkingDirectory (Split-Path -Parent \$restart) -WindowStyle Hidden
    Write-UpdateLog 'restarted executable'
  }
} catch {
  Write-UpdateLog ("restart failed: " + \$_.Exception.Message)
  if (\$outcome -eq 0) { \$outcome = 1 }
}
exit \$outcome
''';
}

List<String> windowsPowerShellArguments(String script) => [
  '-NoProfile',
  '-NonInteractive',
  '-WindowStyle',
  'Hidden',
  '-EncodedCommand',
  base64Encode(Uint16List.fromList(script.codeUnits).buffer.asUint8List()),
];
