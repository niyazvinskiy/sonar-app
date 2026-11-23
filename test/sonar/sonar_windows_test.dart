import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hiddify/sonar/sonar_windows.dart';

void main() {
  // Скрипт создания задачи PowerShell должен разбираться без ошибок: его запускают
  // с правами администратора, и опечатку там уже никто не увидит
  test('скрипт задачи «Sonar VPN» разбирается PowerShell', () async {
    final script = SonarWindows.taskScript(
      r"C:\Users\Ни'ки\AppData\Local\Programs\Sonar\Sonar.exe".replaceAll("'", "''"),
    );
    const check =
        r'$e = $null; [void][System.Management.Automation.Language.Parser]::ParseInput($env:SONAR_SCRIPT, [ref]$null, [ref]$e); '
        r'if ($e) { $e | ForEach-Object { $_.Message }; exit 1 }';
    final r = await Process.run(
      'powershell.exe',
      ['-NoProfile', '-Command', check],
      environment: {'SONAR_SCRIPT': script},
    );
    expect(r.exitCode, 0, reason: '${r.stdout}${r.stderr}\n$script');
    expect(script, contains(r"-Execute 'C:\Users\Ни''ки\AppData"));
    expect(script, contains('-ExecutionTimeLimit 0'));
    expect(script, contains('New-ScheduledTaskTrigger -AtLogOn'));
    expect(script, contains('-RestartCount 3'));
    expect(script, contains('-WorkingDirectory'));
    expect(script, contains('New-ScheduledTaskPrincipal -UserId \$sid'));
    expect(script, contains("\$task = 'Sonar VPN-' + \$sid"));
  }, skip: !Platform.isWindows);

  test('autostart can be disabled without losing privileged manual launch', () {
    final script = SonarWindows.taskScript(r'C:\Program Files\Sonar\Sonar.exe', startup: false, run: false);
    expect(script, isNot(contains('New-ScheduledTaskTrigger')));
    expect(script, isNot(contains('Start-ScheduledTask')));
    expect(script, contains('-RunLevel Highest'));
  });

  for (final enabled in [true, false]) {
    test('installer preserves startup=$enabled and isolates another user task', () async {
      final dir = await Directory.systemTemp.createTemp('sonar-startup-test-');
      try {
        final script = await File('windows/packaging/exe/sonar-startup.ps1').copy('${dir.path}\\sonar-startup.ps1');
        final quoted = script.path.replaceAll("'", "''");
        final fixture =
            '''
\$env:ProgramFiles = '${dir.path.replaceAll("'", "''")}'
\$global:registered = \$null
\$global:removed = @()
function Get-ScheduledTask { param(\$TaskName,\$ErrorAction)
  if (\$TaskName -eq 'Sonar VPN') { return [pscustomobject]@{ Principal=[pscustomobject]@{UserId='S-1-5-21-0'} } }
  return [pscustomobject]@{ Triggers=@(${enabled ? r'[pscustomobject]@{Enabled=$true}' : ''}) }
}
function New-ScheduledTaskAction { param(\$Execute,\$WorkingDirectory) [pscustomobject]@{Execute=\$Execute;WorkingDirectory=\$WorkingDirectory} }
function New-ScheduledTaskPrincipal { param(\$UserId,\$LogonType,\$RunLevel) [pscustomobject]@{UserId=\$UserId;RunLevel=\$RunLevel} }
function New-ScheduledTaskSettingsSet { param([switch]\$AllowStartIfOnBatteries,[switch]\$DontStopIfGoingOnBatteries,\$ExecutionTimeLimit,\$MultipleInstances,[switch]\$StartWhenAvailable,\$RestartCount,\$RestartInterval) @{} }
function New-ScheduledTaskTrigger { param([switch]\$AtLogOn,\$User) [pscustomobject]@{User=\$User} }
function Register-ScheduledTask { param(\$TaskName,\$Action,\$Principal,\$Settings,\$Trigger,[switch]\$Force) \$global:registered=\$PSBoundParameters }
function Unregister-ScheduledTask { param(\$TaskName,[switch]\$Confirm,\$ErrorAction) \$global:removed += \$TaskName }
function Remove-ItemProperty { param(\$LiteralPath,\$Name,\$ErrorAction) }
function Start-ScheduledTask { param(\$TaskName) \$global:started=\$TaskName }
function Get-Process { param(\$Name,\$ErrorAction)
  \$p = [pscustomobject]@{Path=\$exe; MainWindowHandle=1}
  \$p | Add-Member -MemberType ScriptMethod -Name WaitForInputIdle -Value { param(\$timeout) \$global:waitCalled=\$true; return \$true }
  return \$p
}
. '$quoted'
\$sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if (\$global:registered.TaskName -ne ('Sonar VPN-' + \$sid)) { throw 'Task is not scoped to user SID' }
if (\$global:registered.Principal.UserId -ne \$sid) { throw 'Wrong task principal' }
if ((\$null -ne \$global:registered.Trigger) -ne \$${enabled ? 'true' : 'false'}) { throw 'Startup preference changed' }
if (\$global:removed.Count -ne 0) { throw 'Removed another user task' }
if (\$global:started -ne \$global:registered.TaskName) { throw 'Started a different task' }
if (-not \$global:waitCalled) { throw 'Setup did not wait for the GUI message loop, including hidden windows' }
''';
        final result = await Process.run(
          'powershell.exe',
          ['-NoProfile', '-NonInteractive', '-Command', fixture],
          environment: {'ProgramFiles': dir.path},
        );
        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      } finally {
        await dir.delete(recursive: true);
      }
    }, skip: !Platform.isWindows);
  }
}
