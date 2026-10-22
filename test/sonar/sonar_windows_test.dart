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
    expect(script, contains(r"($env:USERDOMAIN + '\' + $env:USERNAME)"));
  }, skip: !Platform.isWindows);
}
