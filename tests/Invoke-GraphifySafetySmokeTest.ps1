Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\scripts\actualizar-graphify.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cronos-graphify-smoke-' + [guid]::NewGuid().ToString('N'))
$fakeCommandRoot = Join-Path $fixtureRoot 'fake-command'
$environmentCommandRoot = Join-Path $fixtureRoot 'environment-command'
$failureCommandRoot = Join-Path $fixtureRoot 'failure-command'
$markerPath = Join-Path $fixtureRoot 'graphify-invoked.txt'
$environmentMarkerPath = Join-Path $fixtureRoot 'graphify-environment.txt'
$oldPath = $null
$oldFixtureEnv = $null
$oldEnvironmentMarker = $null
$oldGraphifyOut = $null
$reparseControlCenterPath = $null
$reparseStatePath = $null
$reparseGraphifyOutPath = $null
$nestedReparsePath = $null
$reparseStatusTemporaryPath = $null
$nestedOutputReparsePath = $null

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

function Invoke-GraphifyScript {
    param(
        [string]$Mode,
        [string]$ProjectsRoot,
        [string]$ControlCenterPath,
        [switch]$WhatIf
    )

    $arguments = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $scriptPath,
        '-Mode', $Mode,
        '-ProjectsRoot', $ProjectsRoot,
        '-ControlCenterPath', $ControlCenterPath
    )
    if ($WhatIf) {
        $arguments += '-WhatIf'
    }

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe @arguments 2>&1)
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

function Get-TreeFingerprint {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return '<absent>'
    }

    $rows = @(
        Get-ChildItem -LiteralPath $Path -File -Recurse -Force -ErrorAction Stop |
            ForEach-Object {
                $relative = $_.FullName.Substring($Path.Length).TrimStart('\', '/')
                "$relative|$($_.Length)|$($_.LastWriteTimeUtc.ToString('o'))"
            } |
            Sort-Object
    )
    return [string]::Join("`n", $rows)
}

