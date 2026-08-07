[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$taskName = 'Cronos-Actualizar-Contexto'

function Test-ScheduledTaskNotFoundError {
    param([System.Management.Automation.ErrorRecord]$ErrorRecord)

    $category = [string]$ErrorRecord.CategoryInfo.Category
    $fullyQualifiedErrorId = [string]$ErrorRecord.FullyQualifiedErrorId
    $message = [string]$ErrorRecord.Exception.Message
    $hResult = $ErrorRecord.Exception.HResult

    return (
        $category -eq 'ObjectNotFound' -or
        $fullyQualifiedErrorId -match '(?i)(CmdletizationQuery_NotFound|ObjectNotFound)' -or
        $hResult -eq -2147024894 -or
        $message -match "(?i)No MSFT_ScheduledTask objects found"
    )
}

$task = $null
try {
    $task = Get-ScheduledTask -TaskName $taskName -ErrorAction Stop
}
catch {
    if (-not (Test-ScheduledTaskNotFoundError -ErrorRecord $_)) {
        $message = "Unable to query scheduled task '$taskName': $($_.Exception.Message)"
        Write-Error $message -ErrorAction Continue
        exit 1
    }
}

if ($null -eq $task) {
    Write-Output "not-found: $taskName"
    exit 0
}

if ($WhatIf) {
    Write-Output "WhatIf: scheduled task would be removed: $taskName"
    exit 0
}

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
Write-Output "removed: $taskName"
