Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$scriptPath = Join-Path $PSScriptRoot '..\scripts\actualizar-indice.ps1'
$fixtureRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('cronos-index-smoke-' + [guid]::NewGuid().ToString('N'))
$nestedReparsePath = $null
$reparseTemporaryPath = $null
$reparseControlCenterPath = $null

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        throw "Assertion failed: $Message"
    }
}

function Assert-ByteArraysEqual {
    param(
        [byte[]]$Expected,
        [byte[]]$Actual,
        [string]$Message
    )

    Assert-True ($Expected.Length -eq $Actual.Length) $Message
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        Assert-True ($Expected[$index] -eq $Actual[$index]) $Message
    }
}

function Remove-FixtureBackups {
    param([string]$RootPath)

    foreach ($backup in @(Get-ChildItem -LiteralPath $RootPath -Filter '*.bak' -File -ErrorAction Stop)) {
        Remove-Item -LiteralPath $backup.FullName -Force -ErrorAction Stop
    }
}

function Get-CollectionCount {
    param([object]$Value)

    if ($null -eq $Value) {
        return 0
    }

    return @($Value).Count
}

function Invoke-Indexer {
    param(
        [string]$ConfigPath,
        [string]$ProjectsRoot,
        [string]$ControlCenterPath,
        [string]$OutputPath,
        [string]$StatusPath
    )

    $global:LASTEXITCODE = 0
    try {
        $output = @(& $scriptPath `
            -ConfigPath $ConfigPath `
            -ProjectsRoot $ProjectsRoot `
            -ControlCenterPath $ControlCenterPath `
            -OutputPath $OutputPath `
            -StatusPath $StatusPath `
            2>&1)
    }
    catch {
        throw "Index invocation failed: $($_.Exception.Message)"
    }

    $errors = @($output | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] })
    if ($errors.Count -gt 0) {
        throw "Index invocation emitted an error: $($errors[0])"
    }

    $exitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $exitCode -and $exitCode -ne 0) {
        throw "Index invocation returned exit code $exitCode"
    }

    return $output
}

function Invoke-IndexerProcess {
    param(
        [string]$ConfigPath,
        [string]$ProjectsRoot,
        [string]$ControlCenterPath,
        [string]$OutputPath,
        [string]$StatusPath
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
            -ConfigPath $ConfigPath `
            -ProjectsRoot $ProjectsRoot `
            -ControlCenterPath $ControlCenterPath `
            -OutputPath $OutputPath `
            -StatusPath $StatusPath `
            2>&1)
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = [int]$LASTEXITCODE
        Text = ([string]::Join("`n", @($output | ForEach-Object {
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                [string]$_.Exception.Message
            }
            else {
                [string]$_
            }
        }))) -replace '[\r\n]+\s*', ''
    }
}

function Read-JsonFile {
    param([string]$Path)

    return ([System.IO.File]::ReadAllText($Path) | ConvertFrom-Json)
}