try {
    if (-not (Test-Path -LiteralPath $scriptPath -PathType Leaf)) {
        throw "RED: production script is absent: $scriptPath"
    }

    $projectsRoot = Join-Path $fixtureRoot 'projects'
    $controlCenterPath = Join-Path $fixtureRoot 'control-center'
    $sourcePath = Join-Path $projectsRoot 'src'
    $nodeModulesPath = Join-Path $projectsRoot 'node_modules'
    $distPath = Join-Path $projectsRoot 'dist'
    $fixtureGraphifyOutPath = Join-Path $projectsRoot 'graphify-out'
    $fixtureGraphifyOutFilePath = Join-Path $fixtureGraphifyOutPath 'stale-graphify-output.ts'
    $firebaseConfigPath = Join-Path $projectsRoot '.firebase-config\configstore'
    $playwrightBrowsersPath = Join-Path $projectsRoot '.playwright-browsers\chromium'
    $reparseControlCenterPath = Join-Path $fixtureRoot 'reparse-control-center'
    $reparseStatePath = Join-Path $controlCenterPath 'state'
    $reparseGraphifyOutPath = Join-Path $controlCenterPath 'graphify-out'
    $nestedReparseTargetPath = Join-Path $fixtureRoot 'nested-reparse-target'
    $nestedReparsePath = Join-Path $sourcePath 'linked-outside'
    $reparseStatusTemporaryPath = Join-Path $controlCenterPath 'state\graphify-status.json.tmp'
    $nestedOutputReparsePath = Join-Path $controlCenterPath 'graphify-out\linked-output'
    $fixtureIgnorePath = Join-Path $projectsRoot '.graphifyignore'
    $sharedIgnorePath = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) '.graphifyignore'
    $realOutputPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'graphify-out'
    $realOutputFingerprintBefore = Get-TreeFingerprint -Path $realOutputPath

    New-Item -ItemType Directory -Path $sourcePath -Force | Out-Null
    New-Item -ItemType Directory -Path $nodeModulesPath -Force | Out-Null
    New-Item -ItemType Directory -Path $distPath -Force | Out-Null
    New-Item -ItemType Directory -Path $fixtureGraphifyOutPath -Force | Out-Null
    New-Item -ItemType Directory -Path $firebaseConfigPath -Force | Out-Null
    New-Item -ItemType Directory -Path $playwrightBrowsersPath -Force | Out-Null
    New-Item -ItemType Directory -Path $fakeCommandRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $environmentCommandRoot -Force | Out-Null
    New-Item -ItemType Directory -Path $failureCommandRoot -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseControlCenterPath -Target $sourcePath -Force | Out-Null

    Set-Content -LiteralPath (Join-Path $sourcePath 'App.ts') -Value 'export const appName: string = "fixture";' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $projectsRoot '.env') -Value 'TOKEN=secret-value' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $nodeModulesPath 'ignored.js') -Value 'secret-value' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $distPath 'generated.js') -Value 'secret-value' -Encoding UTF8
    Set-Content -LiteralPath $fixtureGraphifyOutFilePath -Value 'stale fixture Graphify output' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $firebaseConfigPath 'firebase-tools.json') -Value 'secret-value' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $playwrightBrowsersPath 'browser-cache.json') -Value 'secret-value' -Encoding UTF8
    Set-Content -LiteralPath $fixtureIgnorePath -Value @(
        'Analista/'
        'graphify-out/'
        '**/.git/'
        '**/node_modules/'
        '**/dist/'
        '**/build/'
        '**/coverage/'
        '**/.next/'
        '**/.nuxt/'
        '**/.cache/'
        '**/.firebase-config/'
        '**/.playwright-browsers/'
        '**/.env'
        '**/.env.*'
        '**/*.pem'
        '**/*.key'
        '**/*.p12'
        '**/*.pfx'
        '**/*credentials*'
        '**/*secret*'
    ) -Encoding UTF8

    $sharedIgnoreLines = @(Get-Content -LiteralPath $sharedIgnorePath -ErrorAction Stop)
    $fixtureIgnoreLines = @(Get-Content -LiteralPath $fixtureIgnorePath -ErrorAction Stop)
    Assert-True ($sharedIgnoreLines -contains 'graphify-out/') 'shared root ignore should approve graphify-out exclusion'
    Assert-True ($sharedIgnoreLines -contains '**/.firebase-config/') 'shared root ignore should exclude Firebase configuration'
    Assert-True ($sharedIgnoreLines -contains '**/.playwright-browsers/') 'shared root ignore should exclude Playwright browser output'
    Assert-True ($fixtureIgnoreLines -contains 'graphify-out/') 'fixture ignore should contain graphify-out exclusion'
    Assert-True ($fixtureIgnoreLines -contains '**/.firebase-config/') 'fixture ignore should exclude Firebase configuration'
    Assert-True ($fixtureIgnoreLines -contains '**/.playwright-browsers/') 'fixture ignore should exclude Playwright browser output'

    $fakeCommandPath = Join-Path $fakeCommandRoot 'graphify.cmd'
    Set-Content -LiteralPath $fakeCommandPath -Value @(
        '@echo off'
        'echo invoked>>"%CRONOS_GRAPHIFY_MARKER%"'
        'exit /b 97'
    ) -Encoding ASCII

    $environmentCommandPath = Join-Path $environmentCommandRoot 'graphify.cmd'
    Set-Content -LiteralPath $environmentCommandPath -Value @(
        '@echo off'
        'if "%1"=="--version" echo graphify 0.9.32'
        'if "%1"=="--version" exit /b 0'
        'echo GRAPHIFY_OUT=%GRAPHIFY_OUT%>>"%CRONOS_GRAPHIFY_ENV_MARKER%"'
        'exit /b 0'
    ) -Encoding ASCII

    $failureCommandPath = Join-Path $failureCommandRoot 'graphify.cmd'
    Set-Content -LiteralPath $failureCommandPath -Value @(
        '@echo off'
        'if "%1"=="--version" echo graphify 0.9.32'
        'if "%1"=="--version" exit /b 0'
        'echo fixture extraction failure 1>&2'
        'exit /b 23'
    ) -Encoding ASCII

    New-Item -ItemType Directory -Path $controlCenterPath -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseStatePath -Target $sourcePath -Force | Out-Null
    $reparseState = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -WhatIf
    Assert-True ($reparseState.ExitCode -ne 0) 'a reparse-point Graphify state directory must be rejected'
    Assert-True ($reparseState.Text -match '(?i)reparse') 'the Graphify state reparse-point error should identify the unsafe path'
    [System.IO.Directory]::Delete($reparseStatePath, $false)

    New-Item -ItemType Junction -Path $reparseGraphifyOutPath -Target $sourcePath -Force | Out-Null
    $reparseGraphifyOut = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -WhatIf
    Assert-True ($reparseGraphifyOut.ExitCode -ne 0) 'a reparse-point Graphify output directory must be rejected'
    Assert-True ($reparseGraphifyOut.Text -match '(?i)reparse') 'the Graphify output reparse-point error should identify the unsafe path'
    [System.IO.Directory]::Delete($reparseGraphifyOutPath, $false)
    Remove-Item -LiteralPath $controlCenterPath -Force -ErrorAction Stop

    New-Item -ItemType Directory -Path $nestedReparseTargetPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedReparseTargetPath 'outside.ts') -Value 'export const outside = true;' -Encoding UTF8
    New-Item -ItemType Junction -Path $nestedReparsePath -Target $nestedReparseTargetPath -Force | Out-Null
    $nestedReparse = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -WhatIf
    Assert-True ($nestedReparse.ExitCode -ne 0) 'a nested reparse point must be rejected before Graphify'
    Assert-True ($nestedReparse.Text -match '(?i)reparse') 'the nested Graphify reparse-point error should identify the unsafe path'
    [System.IO.Directory]::Delete($nestedReparsePath, $false)

    New-Item -ItemType Directory -Path (Split-Path -Parent $reparseStatusTemporaryPath) -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseStatusTemporaryPath -Target $sourcePath -Force | Out-Null
    $reparseStatusTemporary = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath
    Assert-True ($reparseStatusTemporary.ExitCode -ne 0) 'a reparse-point Graphify status temporary path must be rejected'
    Assert-True ($reparseStatusTemporary.Text -match '(?i)reparse') 'the Graphify status temporary reparse-point error should identify the unsafe path'
    if (Test-Path -LiteralPath $reparseStatusTemporaryPath) {
        [System.IO.Directory]::Delete($reparseStatusTemporaryPath, $false)
    }

    New-Item -ItemType Directory -Path (Split-Path -Parent $nestedOutputReparsePath) -Force | Out-Null
    New-Item -ItemType Junction -Path $nestedOutputReparsePath -Target $sourcePath -Force | Out-Null
    $nestedOutput = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -WhatIf
    Assert-True ($nestedOutput.ExitCode -ne 0) 'a nested Graphify output reparse point must be rejected'
    Assert-True ($nestedOutput.Text -match '(?i)reparse') 'the nested Graphify output reparse-point error should identify the unsafe path'
    [System.IO.Directory]::Delete($nestedOutputReparsePath, $false)
    [System.IO.Directory]::Delete((Join-Path $controlCenterPath 'graphify-out'), $true)
    Remove-Item -LiteralPath $controlCenterPath -Recurse -Force -ErrorAction Stop

    $reparseControlCenter = Invoke-GraphifyScript `
        -Mode Scheduled `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $reparseControlCenterPath `
        -WhatIf
    Assert-True ($reparseControlCenter.ExitCode -ne 0) 'a reparse-point Graphify output root must be rejected'
    Assert-True ($reparseControlCenter.Text -match '(?i)reparse') 'the Graphify reparse-point error should identify the unsafe path'

    $oldPath = $env:PATH
    $oldMarker = $env:CRONOS_GRAPHIFY_MARKER
    $env:CRONOS_GRAPHIFY_MARKER = $markerPath
    try {
        $env:PATH = "$fakeCommandRoot;$oldPath"
        $whatIf = Invoke-GraphifyScript -Mode Scheduled -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -WhatIf
    }
    finally {
        $env:PATH = $oldPath
        if ($null -eq $oldMarker) {
            Remove-Item Env:CRONOS_GRAPHIFY_MARKER -ErrorAction SilentlyContinue
        }
        else {
            $env:CRONOS_GRAPHIFY_MARKER = $oldMarker
        }
    }

    Assert-True ($whatIf.ExitCode -eq 0) '-WhatIf should exit successfully'
    Assert-True ($whatIf.Text -match 'graphify\s+extract') '-WhatIf should print the planned Graphify command'
    Assert-True (-not (Test-Path -LiteralPath $markerPath)) '-WhatIf must not invoke Graphify'
    Assert-True (-not (Test-Path -LiteralPath $controlCenterPath)) '-WhatIf must not create the output directory'

    $oldPath = $env:PATH
    $oldEnvironmentMarker = $env:CRONOS_GRAPHIFY_ENV_MARKER
    $oldGraphifyOut = $env:GRAPHIFY_OUT
    $env:CRONOS_GRAPHIFY_ENV_MARKER = $environmentMarkerPath
    $env:GRAPHIFY_OUT = 'prior-graphify-out'
    try {
        $env:PATH = "$environmentCommandRoot;$oldPath"
        $environmentRun = Invoke-GraphifyScript -Mode Scheduled -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath
    }
    finally {
        $env:PATH = $oldPath
        if ($null -eq $oldEnvironmentMarker) {
            Remove-Item Env:CRONOS_GRAPHIFY_ENV_MARKER -ErrorAction SilentlyContinue
        }
        else {
            $env:CRONOS_GRAPHIFY_ENV_MARKER = $oldEnvironmentMarker
        }
        if ($null -eq $oldGraphifyOut) {
            Remove-Item Env:GRAPHIFY_OUT -ErrorAction SilentlyContinue
        }
        else {
            $env:GRAPHIFY_OUT = $oldGraphifyOut
        }
    }

    $expectedGraphifyOut = Join-Path $controlCenterPath 'graphify-out'
    Assert-True ($environmentRun.ExitCode -eq 0) "environment fixture should exit 0: $($environmentRun.Text)"
    Assert-True (Test-Path -LiteralPath $environmentMarkerPath -PathType Leaf) 'environment fixture should record GRAPHIFY_OUT'
    $environmentMarker = [System.IO.File]::ReadAllText($environmentMarkerPath).Trim()
    Assert-True ($environmentMarker -eq "GRAPHIFY_OUT=$expectedGraphifyOut") 'Graphify child should receive the temporary control-center GRAPHIFY_OUT'

    $scheduled = Invoke-GraphifyScript -Mode Scheduled -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath
    Assert-True ($scheduled.ExitCode -eq 0) "scheduled extraction should exit 0: $($scheduled.Text)"

    $graphPath = Join-Path $controlCenterPath 'graphify-out\graph.json'
    $statusPath = Join-Path $controlCenterPath 'state\graphify-status.json'
    Assert-True (Test-Path -LiteralPath $graphPath -PathType Leaf) 'temporary graphify-out/graph.json should exist'
    Assert-True (Test-Path -LiteralPath $statusPath -PathType Leaf) 'temporary graphify status should exist'

    $graphText = [System.IO.File]::ReadAllText($graphPath)
    Assert-True (($graphText -match 'App\.ts') -or ($graphText -match 'appName')) 'the graph should include the TypeScript source or symbol'
    foreach ($forbidden in @('.env', 'node_modules', 'dist', 'graphify-out', 'stale-graphify-output.ts', '.firebase-config', 'firebase-tools.json', '.playwright-browsers', 'browser-cache.json', 'TOKEN=', 'secret-value')) {
        Assert-True ($graphText -notmatch [regex]::Escape($forbidden)) "the graph must not contain '$forbidden'"
    }
    Assert-True ($graphText -notmatch [regex]::Escape($fixtureGraphifyOutPath)) 'the graph must not contain the fixture output path'
    Assert-True ($graphText -notmatch [regex]::Escape($fixtureGraphifyOutPath.Replace('\', '/'))) 'the graph must not contain the fixture output path with forward slashes'
    Assert-True ($graphText -notmatch [regex]::Escape($firebaseConfigPath)) 'the graph must not contain the Firebase configuration path'
    Assert-True ($graphText -notmatch [regex]::Escape($firebaseConfigPath.Replace('\', '/'))) 'the graph must not contain the Firebase configuration path with forward slashes'
    Assert-True ($graphText -notmatch [regex]::Escape($playwrightBrowsersPath)) 'the graph must not contain the Playwright browser path'
    Assert-True ($graphText -notmatch [regex]::Escape($playwrightBrowsersPath.Replace('\', '/'))) 'the graph must not contain the Playwright browser path with forward slashes'

    $status = Read-JsonFile -Path $statusPath
    foreach ($propertyName in @('startedAtUtc', 'completedAtUtc', 'mode', 'command', 'exitCode', 'semanticMode', 'error')) {
        Assert-True ($null -ne $status.PSObject.Properties[$propertyName]) "status should contain '$propertyName'"
    }
    Assert-True ($status.mode -eq 'Scheduled') 'status should record Scheduled mode'
    Assert-True ($status.semanticMode -eq 'code-only') 'status should record code-only mode'
    Assert-True ([int]$status.exitCode -eq 0) 'status should record exit code 0'
    Assert-True ([string]$status.command -match '--code-only') 'status command should record --code-only'
    Assert-True ([string]$status.command -match '--no-cluster') 'status command should record --no-cluster'
    Assert-True ([string]$status.command -notmatch 'secret-value') 'status must not contain fixture secrets'
    Assert-True (-not (Test-Path -LiteralPath "$statusPath.tmp")) 'status temporary file should be removed'

    $failureControlCenterPath = Join-Path $fixtureRoot 'failure-output'
    $oldPath = $env:PATH
    try {
        $env:PATH = "$failureCommandRoot;$oldPath"
        $failure = Invoke-GraphifyScript -Mode Scheduled -ProjectsRoot $projectsRoot -ControlCenterPath $failureControlCenterPath
    }
    finally {
        $env:PATH = $oldPath
    }
    Assert-True ($failure.ExitCode -eq 23) "scheduled extraction should return the Graphify failure exit code (actual: $($failure.ExitCode); output: $($failure.Text))"
    $failureStatusPath = Join-Path $failureControlCenterPath 'state\graphify-status.json'
    Assert-True (Test-Path -LiteralPath $failureStatusPath -PathType Leaf) 'failure status should be written'
    $failureStatus = Read-JsonFile -Path $failureStatusPath
    Assert-True ([int]$failureStatus.exitCode -eq 23) 'failure status should preserve the Graphify exit code'
    Assert-True (-not [string]::IsNullOrWhiteSpace([string]$failureStatus.error)) 'failure status should record an error'

    $realProjectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $realProjectsRoot = [System.IO.Path]::GetFullPath((Join-Path $realProjectRoot '..'))
    $unsafeProjectControlCenterPath = Join-Path $realProjectsRoot 'hachi-greciaspa'
    $oldPath = $env:PATH
    try {
        $env:PATH = "$environmentCommandRoot;$oldPath"
        $unsafeControlCenter = Invoke-GraphifyScript `
            -Mode Scheduled `
            -ProjectsRoot $realProjectsRoot `
            -ControlCenterPath $unsafeProjectControlCenterPath `
            -WhatIf
    }
    finally {
        $env:PATH = $oldPath
    }
    Assert-True ($unsafeControlCenter.ExitCode -ne 0) 'a project directory must not be used as the Graphify output root'
    Assert-True ($unsafeControlCenter.Text -match [regex]::Escape($unsafeProjectControlCenterPath)) 'the rejected Graphify output root should appear in the error'
    Assert-True ($unsafeControlCenter.Text -match '(?i)inside the control center') 'the Graphify error should explain the safe output root'
    Assert-True ($unsafeControlCenter.Text -match '(?i)equal the configured control center') 'the Graphify error should explain the configured output root'

    $oldFixtureEnv = $env:CRONOS_GRAPHIFY_FIXTURE_VALUE
    $env:CRONOS_GRAPHIFY_FIXTURE_VALUE = 'fixture-env-not-print'
    try {
        $manual = Invoke-GraphifyScript -Mode Manual -ProjectsRoot $projectsRoot -ControlCenterPath (Join-Path $fixtureRoot 'manual-output')
    }
    finally {
        if ($null -eq $oldFixtureEnv) {
            Remove-Item Env:CRONOS_GRAPHIFY_FIXTURE_VALUE -ErrorAction SilentlyContinue
        }
        else {
            $env:CRONOS_GRAPHIFY_FIXTURE_VALUE = $oldFixtureEnv
        }
    }
    Assert-True ($manual.ExitCode -ne 0) 'Manual mode should fail while disabled'
    Assert-True ($manual.Text -match 'semantic extraction') 'Manual mode should explain the semantic extraction boundary'
    Assert-True (($manual.Text -match 'active Cronos\s+session') -or ($manual.Text -match 'explicit backend/cost approval')) 'Manual mode should explain the approval boundary'
    Assert-True ($manual.Text -notmatch 'secret-value') 'Manual mode must not print environment or fixture secret values'
    Assert-True ($manual.Text -notmatch 'fixture-env-not-print') 'Manual mode must not print environment values'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $fixtureRoot 'manual-output'))) 'rejected Manual mode must not create output'

    $realOutputFingerprintAfter = Get-TreeFingerprint -Path $realOutputPath
    Assert-True ($realOutputFingerprintBefore -eq $realOutputFingerprintAfter) 'the real Analista graphify-out must remain untouched'

    Write-Output 'PASS: Graphify safety smoke test'
}
catch {
    Write-Error ("TEST FAILURE: " + $_.Exception.Message)
    exit 1
}
finally {
    if ($null -ne $oldPath) {
        $env:PATH = $oldPath
    }
    if ($null -ne $reparseControlCenterPath -and (Test-Path -LiteralPath $reparseControlCenterPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseControlCenterPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseControlCenterPath, $false)
        }
    }
    if ($null -ne $reparseStatePath -and (Test-Path -LiteralPath $reparseStatePath)) {
        $reparseItem = Get-Item -LiteralPath $reparseStatePath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseStatePath, $false)
        }
    }
    if ($null -ne $reparseGraphifyOutPath -and (Test-Path -LiteralPath $reparseGraphifyOutPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseGraphifyOutPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseGraphifyOutPath, $false)
        }
    }
    if ($null -ne $nestedReparsePath -and (Test-Path -LiteralPath $nestedReparsePath)) {
        $reparseItem = Get-Item -LiteralPath $nestedReparsePath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($nestedReparsePath, $false)
        }
    }
    if ($null -ne $reparseStatusTemporaryPath -and (Test-Path -LiteralPath $reparseStatusTemporaryPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseStatusTemporaryPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseStatusTemporaryPath, $false)
        }
    }
    if ($null -ne $nestedOutputReparsePath -and (Test-Path -LiteralPath $nestedOutputReparsePath)) {
        $reparseItem = Get-Item -LiteralPath $nestedOutputReparsePath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($nestedOutputReparsePath, $false)
        }
    }
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
