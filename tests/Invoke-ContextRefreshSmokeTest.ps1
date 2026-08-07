Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$orchestratorPath = Join-Path $PSScriptRoot '..\scripts\actualizar-contexto.ps1'
$schedulerPath = Join-Path $PSScriptRoot '..\scripts\registrar-tarea-contexto.ps1'
$removalPath = Join-Path $PSScriptRoot '..\scripts\eliminar-tarea-contexto.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cronos-context-smoke-' + [guid]::NewGuid().ToString('N'))
$oldPath = $null
$oldGraphifyMarker = $null
$oldContextIndex = $null
$reparseControlCenterPath = $null
$reparseContextTemporaryPath = $null
$script:schedulerRegisterCalled = $false
$script:schedulerRemovalCalled = $false
$global:cronosSchedulerQueryShouldFail = $false

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Get-TextOutput {
    param([object[]]$Output)

    return [string]::Join("`n", @($Output | ForEach-Object { [string]$_ }))
}

function Invoke-PowerShellScript {
    param(
        [string]$Path,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $Path @Arguments 2>&1)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = [int]$LASTEXITCODE
        Output = $output
        Text = Get-TextOutput -Output $output
    }
}

function Read-JsonFile {
    param([string]$Path)

    return ([System.IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

function Get-FileFingerprint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return '<absent>'
    }

    $rows = @(
        Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction Stop |
            ForEach-Object {
                $relativePath = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
                "$relativePath|$($_.Length)|$($_.LastWriteTimeUtc.ToString('o'))"
            } |
            Sort-Object
    )

    return [string]::Join("`n", $rows)
}

function Register-ScheduledTask {
    [CmdletBinding()]
    param(
        [object]$TaskName,
        [object]$Action,
        [object]$Trigger,
        [object]$Principal,
        [object]$Settings,
        [string]$Description
    )

    $script:schedulerRegisterCalled = $true
}

function Get-ScheduledTask {
    [CmdletBinding()]
    param([string]$TaskName)

    if ($global:cronosSchedulerQueryShouldFail) {
        throw 'fixture service unavailable: access denied'
    }

    return $null
}

function Unregister-ScheduledTask {
    [CmdletBinding()]
    param(
        [string]$TaskName,
        [switch]$Confirm
    )

    $script:schedulerRemovalCalled = $true
}

try {
    if (-not (Test-Path -LiteralPath $orchestratorPath -PathType Leaf)) {
        throw "RED: orchestrator is absent: $orchestratorPath"
    }

    Assert-True (Test-Path -LiteralPath $schedulerPath -PathType Leaf) 'scheduler script should exist'
    Assert-True (Test-Path -LiteralPath $removalPath -PathType Leaf) 'removal script should exist'

    $projectsRoot = Join-Path $fixtureRoot 'projects'
    $controlCenterPath = Join-Path $fixtureRoot 'control-center'
    $projectPath = Join-Path $projectsRoot 'alpha'
    $sourcePath = Join-Path $projectPath 'src'
    $reparseControlCenterPath = Join-Path $fixtureRoot 'reparse-control-center'
    $fakeCommandRoot = Join-Path $fixtureRoot 'fake-command'
    $markerPath = Join-Path $fixtureRoot 'graphify-marker.txt'
    $indexMarkerPath = Join-Path $fixtureRoot 'index-marker.txt'
    $reparseContextControlCenterPath = Join-Path $fixtureRoot 'reparse-context-control-center'
    $reparseContextTemporaryPath = Join-Path $reparseContextControlCenterPath 'state\context-status.json.tmp'
    $reparseContextTemporaryTargetPath = Join-Path $fixtureRoot 'reparse-context-target'

    New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null
    New-Item -ItemType Directory -Path $controlCenterPath -Force | Out-Null
    New-Item -ItemType Directory -Path $fakeCommandRoot -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseControlCenterPath -Target $sourcePath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $sourcePath 'App.ts') -Value 'export const appName = "fixture";' -Encoding UTF8
    Set-Content -LiteralPath $indexMarkerPath -Value 'fixture-index-marker' -Encoding UTF8

    $fakeCommandPath = Join-Path $fakeCommandRoot 'graphify.cmd'
    Set-Content -LiteralPath $fakeCommandPath -Value @(
        '@echo off'
        'if "%1"=="--version" ('
        '  echo graphify 0.9.32'
        '  exit /b 0'
        ')'
        'if not exist "%CRONOS_CONTEXT_INDEX%" ('
        '  echo index-missing>>"%CRONOS_GRAPHIFY_MARKER%"'
        '  exit /b 91'
        ')'
        'echo index-present>>"%CRONOS_GRAPHIFY_MARKER%"'
        'echo %*>>"%CRONOS_GRAPHIFY_MARKER%"'
        'exit /b 23'
    ) -Encoding ASCII

    $oldPath = $env:PATH
    $oldGraphifyMarker = $env:CRONOS_GRAPHIFY_MARKER
    $oldContextIndex = $env:CRONOS_CONTEXT_INDEX
    $env:PATH = "$fakeCommandRoot;$oldPath"
    $env:CRONOS_GRAPHIFY_MARKER = $markerPath
    $env:CRONOS_CONTEXT_INDEX = Join-Path $controlCenterPath 'INDICE-PROYECTOS.md'

    $reparseControlCenter = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Session',
            '-ProjectsRoot', $projectsRoot,
            '-ControlCenterPath', $reparseControlCenterPath,
            '-WhatIf'
        )
    Assert-True ($reparseControlCenter.ExitCode -ne 0) 'a reparse-point context output root must be rejected'
    Assert-True ($reparseControlCenter.Text -match '(?i)reparse') 'the context reparse-point error should identify the unsafe path'

    New-Item -ItemType Directory -Path $reparseContextTemporaryTargetPath -Force | Out-Null
    New-Item -ItemType Directory -Path (Split-Path -Parent $reparseContextTemporaryPath) -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseContextTemporaryPath -Target $reparseContextTemporaryTargetPath -Force | Out-Null
    $reparseContextTemporaryRun = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Session',
            '-ProjectsRoot', $projectsRoot,
            '-ControlCenterPath', $reparseContextControlCenterPath,
            '-WhatIf'
        )
    Assert-True ($reparseContextTemporaryRun.ExitCode -ne 0) 'a reparse-point context temporary path must be rejected'
    Assert-True ($reparseContextTemporaryRun.Text -match '(?i)reparse') 'the context temporary reparse-point error should identify the unsafe path'
    if (Test-Path -LiteralPath $reparseContextTemporaryPath) {
        [System.IO.Directory]::Delete($reparseContextTemporaryPath, $false)
    }
    Remove-Item -LiteralPath $reparseContextControlCenterPath -Recurse -Force -ErrorAction Stop

    $refresh = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Session',
            '-ProjectsRoot', $projectsRoot,
            '-ControlCenterPath', $controlCenterPath
        )

    Assert-True ($refresh.ExitCode -eq 0) "index success should determine overall exit code: $($refresh.Text)"
    Assert-True (Test-Path -LiteralPath $env:CRONOS_CONTEXT_INDEX -PathType Leaf) 'index should be produced'
    $markerText = [System.IO.File]::ReadAllText($markerPath)
    Assert-True ($markerText -match 'index-present') 'Graphify should run after the index exists'
    Assert-True ($markerText -match '--code-only') 'Session mode should use scheduled code-only Graphify'

    $statePath = Join-Path $controlCenterPath 'state'
    $graphifyStatusPath = Join-Path $statePath 'graphify-status.json'
    $contextStatusPath = Join-Path $statePath 'context-status.json'
    $refreshLogPath = Join-Path $statePath 'context-refresh.log'
    Assert-True (Test-Path -LiteralPath $graphifyStatusPath -PathType Leaf) 'Graphify status should be written'
    Assert-True (Test-Path -LiteralPath $contextStatusPath -PathType Leaf) 'context status should be written'
    Assert-True (Test-Path -LiteralPath $refreshLogPath -PathType Leaf) 'refresh log should be written'

    $graphifyStatus = Read-JsonFile -Path $graphifyStatusPath
    Assert-True ($graphifyStatus.mode -eq 'Scheduled') 'Graphify status should use Scheduled mode'
    Assert-True ([int]$graphifyStatus.exitCode -eq 23) 'Graphify failure exit code should be preserved'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$graphifyStatus.startedAtUtc)) 'fallback must not overwrite a Graphify status generated in the current execution'

    $contextStatus = Read-JsonFile -Path $contextStatusPath
    Assert-True ([int]$contextStatus.indexExitCode -eq 0) 'context status should record index success'
    Assert-True ([int]$contextStatus.graphifyExitCode -eq 23) ("context status should record Graphify failure (actual: $($contextStatus.graphifyExitCode); status: $($contextStatus | ConvertTo-Json -Compress))")
    Assert-True ([int]$contextStatus.exitCode -eq 0) 'overall status should preserve index success'

    $logLines = @(Get-Content -LiteralPath $refreshLogPath -ErrorAction Stop)
    Assert-True ($logLines.Count -eq 1) 'one refresh log line should be appended'
    Assert-True ($logLines[0] -match '^\d{4}-\d{2}-\d{2}T[^|]+Z\|Session\|0\|23$') 'refresh log should contain only timestamp, mode, index code, and Graphify code'
    Assert-True ($logLines[0] -notmatch 'fixture|CRONOS|F:\\|/') 'refresh log should not contain project or environment values'

    $staleControlCenterPath = Join-Path $fixtureRoot 'stale-control-center'
    $staleStatePath = Join-Path $staleControlCenterPath 'state'
    $staleGraphifyStatusPath = Join-Path $staleStatePath 'graphify-status.json'
    New-Item -ItemType Directory -Path $staleStatePath -Force | Out-Null
    $staleStatus = [ordered]@{
        startedAtUtc = '2000-01-01T00:00:00.0000000Z'
        completedAtUtc = '2000-01-01T00:00:01.0000000Z'
        mode = 'Scheduled'
        command = 'stale command'
        exitCode = 0
        semanticMode = 'code-only'
        error = $null
    }
    [System.IO.File]::WriteAllText(
        $staleGraphifyStatusPath,
        ($staleStatus | ConvertTo-Json -Depth 5),
        (New-Object System.Text.UTF8Encoding($false))
    )
    $pathWithFakeGraphify = $env:PATH
    $powershellCommandPath = (Get-Command powershell.exe -CommandType Application -ErrorAction Stop).Path
    $powershellDirectory = Split-Path -Parent $powershellCommandPath
    $systemRoot = [Environment]::GetEnvironmentVariable('SystemRoot')
    try {
        $env:PATH = "$powershellDirectory;$systemRoot\System32"
        $fallback = Invoke-PowerShellScript `
            -Path $orchestratorPath `
            -Arguments @(
                '-Mode', 'Scheduled',
                '-ProjectsRoot', $projectsRoot,
                '-ControlCenterPath', $staleControlCenterPath
            )
    }
    finally {
        $env:PATH = $pathWithFakeGraphify
    }
    Assert-True ($fallback.ExitCode -eq 0) "fallback fixture should preserve index success: $($fallback.Text)"
    $fallbackStatus = Read-JsonFile -Path $staleGraphifyStatusPath
    Assert-True ([int]$fallbackStatus.exitCode -ne 0) 'fallback should replace a stale Graphify status'
    Assert-True ([string]$fallbackStatus.startedAtUtc -ne [string]$staleStatus.startedAtUtc) 'fallback status should belong to the current execution'

    $indexFailureProjectsRoot = Join-Path $fixtureRoot 'missing-projects-root'
    $indexFailureControlCenterPath = Join-Path $fixtureRoot 'index-failure-control-center'
    New-Item -ItemType Directory -Path $indexFailureControlCenterPath -Force | Out-Null
    $markerBeforeIndexFailure = Get-FileFingerprint -Path $markerPath
    $indexFailure = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Scheduled',
            '-ProjectsRoot', $indexFailureProjectsRoot,
            '-ControlCenterPath', $indexFailureControlCenterPath
        )
    Assert-True ($indexFailure.ExitCode -eq 1) "missing ProjectsRoot should return global code 1: $($indexFailure.Text)"
    Assert-True ($markerBeforeIndexFailure -eq (Get-FileFingerprint -Path $markerPath)) 'Graphify must not be invoked when index validation fails'

    $whatIfProjectsRoot = Join-Path $fixtureRoot 'whatif-projects'
    $whatIfControlCenterPath = Join-Path $fixtureRoot 'whatif-control-center'
    New-Item -ItemType Directory -Path (Join-Path $whatIfProjectsRoot 'beta') -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $whatIfProjectsRoot 'beta\README.md') -Value '# fixture' -Encoding UTF8
    $whatIfFixtureFingerprintBefore = Get-FileFingerprint -Path $fixtureRoot
    $whatIfMarkerFingerprintBefore = Get-FileFingerprint -Path $markerPath
    $whatIfControlCenterFingerprintBefore = Get-FileFingerprint -Path $whatIfControlCenterPath
    $whatIfOutputPaths = @(
        (Join-Path $whatIfControlCenterPath 'INDICE-PROYECTOS.md'),
        (Join-Path $whatIfControlCenterPath 'state\context-status.json'),
        (Join-Path $whatIfControlCenterPath 'state\graphify-status.json'),
        (Join-Path $whatIfControlCenterPath 'state\context-refresh.log')
    )
    $whatIfOutputFingerprintsBefore = @{}
    foreach ($outputPath in $whatIfOutputPaths) {
        $whatIfOutputFingerprintsBefore[$outputPath] = Get-FileFingerprint -Path $outputPath
    }
    $whatIf = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Scheduled',
            '-ProjectsRoot', $whatIfProjectsRoot,
            '-ControlCenterPath', $whatIfControlCenterPath,
            '-WhatIf'
        )

    Assert-True ($whatIf.ExitCode -eq 0) "orchestrator WhatIf should exit successfully: $($whatIf.Text)"
    Assert-True ($whatIf.Text -match 'actualizar-indice\.ps1') 'WhatIf should print the index child command'
    Assert-True ($whatIf.Text -match 'actualizar-graphify\.ps1') 'WhatIf should print the Graphify child command'
    Assert-True ($whatIf.Text -match '-Mode Scheduled') 'WhatIf should print scheduled Graphify mode'
    Assert-True ($whatIfFixtureFingerprintBefore -eq (Get-FileFingerprint -Path $fixtureRoot)) 'orchestrator WhatIf must not change the fixture root'
    Assert-True ($whatIfMarkerFingerprintBefore -eq (Get-FileFingerprint -Path $markerPath)) 'orchestrator WhatIf must not invoke Graphify'
    Assert-True ($whatIfControlCenterFingerprintBefore -eq (Get-FileFingerprint -Path $whatIfControlCenterPath)) 'orchestrator WhatIf must not create the control center'
    foreach ($outputPath in $whatIfOutputPaths) {
        Assert-True ($whatIfOutputFingerprintsBefore[$outputPath] -eq (Get-FileFingerprint -Path $outputPath)) "orchestrator WhatIf must not change output '$outputPath'"
    }

    $projectRootPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $realProjectsRoot = [System.IO.Path]::GetFullPath((Join-Path $projectRootPath '..'))
    $realControlCenterPath = $projectRootPath
    $unsafeProjectControlCenterPath = Join-Path $realProjectsRoot 'hachi-greciaspa'
    $unsafeControlCenter = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @(
            '-Mode', 'Scheduled',
            '-ProjectsRoot', $realProjectsRoot,
            '-ControlCenterPath', $unsafeProjectControlCenterPath,
            '-WhatIf'
        )
    Assert-True ($unsafeControlCenter.ExitCode -ne 0) 'a project directory must not be used as the context output root'
    Assert-True ($unsafeControlCenter.Text -match [regex]::Escape($unsafeProjectControlCenterPath)) 'the rejected context output root should appear in the error'
    Assert-True ($unsafeControlCenter.Text -match '(?i)inside the control center') 'the context error should explain the safe output root'
    Assert-True ($unsafeControlCenter.Text -match '(?i)equal the configured control center') 'the context error should explain the configured output root'

    $realDefaultOutputPaths = @(
        (Join-Path $realControlCenterPath 'INDICE-PROYECTOS.md'),
        (Join-Path $realControlCenterPath 'state\context-status.json'),
        (Join-Path $realControlCenterPath 'state\graphify-status.json'),
        (Join-Path $realControlCenterPath 'state\context-refresh.log')
    )
    $realDefaultOutputFingerprintsBefore = @{}
    foreach ($outputPath in $realDefaultOutputPaths) {
        $realDefaultOutputFingerprintsBefore[$outputPath] = Get-FileFingerprint -Path $outputPath
    }
    $defaultWhatIf = Invoke-PowerShellScript `
        -Path $orchestratorPath `
        -Arguments @('-Mode', 'Scheduled', '-WhatIf')
    Assert-True ($defaultWhatIf.ExitCode -eq 0) "default WhatIf should exit 0: $($defaultWhatIf.Text)"
    Assert-True ($defaultWhatIf.Text -match [regex]::Escape($realProjectsRoot)) 'default WhatIf should print the configured projects root'
    Assert-True ($defaultWhatIf.Text -match [regex]::Escape($realControlCenterPath)) 'default WhatIf should print the configured control center'
    foreach ($outputPath in $realDefaultOutputPaths) {
        Assert-True ($realDefaultOutputFingerprintsBefore[$outputPath] -eq (Get-FileFingerprint -Path $outputPath)) "default WhatIf must not change real output '$outputPath'"
    }

    $schedulerOutput = @(& $schedulerPath -WhatIf -DayOfWeek Sunday -At '03:00' 2>&1)
    $schedulerText = Get-TextOutput -Output $schedulerOutput
    Assert-True ($schedulerText -match 'Cronos-Actualizar-Contexto') 'scheduler WhatIf should print the task name'
    Assert-True ($schedulerText -match 'Sunday') 'scheduler WhatIf should print the trigger day'
    Assert-True ($schedulerText -match '03:00') 'scheduler WhatIf should print the trigger time'
    Assert-True ($schedulerText -match 'powershell\.exe') 'scheduler WhatIf should print the action'
    Assert-True ($schedulerText -match 'actualizar-contexto\.ps1') 'scheduler WhatIf should print the orchestrator path'
    Assert-True ($schedulerText -match 'InteractiveToken') 'scheduler WhatIf should print the interactive token logon type'
    Assert-True ($schedulerText -match '(?i)limited') 'scheduler WhatIf should print limited privileges'
    Assert-True ($schedulerText -match '(?i)no stored credentials') 'scheduler WhatIf should print that credentials are not stored'
    Assert-True (-not $script:schedulerRegisterCalled) 'scheduler WhatIf must not register a task'
    $schedulerProcess = Invoke-PowerShellScript `
        -Path $schedulerPath `
        -Arguments @('-WhatIf', '-DayOfWeek', 'Sunday', '-At', '03:00')
    Assert-True ($schedulerProcess.ExitCode -eq 0) "scheduler WhatIf should return code 0: $($schedulerProcess.Text)"

    $removalOutput = @(& $removalPath -WhatIf 2>&1)
    $removalText = Get-TextOutput -Output $removalOutput
    Assert-True ($removalText -match 'not-found') 'removal WhatIf should report an absent task safely'
    Assert-True (-not $script:schedulerRemovalCalled) 'removal WhatIf must not remove a task'
    $removalProcess = Invoke-PowerShellScript -Path $removalPath -Arguments @('-WhatIf')
    Assert-True ($removalProcess.ExitCode -eq 0) "removal WhatIf should return code 0: $($removalProcess.Text)"

    $global:cronosSchedulerQueryShouldFail = $true
    $removalErrorOutput = @(& $removalPath -WhatIf 2>&1)
    $removalErrorText = Get-TextOutput -Output $removalErrorOutput
    $removalErrorCode = [int]$LASTEXITCODE
    $global:cronosSchedulerQueryShouldFail = $false
    Assert-True ($removalErrorText -match 'Unable to query scheduled task') 'scheduler query errors should be explicit'
    Assert-True ($removalErrorText -match 'access denied') 'scheduler query error details should be preserved'
    Assert-True ($removalErrorCode -ne 0) 'scheduler query errors should return a nonzero code'

    Write-Output 'PASS: context refresh smoke test'
}
catch {
    Write-Error ("TEST FAILURE: " + $_.Exception.Message)
    exit 1
}
finally {
    if ($null -ne $oldPath) {
        $env:PATH = $oldPath
    }
    if ($null -eq $oldGraphifyMarker) {
        Remove-Item Env:CRONOS_GRAPHIFY_MARKER -ErrorAction SilentlyContinue
    }
    else {
        $env:CRONOS_GRAPHIFY_MARKER = $oldGraphifyMarker
    }
    if ($null -eq $oldContextIndex) {
        Remove-Item Env:CRONOS_CONTEXT_INDEX -ErrorAction SilentlyContinue
    }
    else {
        $env:CRONOS_CONTEXT_INDEX = $oldContextIndex
    }
    if ($null -ne $reparseContextTemporaryPath -and (Test-Path -LiteralPath $reparseContextTemporaryPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseContextTemporaryPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseContextTemporaryPath, $false)
        }
    }
    if ($null -ne $reparseControlCenterPath -and (Test-Path -LiteralPath $reparseControlCenterPath)) {
        [System.IO.Directory]::Delete($reparseControlCenterPath, $false)
    }
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name cronosSchedulerQueryShouldFail -Scope Global -ErrorAction SilentlyContinue
}