try {
    $projectsRoot = Join-Path $fixtureRoot 'projects'
    $controlCenterPath = Join-Path $projectsRoot 'control-center'
    $configPath = Join-Path $controlCenterPath 'contexto.json'
    $outputPath = Join-Path $controlCenterPath 'INDICE-PROYECTOS.md'
    $statusPath = Join-Path $controlCenterPath 'state\context-status.json'
    $alphaPath = Join-Path $projectsRoot 'alpha'
    $alphaDocsPath = Join-Path $alphaPath 'docs'
    $alphaNodeModulesPath = Join-Path $alphaPath 'node_modules'
    $readmePath = Join-Path $alphaPath 'README.md'
    $graphifyOutPath = Join-Path $projectsRoot 'graphify-out'
    $graphifyOutFilePath = Join-Path $graphifyOutPath 'stale-cache.json'
    $pathOnlyProjectsRoot = Join-Path $fixtureRoot 'path-only-projects'
    $pathOnlyControlCenterPath = Join-Path $pathOnlyProjectsRoot 'control-center'
    $pathOnlyOutputPath = Join-Path $pathOnlyControlCenterPath 'INDICE-PROYECTOS.md'
    $pathOnlyStatusPath = Join-Path $pathOnlyControlCenterPath 'state\context-status.json'
    $unsafeProjectsDirectory = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $unsafeControlCenterPath = Join-Path $unsafeProjectsDirectory 'hachi-greciaspa'
    $unsafeOutputPath = Join-Path $unsafeControlCenterPath 'cronos-index-output.md'
    $unsafeStatusPath = Join-Path $unsafeControlCenterPath 'cronos-index-status.json'
    $unsafeProjectsRootFile = Join-Path $fixtureRoot 'unsafe-projects-root.txt'
    $unsafeConfigPath = Join-Path $fixtureRoot 'unsafe-contexto.json'
    $reparseTargetPath = Join-Path $fixtureRoot 'reparse-target'
    $reparseControlCenterPath = Join-Path $fixtureRoot 'reparse-control-center'
    $reparseOutputPath = Join-Path $reparseControlCenterPath 'INDICE-PROYECTOS.md'
    $reparseStatusPath = Join-Path $reparseControlCenterPath 'state\context-status.json'
    $nestedReparseTargetPath = Join-Path $fixtureRoot 'nested-reparse-target'
    $nestedReparsePath = Join-Path $alphaPath 'linked-outside'
    $reparseTemporaryPath = "$outputPath.tmp"

    New-Item -ItemType Directory -Path $alphaDocsPath -Force | Out-Null
    New-Item -ItemType Directory -Path $alphaNodeModulesPath -Force | Out-Null
    New-Item -ItemType Directory -Path $graphifyOutPath -Force | Out-Null
    New-Item -ItemType Directory -Path $controlCenterPath -Force | Out-Null
    New-Item -ItemType Directory -Path $pathOnlyControlCenterPath -Force | Out-Null
    New-Item -ItemType Directory -Path $reparseTargetPath -Force | Out-Null
    New-Item -ItemType Junction -Path $reparseControlCenterPath -Target $reparseTargetPath -Force | Out-Null

    Set-Content -LiteralPath $readmePath -Value '# Alpha' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $alphaPath '.env') -Value 'fixture-only-ignored-value' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $alphaNodeModulesPath 'ignored.js') -Value 'ignored fixture file' -Encoding UTF8
    Set-Content -LiteralPath $graphifyOutFilePath -Value 'stale fixture output' -Encoding UTF8

    $alphaFirebaseConfigPath = Join-Path $alphaPath '.firebase-config\configstore'
    $alphaPlaywrightBrowsersPath = Join-Path $alphaPath '.playwright-browsers\chromium'
    New-Item -ItemType Directory -Path $alphaFirebaseConfigPath -Force | Out-Null
    New-Item -ItemType Directory -Path $alphaPlaywrightBrowsersPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $alphaFirebaseConfigPath 'README.md') -Value 'ignored Firebase fixture' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $alphaFirebaseConfigPath 'firebase-tools.json') -Value 'ignored Firebase configuration' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $alphaPlaywrightBrowsersPath 'README.md') -Value 'ignored browser fixture' -Encoding UTF8
    Set-Content -LiteralPath (Join-Path $alphaPlaywrightBrowsersPath 'browser-cache.json') -Value 'ignored browser output' -Encoding UTF8
    Set-Content -LiteralPath $unsafeProjectsRootFile -Value 'not a directory' -Encoding UTF8

    $config = [ordered]@{
        projectsRoot = $projectsRoot
        controlCenter = $controlCenterPath
        indexPath = $outputPath
        statusPath = $statusPath
        ignoredDirectoryNames = @('.git', 'node_modules', 'dist', 'build', 'coverage', '.next', '.nuxt', '.cache', 'graphify-out', '.firebase-config', '.playwright-browsers')
        ignoredFilePatterns = @('.env', '.env.*', '*.pem', '*.key', '*.p12', '*.pfx', '*credentials*', '*secret*')
        knownDocumentNames = @('BRIEF.md', 'STACK.md', 'tasks.md', 'README.md')
    }
    [System.IO.File]::WriteAllText($configPath, ($config | ConvertTo-Json -Depth 4))

    $unsafeConfig = [ordered]@{
        projectsRoot = $unsafeProjectsDirectory
        controlCenter = (Split-Path -Parent $PSScriptRoot)
        indexPath = $outputPath
        statusPath = $statusPath
        ignoredDirectoryNames = $config.ignoredDirectoryNames
        ignoredFilePatterns = $config.ignoredFilePatterns
        knownDocumentNames = $config.knownDocumentNames
    }
    [System.IO.File]::WriteAllText($unsafeConfigPath, ($unsafeConfig | ConvertTo-Json -Depth 4))

    New-Item -ItemType Junction -Path $reparseTemporaryPath -Target $reparseTargetPath -Force | Out-Null
    $reparseTemporary = Invoke-IndexerProcess `
        -ConfigPath $configPath `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -OutputPath $outputPath `
        -StatusPath $statusPath
    Assert-True ($reparseTemporary.ExitCode -ne 0) 'a reparse-point index temporary path must be rejected'
    Assert-True ($reparseTemporary.Text -match '(?i)reparse') 'the index temporary reparse-point error should identify the unsafe path'
    if (Test-Path -LiteralPath $reparseTemporaryPath) {
        [System.IO.Directory]::Delete($reparseTemporaryPath, $false)
    }

    New-Item -ItemType Directory -Path $nestedReparseTargetPath -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $nestedReparseTargetPath 'outside.md') -Value 'outside fixture' -Encoding UTF8
    New-Item -ItemType Junction -Path $nestedReparsePath -Target $nestedReparseTargetPath -Force | Out-Null
    $nestedReparse = Invoke-IndexerProcess `
        -ConfigPath $configPath `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $controlCenterPath `
        -OutputPath $outputPath `
        -StatusPath $statusPath
    Assert-True ($nestedReparse.ExitCode -ne 0) 'a nested reparse point must be rejected before indexing'
    Assert-True ($nestedReparse.Text -match '(?i)reparse') 'the nested reparse-point error should identify the unsafe path'
    [System.IO.Directory]::Delete($nestedReparsePath, $false)

    $reparseControlCenter = Invoke-IndexerProcess `
        -ConfigPath $configPath `
        -ProjectsRoot $projectsRoot `
        -ControlCenterPath $reparseControlCenterPath `
        -OutputPath $reparseOutputPath `
        -StatusPath $reparseStatusPath
    Assert-True ($reparseControlCenter.ExitCode -ne 0) 'a reparse-point control center must be rejected'
    Assert-True ($reparseControlCenter.Text -match '(?i)reparse') 'the reparse-point error should identify the unsafe path'
    Assert-True (-not (Test-Path -LiteralPath $reparseOutputPath)) 'the rejected reparse output must not be created'
    Assert-True (-not (Test-Path -LiteralPath $reparseStatusPath)) 'the rejected reparse status must not be created'

    $unsafeControlCenter = Invoke-IndexerProcess `
        -ConfigPath $unsafeConfigPath `
        -ProjectsRoot $unsafeProjectsRootFile `
        -ControlCenterPath $unsafeControlCenterPath `
        -OutputPath $unsafeOutputPath `
        -StatusPath $unsafeStatusPath
    Assert-True ($unsafeControlCenter.ExitCode -ne 0) 'a real project must not be used as the index control center'
    Assert-True ($unsafeControlCenter.Text -match '(?i)ControlCenterPath') 'the index error should identify the rejected control center'
    Assert-True (($unsafeControlCenter.Text -replace '\s', '') -match [regex]::Escape(($unsafeControlCenterPath -replace '\s', ''))) 'the rejected index control center should appear in the error'
    Assert-True ($unsafeControlCenter.Text -match '(?i)inside the control center') 'the index error should explain the safe output root'
    Assert-True ($unsafeControlCenter.Text -match '(?i)equal the configured control center') 'the index error should explain the configured output root'
    Assert-True (-not (Test-Path -LiteralPath $unsafeOutputPath)) 'the rejected index output must not be created'
    Assert-True (-not (Test-Path -LiteralPath $unsafeStatusPath)) 'the rejected index status must not be created'
    Assert-True (-not (Test-Path -LiteralPath "$unsafeOutputPath.tmp")) 'the rejected index temporary output must not be created'
    Assert-True (-not (Test-Path -LiteralPath "$unsafeStatusPath.tmp")) 'the rejected index temporary status must not be created'

    $unsafeOutputPath = Join-Path $fixtureRoot 'unsafe-output\INDICE-PROYECTOS.md'
    $unsafeOutput = Invoke-IndexerProcess `
        -ConfigPath $configPath `
        -ProjectsRoot $pathOnlyProjectsRoot `
        -ControlCenterPath $pathOnlyControlCenterPath `
        -OutputPath $unsafeOutputPath `
        -StatusPath $pathOnlyStatusPath
    Assert-True ($unsafeOutput.ExitCode -ne 0) 'OutputPath outside the control center should be rejected'
    Assert-True (($unsafeOutput.Text -replace '\s', '') -match [regex]::Escape(($unsafeOutputPath -replace '\s', ''))) "the rejected OutputPath should appear in the error: $($unsafeOutput.Text)"
    Assert-True ($unsafeOutput.Text -match '(?i)must remain inside the control center') 'the OutputPath error should explain the safe output root'

    $unsafeStatusPath = Join-Path $fixtureRoot 'unsafe-status\context-status.json'
    $unsafeStatus = Invoke-IndexerProcess `
        -ConfigPath $configPath `
        -ProjectsRoot $pathOnlyProjectsRoot `
        -ControlCenterPath $pathOnlyControlCenterPath `
        -OutputPath $pathOnlyOutputPath `
        -StatusPath $unsafeStatusPath
    Assert-True ($unsafeStatus.ExitCode -ne 0) 'StatusPath outside the control center should be rejected'
    Assert-True (($unsafeStatus.Text -replace '\s', '') -match [regex]::Escape(($unsafeStatusPath -replace '\s', ''))) 'the rejected StatusPath should appear in the error'
    Assert-True ($unsafeStatus.Text -match '(?i)must remain inside the control center') 'the StatusPath error should explain the safe output root'

    Invoke-Indexer -ConfigPath $configPath -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -OutputPath $outputPath -StatusPath $statusPath | Out-Null
    $firstMarkdown = [System.IO.File]::ReadAllText($outputPath)
    $firstStatus = Read-JsonFile -Path $statusPath

    Assert-True ($firstMarkdown -match 'alpha') 'alpha should appear in the index'
    Assert-True ($firstMarkdown -notmatch 'graphify-out') 'graphify-out should not appear as a project in the index'
    Assert-True ($firstMarkdown -notmatch '\.env') '.env should not appear in the index'
    Assert-True ($firstMarkdown -notmatch 'node_modules') 'node_modules should not appear in the index'
    Assert-True ($firstMarkdown -notmatch '\.firebase-config') '.firebase-config should not appear in the index'
    Assert-True ($firstMarkdown -notmatch 'firebase-tools\.json') 'Firebase configuration should not appear in the index'
    Assert-True ($firstMarkdown -notmatch '\.playwright-browsers') '.playwright-browsers should not appear in the index'
    Assert-True ($firstMarkdown -notmatch 'browser-cache\.json') 'Playwright browser output should not appear in the index'
    Assert-True (@($firstStatus.projects | ForEach-Object { [string]$_.name }) -notcontains 'graphify-out') 'graphify-out should not appear in project status'
    Assert-True ((Get-CollectionCount $firstStatus.added) -eq 1) 'the first run should report one added project'
    Assert-True ((Get-CollectionCount $firstStatus.changed) -eq 0) 'the first run should report no changed projects'
    Assert-True ((Get-CollectionCount $firstStatus.errors) -eq 0) 'the first run should report no errors'

    Invoke-Indexer -ConfigPath $configPath -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -OutputPath $outputPath -StatusPath $statusPath | Out-Null
    $secondStatus = Read-JsonFile -Path $statusPath

    Assert-True ((Get-CollectionCount $secondStatus.added) -eq 0) 'the identical second run should report no added projects'
    Assert-True ((Get-CollectionCount $secondStatus.changed) -eq 0) 'the identical second run should report no changed projects'
    Assert-True ((Get-CollectionCount $secondStatus.errors) -eq 0) 'the second run should report no errors'

    [System.IO.File]::AppendAllText($readmePath, "`nAdditional alpha content")
    Invoke-Indexer -ConfigPath $configPath -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -OutputPath $outputPath -StatusPath $statusPath | Out-Null
    $thirdStatus = Read-JsonFile -Path $statusPath

    Assert-True ((Get-CollectionCount $thirdStatus.changed) -eq 1) 'the third run should report one changed project'
    Assert-True (@($thirdStatus.changed) -contains 'alpha') 'the third run should report alpha as changed'
    Assert-True ((Get-CollectionCount $thirdStatus.errors) -eq 0) 'the third run should report no errors'

    $previousMarkdownBytes = [System.IO.File]::ReadAllBytes($outputPath)
    $previousStatusBytes = [System.IO.File]::ReadAllBytes($statusPath)
    $moveBreakpoint = $null
    $failureObserved = $false
    $global:cronosMoveCount = 0
    $global:cronosStatusLock = $null
    $global:cronosLockedStatusPath = $statusPath
    try {
        $moveBreakpoint = Set-PSBreakpoint -Command Move-Item -Action {
            $global:cronosMoveCount++
            if ($global:cronosMoveCount -eq 2) {
                $global:cronosStatusLock = New-Object System.IO.FileStream(
                    $global:cronosLockedStatusPath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::None
                )
            }
            return $true
        }
        try {
            Invoke-Indexer -ConfigPath $configPath -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -OutputPath $outputPath -StatusPath $statusPath | Out-Null
        }
        catch {
            $failureObserved = $true
        }
    }
    finally {
        if ($null -ne $moveBreakpoint) {
            Remove-PSBreakpoint -Id $moveBreakpoint.Id
        }
        if ($null -ne $global:cronosStatusLock) {
            $global:cronosStatusLock.Dispose()
        }
        $moveCountObserved = $global:cronosMoveCount
        Remove-Variable -Name cronosMoveCount -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosStatusLock -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosLockedStatusPath -Scope Global -ErrorAction SilentlyContinue
    }

    Assert-True ($moveCountObserved -eq 2) 'the failure should occur at the second Move-Item'
    Assert-True $failureObserved 'the locked status replacement should fail'
    Assert-ByteArraysEqual $previousMarkdownBytes ([System.IO.File]::ReadAllBytes($outputPath)) 'the previous Markdown should be restored'
    Assert-ByteArraysEqual $previousStatusBytes ([System.IO.File]::ReadAllBytes($statusPath)) 'the previous status should remain intact'
    Assert-True (-not (Test-Path -LiteralPath "$outputPath.tmp")) 'the Markdown temporary file should be removed'
    Assert-True (-not (Test-Path -LiteralPath "$statusPath.tmp")) 'the status temporary file should be removed'
    Remove-FixtureBackups -RootPath $controlCenterPath

    $moveBreakpoint = $null
    $copyBreakpoint = $null
    $failureObserved = $false
    $failureMessage = $null
    $global:cronosMoveCount = 0
    $global:cronosCopyCount = 0
    $global:cronosStatusLock = $null
    $global:cronosOutputLock = $null
    $global:cronosLockedStatusPath = $statusPath
    $global:cronosLockedOutputPath = $outputPath
    try {
        $moveBreakpoint = Set-PSBreakpoint -Command Move-Item -Action {
            $global:cronosMoveCount++
            if ($global:cronosMoveCount -eq 2) {
                $global:cronosStatusLock = New-Object System.IO.FileStream(
                    $global:cronosLockedStatusPath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::None
                )
            }
            return $true
        }
        $copyBreakpoint = Set-PSBreakpoint -Command Copy-Item -Action {
            $global:cronosCopyCount++
            if ($global:cronosCopyCount -eq 3) {
                $global:cronosOutputLock = New-Object System.IO.FileStream(
                    $global:cronosLockedOutputPath,
                    [System.IO.FileMode]::Open,
                    [System.IO.FileAccess]::Read,
                    [System.IO.FileShare]::None
                )
            }
            return $true
        }
        try {
            Invoke-Indexer -ConfigPath $configPath -ProjectsRoot $projectsRoot -ControlCenterPath $controlCenterPath -OutputPath $outputPath -StatusPath $statusPath | Out-Null
        }
        catch {
            $failureObserved = $true
            $failureMessage = $_.Exception.Message
        }

        Assert-True ($global:cronosMoveCount -eq 2) 'the rollback failure should start after the second Move-Item'
        Assert-True ($global:cronosCopyCount -ge 3) 'the rollback failure should reach output restoration'
        Assert-True $failureObserved 'the locked rollback should fail explicitly'
        Assert-True ($failureMessage -match 'rollback incomplete') 'the failure should identify incomplete rollback'
        $outputBackups = @(Get-ChildItem -LiteralPath $controlCenterPath -Filter 'INDICE-PROYECTOS.md.*.bak' -File -Recurse -ErrorAction Stop)
        $statusBackups = @(Get-ChildItem -LiteralPath $controlCenterPath -Filter 'context-status.json.*.bak' -File -Recurse -ErrorAction Stop)
        Assert-True ($outputBackups.Count -gt 0) 'the output backup should remain for recovery'
        Assert-True ($statusBackups.Count -gt 0) 'the status backup should remain for recovery'
    }
    finally {
        if ($null -ne $moveBreakpoint) {
            Remove-PSBreakpoint -Id $moveBreakpoint.Id
        }
        if ($null -ne $copyBreakpoint) {
            Remove-PSBreakpoint -Id $copyBreakpoint.Id
        }
        if ($null -ne $global:cronosOutputLock) {
            $global:cronosOutputLock.Dispose()
        }
        if ($null -ne $global:cronosStatusLock) {
            $global:cronosStatusLock.Dispose()
        }
        Remove-Variable -Name cronosMoveCount -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosCopyCount -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosStatusLock -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosOutputLock -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosLockedStatusPath -Scope Global -ErrorAction SilentlyContinue
        Remove-Variable -Name cronosLockedOutputPath -Scope Global -ErrorAction SilentlyContinue
        Remove-FixtureBackups -RootPath $controlCenterPath
    }

    Write-Output 'PASS: project index smoke test'
}
catch {
    Write-Error $_
    exit 1
}
finally {
    if ($null -ne $nestedReparsePath -and (Test-Path -LiteralPath $nestedReparsePath)) {
        [System.IO.Directory]::Delete($nestedReparsePath, $false)
    }
    if ($null -ne $reparseTemporaryPath -and (Test-Path -LiteralPath $reparseTemporaryPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseTemporaryPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseTemporaryPath, $false)
        }
    }
    if ($null -ne $reparseControlCenterPath -and (Test-Path -LiteralPath $reparseControlCenterPath)) {
        $reparseItem = Get-Item -LiteralPath $reparseControlCenterPath -Force
        if (($reparseItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
            [System.IO.Directory]::Delete($reparseControlCenterPath, $false)
        }
    }
    if (Test-Path -LiteralPath $fixtureRoot) {
        Remove-Item -LiteralPath $fixtureRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
