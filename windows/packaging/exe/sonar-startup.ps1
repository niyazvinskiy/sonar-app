param([switch]$Uninstall)
$ErrorActionPreference = 'Stop'
# Installed beside Sonar in Program Files, so a non-elevated process cannot
# replace the executable behind this highest-privilege task.
$exe = Join-Path $PSScriptRoot 'Sonar.exe'
$protectedRoot = [IO.Path]::GetFullPath($env:ProgramFiles).TrimEnd('\') + '\'
if (-not ([IO.Path]::GetFullPath($exe).StartsWith($protectedRoot, [StringComparison]::OrdinalIgnoreCase))) {
    throw 'Sonar automatic startup requires installation in Program Files'
}
$user = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$taskName = 'Sonar VPN-' + $user
if ($Uninstall) {
    Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    exit 0
}
$previous = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
$startup = -not $previous -or @($previous.Triggers | Where-Object Enabled).Count -gt 0
$action = New-ScheduledTaskAction -Execute $exe -WorkingDirectory $PSScriptRoot
$principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0 -MultipleInstances IgnoreNew -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$parameters = @{TaskName=$taskName; Action=$action; Principal=$principal; Settings=$settings; Force=$true}
if ($startup) { $parameters.Trigger = New-ScheduledTaskTrigger -AtLogOn -User $user }
Register-ScheduledTask @parameters | Out-Null
# Remove the obsolete non-elevated startup entry.
Remove-ItemProperty -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' -Name 'Sonar' -ErrorAction SilentlyContinue
# Migrate only this user's legacy task. Never remove another user's task.
$legacy = Get-ScheduledTask -TaskName 'Sonar VPN' -ErrorAction SilentlyContinue
if ($legacy) {
    try {
        $owner = $legacy.Principal.UserId
        if ($owner -notlike 'S-1-*') { $owner = ([Security.Principal.NTAccount]$owner).Translate([Security.Principal.SecurityIdentifier]).Value }
        if ($owner -eq $user) { Unregister-ScheduledTask -TaskName 'Sonar VPN' -Confirm:$false }
    } catch { Write-Warning 'Legacy Sonar task could not be migrated' }
}
Start-ScheduledTask -TaskName $taskName
# The 1.3 updater launches its old executable as soon as setup exits. Do not
# return until the protected replacement has claimed the single-instance mutex.
$deadline = (Get-Date).AddSeconds(30)
$ready = $false
while (-not $ready) {
    foreach ($process in (Get-Process -Name Sonar -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })) {
        try { if ($process.WaitForInputIdle(1000)) { $ready = $true; break } } catch { }
    }
    if ($ready) { break }
    if ((Get-Date) -ge $deadline) { throw 'The installed Sonar did not open after setup' }
    Start-Sleep -Milliseconds 100
}
