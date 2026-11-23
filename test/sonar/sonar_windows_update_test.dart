import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/sonar_update_io.dart';

void main() {
  group('Windows installer handoff', _windowsTests, skip: !Platform.isWindows);
}

void _windowsTests() {
  late Directory temporary;
  late String installer;
  late String executable;
  late File invocation;
  late File restarted;

  setUp(() async {
    temporary = await Directory.systemTemp.createTemp("Sonar ' %PATH% тест ");
    installer = '${temporary.path}\\installer.exe';
    executable = '${temporary.path}\\Sonar.exe';
    invocation = File('${temporary.path}\\installer-arguments.txt');
    restarted = File('${temporary.path}\\restarted.txt');
    final source = File('${temporary.path}\\fixture.cs');
    await source.writeAsString(r'''
using System;
using System.IO;
class Fixture {
  static int Main(string[] args) {
    if (args.Length == 1 && args[0] == "hold") { System.Threading.Thread.Sleep(30000); return 0; }
    if (args.Length == 0) { File.AppendAllText(Environment.GetEnvironmentVariable("SONAR_RESTART_MARKER"), "start\n"); return 0; }
    File.WriteAllLines(Environment.GetEnvironmentVariable("SONAR_INSTALL_ARGS"), args);
    return int.Parse(Environment.GetEnvironmentVariable("SONAR_INSTALL_EXIT"));
  }
}
''');
    final compile = await Process.run(
      '${Platform.environment['WINDIR']}\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe',
      ['/nologo', '/target:exe', '/out:$installer', source.path],
    );
    expect(compile.exitCode, 0, reason: '${compile.stdout}\n${compile.stderr}');
    await File(installer).copy(executable);
  });
  tearDown(() async {
    // The fixture restarts detached; allow its very short write to finish.
    for (var i = 0; i < 40 && !await restarted.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    await temporary.delete(recursive: true);
  });

  Future<ProcessResult> run({
    required int exitCode,
    bool withTask = false,
    bool taskRunning = false,
    bool wrongTaskAction = false,
    bool exitWhileChecking = false,
    int oldProcessId = 2147483647,
  }) {
    final script = windowsUpdateScript(
      installer: installer,
      executable: executable,
      oldProcessId: oldProcessId,
      logPath: '${temporary.path}\\outcome.log',
      acknowledgementPath: '${temporary.path}\\ack',
      installationDirectory: temporary.path,
      taskName: 'Sonar VPN-test',
    );
    // Keep task execution isolated from the user's real Sonar task.
    final taskBoundary = wrongTaskAction
        ? r'''
function Get-ScheduledTask { [PSCustomObject]@{ State = 'Running'; Actions = @([PSCustomObject]@{ Execute = 'C:\unrelated\Sonar.exe' }) } }
function Start-ScheduledTask { throw 'Must not start an unrelated task' }
'''
        : taskRunning
        ? r'''
function Get-ScheduledTask { [PSCustomObject]@{ State = 'Running'; Actions = @([PSCustomObject]@{ Execute = $env:SONAR_RESTART_EXE }) } }
function Start-ScheduledTask { throw 'A running Sonar task must not be started twice' }
'''
        : withTask
        ? r'''
function Get-ScheduledTask { [PSCustomObject]@{ State = 'Ready'; Actions = @([PSCustomObject]@{ Execute = $env:SONAR_RESTART_EXE }) } }
function Start-ScheduledTask { Add-Content -LiteralPath $env:SONAR_RESTART_MARKER -Value 'task' }
'''
        : 'function Get-ScheduledTask { return \$null }\n';
    return Process.run(
      'powershell.exe',
      windowsPowerShellArguments('''
$taskBoundary
${exitWhileChecking ? r'''
function Get-Process { param($Id,$ErrorAction)
  $original = Microsoft.PowerShell.Management\Get-Process -Id $Id -ErrorAction SilentlyContinue
  if ($original) { Stop-Process -Id $Id -Force; return $original }
}
''' : ''}
$script'''),
      environment: {
        'SONAR_RESTART_MARKER': restarted.path,
        'SONAR_INSTALL_ARGS': invocation.path,
        'SONAR_INSTALL_EXIT': '$exitCode',
        'SONAR_RESTART_EXE': executable,
      },
    );
  }

  test('installer receives the exact protected directory despite quote and percent characters', () async {
    final result = await run(exitCode: 0);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await invocation.readAsLines(), contains('/ALLUSERS'));
    expect(await invocation.readAsLines(), contains('/DIR=${temporary.path}'));
    expect(await File('${temporary.path}\\ack').exists(), true);
    expect(await File('${temporary.path}\\outcome.log').readAsString(), contains('installer exit code: 0'));
  });

  test('failed installer records its exit code and restarts the existing executable', () async {
    final result = await run(exitCode: 9);
    expect(result.exitCode, 9, reason: '${result.stderr}');
    expect(await File('${temporary.path}\\outcome.log').readAsString(), contains('installer exit code: 9'));
    expect((await File('${temporary.path}\\outcome.log.failed').readAsString()).trim(), '9');
    for (var i = 0; i < 40 && !await restarted.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(await restarted.readAsString(), 'start\n');
  });

  test('restarts through the existing scheduled task without launching a second process', () async {
    final result = await run(exitCode: 0, withTask: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((await restarted.readAsString()).trim(), 'task');
  });

  test('keeps the instance already started by the installer without duplicating it', () async {
    final result = await run(exitCode: 0, taskRunning: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(await restarted.exists(), false);
    expect(await File('${temporary.path}\\outcome.log').readAsString(), contains('task already running'));
  });

  test('ignores a task pointing at another installation', () async {
    final result = await run(exitCode: 0, wrongTaskAction: true);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    for (var i = 0; i < 40 && !await restarted.exists(); i++) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(await restarted.readAsString(), 'start\n');
  });

  test('waits for the original process to exit before starting the installer', () async {
    final original = await Process.start(executable, ['hold']);
    try {
      final result = run(exitCode: 0, oldProcessId: original.pid);
      final acknowledgement = File('${temporary.path}\\ack');
      for (var i = 0; i < 80 && !await acknowledgement.exists(); i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
      expect(await acknowledgement.exists(), true);
      expect(await invocation.exists(), false, reason: 'the old process still owns installed files');
      original.kill();
      final completed = await result;
      final log = File('${temporary.path}\\outcome.log');
      expect(completed.exitCode, 0, reason: '${completed.stdout}${completed.stderr}\n${await log.readAsString()}');
      expect(await invocation.exists(), true);
    } finally {
      original.kill();
      await original.exitCode;
    }
  });

  test('handles original process exiting between lookup and wait', () async {
    final original = await Process.start(executable, ['hold']);
    try {
      final completed = await run(exitCode: 0, oldProcessId: original.pid, exitWhileChecking: true);
      expect(completed.exitCode, 0, reason: await File('${temporary.path}\\outcome.log').readAsString());
      expect(await invocation.exists(), true);
    } finally {
      original.kill();
      await original.exitCode;
    }
  });
}
