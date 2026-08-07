[CmdletBinding()]
param(
    [switch]$WhatIf,
    [ValidateSet('Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday')]
    [string]$DayOfWeek = 'Sunday',
    [string]$At = '03:00'
)

$ErrorActionPreference = 'Stop'
$taskName = 'Cronos-Actualizar-Contexto'
$orchestratorPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot 'actualizar-contexto.ps1'))

try {
    $triggerTime = [DateTime]::ParseExact(
        $At,
        'HH:mm',
        [System.Globalization.CultureInfo]::InvariantCulture,
        [System.Globalization.DateTimeStyles]::None
    )
}
catch {
    throw "At must use the HH:mm format: $At"
}

$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
$actionText = 'powershell.exe -NoProfile -ExecutionPolicy Bypass -File ' +
    ('"' + $orchestratorPath.Replace('"', '\"') + '"') +
    ' -Mode Scheduled'
$triggerText = "Weekly $DayOfWeek at $At"
$principalText = "$currentUser (InteractiveToken, limited, no stored credentials)"

if ($WhatIf) {
    Write-Output "TaskName: $taskName"
    Write-Output "Trigger: $triggerText"
    Write-Output "Principal: $principalText"
    Write-Output "Action: $actionText"
    Write-Output 'WhatIf: scheduled task was not registered.'
    exit 0
}

$action = New-ScheduledTaskAction `
    -Execute 'powershell.exe' `
    -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$orchestratorPath`" -Mode Scheduled"
$trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek $DayOfWeek -At $triggerTime
$principal = New-ScheduledTaskPrincipal `
    -UserId $currentUser `
    -LogonType InteractiveToken `
    -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet

Register-ScheduledTask `
    -TaskName $taskName `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description 'Refresh Cronos Analista context and run safe scheduled Graphify.'

Write-Output "registered: $taskName"
