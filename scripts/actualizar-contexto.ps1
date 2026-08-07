[CmdletBinding()]
param(
    [ValidateSet('Session', 'Scheduled')]
    [string]$Mode = 'Session',
    [string]$ProjectsRoot,
    [string]$ControlCenterPath,
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Get-ConfigValue {
    param(
        [object]$Config,
        [string]$Name,
        [object]$DefaultValue
    )

    $property = $Config.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        return $DefaultValue
    }

    return $property.Value
}

function ConvertTo-UtcString {
    param([DateTime]$Value)

    return $Value.ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Resolve-FullPath {
    param(
        [string]$Path,
        [string]$Description
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        throw "$Description is required."
    }

    try {
        return [System.IO.Path]::GetFullPath($Path)
    }
    catch {
        throw "Invalid $Description path."
    }
}

function Test-PathInsideOrEqual {
    param(
        [string]$Path,
        [string]$RootPath
    )

    if ([System.String]::Equals($Path, $RootPath, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $rootPrefix = $RootPath.TrimEnd('\') + '\'
    return $Path.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
}

function Assert-NoReparsePoint {
    param(
        [string]$Path,
        [string]$Description
    )

    $currentPath = [System.IO.Path]::GetFullPath($Path)
    while ($true) {
        $item = Get-Item -LiteralPath $currentPath -Force -ErrorAction SilentlyContinue
        if ($null -ne $item -and (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
            throw "$Description '$Path' is unsafe: reparse point '$currentPath' is not allowed."
        }

        $parentPath = [System.IO.Path]::GetDirectoryName($currentPath)
        if ([string]::IsNullOrWhiteSpace($parentPath) -or [System.String]::Equals($parentPath, $currentPath, [System.StringComparison]::OrdinalIgnoreCase)) {
            break
        }
        $currentPath = $parentPath
    }
}

function Remove-AtomicTemporaryPath {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return
    }

    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($null -eq $item -or (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0)) {
        return
    }

    Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
}

function Test-ExistingDirectory {
    param(
        [string]$Path,
        [string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
        throw "$Description does not exist: $Path"
    }
}

function Ensure-Directory {
    param(
        [string]$Path,
        [string]$Description
    )

    if (Test-Path -LiteralPath $Path) {
        if (-not (Test-Path -LiteralPath $Path -PathType Container)) {
            throw "$Description is not a directory: $Path"
        }
        return
    }

    try {
        New-Item -ItemType Directory -Path $Path -Force -ErrorAction Stop | Out-Null
    }
    catch {
        throw "Unable to create ${Description}: $Path"
    }
}

function Quote-CommandArgument {
    param([string]$Value)

    return '"' + $Value.Replace('"', '\"') + '"'
}

function Format-CommandPart {
    param([string]$Value)

    if ($Value -match '^[A-Za-z0-9_.:-]+$') {
        return $Value
    }

    return Quote-CommandArgument -Value $Value
}

function New-PowerShellCommandText {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    $parts = @(
        'powershell.exe',
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        (Quote-CommandArgument -Value $ScriptPath)
    )
    foreach ($argument in @($Arguments)) {
        $parts += Format-CommandPart -Value ([string]$argument)
    }

    return [string]::Join(' ', $parts)
}

function Invoke-ChildScript {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments
    )

    $previousErrorActionPreference = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        $output = @(& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $ScriptPath @Arguments 2>&1)
        $childExitCode = [int]$LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference
    }

    return [pscustomobject]@{
        ExitCode = $childExitCode
        Output = $output
    }
}

function Write-JsonAtomically {
    param(
        [string]$Path,
        [object]$Value
    )

    $temporaryPath = "$Path.tmp"
    $json = $Value | ConvertTo-Json -Depth 8
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    try {
        Assert-NoReparsePoint -Path $temporaryPath -Description 'temporary JSON output'
        [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8)
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force -ErrorAction Stop
    }
    catch {
        Remove-AtomicTemporaryPath -Path $temporaryPath
        throw
    }
}

function Append-RefreshLog {
    param(
        [string]$Path,
        [string]$TimestampUtc,
        [string]$CurrentMode,
        [int]$IndexExitCode,
        [int]$GraphifyExitCode
    )

    $line = [string]::Join('|', @(
        $TimestampUtc,
        $CurrentMode,
        [string]$IndexExitCode,
        [string]$GraphifyExitCode
    ))
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::AppendAllText($Path, $line + [Environment]::NewLine, $utf8)
}

function Test-CurrentGraphifyStatus {
    param(
        [string]$Path,
        [string]$ExecutionStartedAtUtc,
        [int]$ExitCode
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return $false
    }

    try {
        $status = Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
        $executionStarted = [DateTime]::Parse(
            $ExecutionStartedAtUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
        $statusStarted = [DateTime]::Parse(
            [string]$status.startedAtUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()
        $statusCompleted = [DateTime]::Parse(
            [string]$status.completedAtUtc,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [System.Globalization.DateTimeStyles]::RoundtripKind
        ).ToUniversalTime()

        return (
            $statusStarted -ge $executionStarted -and
            $statusCompleted -ge $statusStarted -and
            [string]$status.mode -eq 'Scheduled' -and
            [string]$status.semanticMode -eq 'code-only' -and
            [int]$status.exitCode -eq $ExitCode -and
            -not [string]::IsNullOrWhiteSpace([string]$status.command)
        )
    }
    catch {
        return $false
    }
}

function Write-FallbackGraphifyStatus {
    param(
        [string]$Path,
        [string]$CommandText,
        [int]$ExitCode,
        [string]$ErrorMessage,
        [string]$ExecutionStartedAtUtc
    )

    if (Test-CurrentGraphifyStatus `
        -Path $Path `
        -ExecutionStartedAtUtc $ExecutionStartedAtUtc `
        -ExitCode $ExitCode
    ) {
        return
    }

    $status = [ordered]@{
        startedAtUtc = $ExecutionStartedAtUtc
        completedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
        mode = 'Scheduled'
        command = $CommandText
        exitCode = $ExitCode
        semanticMode = 'code-only'
        error = $ErrorMessage
    }
    Write-JsonAtomically -Path $Path -Value $status
}

$contextConfigPath = Resolve-FullPath -Path (Join-Path $PSScriptRoot '..\config\contexto.json') -Description 'context configuration'
if (-not (Test-Path -LiteralPath $contextConfigPath -PathType Leaf)) {
    throw "Context configuration file not found: $contextConfigPath"
}

$config = Get-Content -LiteralPath $contextConfigPath -Raw | ConvertFrom-Json
$configuredProjectsRoot = [string](Get-ConfigValue -Config $config -Name 'projectsRoot' -DefaultValue '')
$configuredControlCenterPath = [string](Get-ConfigValue -Config $config -Name 'controlCenter' -DefaultValue '')
if ([string]::IsNullOrWhiteSpace($ProjectsRoot)) {
    $ProjectsRoot = $configuredProjectsRoot
}
if ([string]::IsNullOrWhiteSpace($ControlCenterPath)) {
    $ControlCenterPath = $configuredControlCenterPath
}

$projectsRootFullPath = Resolve-FullPath -Path $ProjectsRoot -Description 'ProjectsRoot'
$controlCenterFullPath = Resolve-FullPath -Path $ControlCenterPath -Description 'ControlCenterPath'
$configuredProjectsRootFullPath = Resolve-FullPath -Path $configuredProjectsRoot -Description 'configured ProjectsRoot'
$configuredControlCenterFullPath = Resolve-FullPath -Path $configuredControlCenterPath -Description 'configured ControlCenterPath'
if (
    (Test-PathInsideOrEqual -Path $controlCenterFullPath -RootPath $configuredProjectsRootFullPath) -and
    -not [System.String]::Equals(
        $controlCenterFullPath,
        $configuredControlCenterFullPath,
        [System.StringComparison]::OrdinalIgnoreCase
    )
) {
    throw "ControlCenterPath '$controlCenterFullPath' is unsafe: output must remain inside the control center or equal the configured control center '$configuredControlCenterFullPath'."
}
Test-ExistingDirectory -Path $projectsRootFullPath -Description 'ProjectsRoot'

$controlCenterParent = [System.IO.Path]::GetDirectoryName($controlCenterFullPath)
if ([string]::IsNullOrWhiteSpace($controlCenterParent)) {
    throw "ControlCenterPath has no parent directory: $ControlCenterPath"
}
Test-ExistingDirectory -Path $controlCenterParent -Description 'ControlCenterPath parent'
if ((Test-Path -LiteralPath $controlCenterFullPath) -and -not (Test-Path -LiteralPath $controlCenterFullPath -PathType Container)) {
    throw "ControlCenterPath is not a directory: $ControlCenterPath"
}

$indexScriptPath = Resolve-FullPath -Path (Join-Path $PSScriptRoot 'actualizar-indice.ps1') -Description 'index script'
$graphifyScriptPath = Resolve-FullPath -Path (Join-Path $PSScriptRoot 'actualizar-graphify.ps1') -Description 'Graphify script'
if (-not (Test-Path -LiteralPath $indexScriptPath -PathType Leaf)) {
    throw "Index script not found: $indexScriptPath"
}
if (-not (Test-Path -LiteralPath $graphifyScriptPath -PathType Leaf)) {
    throw "Graphify script not found: $graphifyScriptPath"
}

$indexPath = Join-Path $controlCenterFullPath 'INDICE-PROYECTOS.md'
$stateDirectory = Join-Path $controlCenterFullPath 'state'
$contextStatusPath = Join-Path $stateDirectory 'context-status.json'
$graphifyStatusPath = Join-Path $stateDirectory 'graphify-status.json'
$refreshLogPath = Join-Path $stateDirectory 'context-refresh.log'
$graphifyMode = 'Scheduled'
Assert-NoReparsePoint -Path $projectsRootFullPath -Description 'ProjectsRoot'
Assert-NoReparsePoint -Path $controlCenterFullPath -Description 'ControlCenterPath'
Assert-NoReparsePoint -Path $indexPath -Description 'index output'
Assert-NoReparsePoint -Path $contextStatusPath -Description 'context status output'
Assert-NoReparsePoint -Path "$contextStatusPath.tmp" -Description 'context temporary status output'
Assert-NoReparsePoint -Path $graphifyStatusPath -Description 'Graphify status output'
Assert-NoReparsePoint -Path $refreshLogPath -Description 'refresh log output'

$indexArguments = @(
    '-ConfigPath', $contextConfigPath,
    '-ProjectsRoot', $projectsRootFullPath,
    '-ControlCenterPath', $controlCenterFullPath,
    '-OutputPath', $indexPath,
    '-StatusPath', $contextStatusPath
)
$graphifyArguments = @(
    '-Mode', $graphifyMode,
    '-ProjectsRoot', $projectsRootFullPath,
    '-ControlCenterPath', $controlCenterFullPath
)
$indexCommandText = New-PowerShellCommandText -ScriptPath $indexScriptPath -Arguments $indexArguments
$graphifyCommandText = New-PowerShellCommandText -ScriptPath $graphifyScriptPath -Arguments $graphifyArguments

if ($WhatIf) {
    Write-Output "WhatIf: $indexCommandText"
    Write-Output "WhatIf: $graphifyCommandText"
    exit 0
}

$startedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
$indexExitCode = 1
$graphifyExitCode = -1
$errorMessage = $null

try {
    try {
        $indexResult = Invoke-ChildScript -ScriptPath $indexScriptPath -Arguments $indexArguments
        $indexExitCode = [int]$indexResult.ExitCode
    }
    catch {
        $indexExitCode = 1
        $errorMessage = $_.Exception.Message
    }

    if ($indexExitCode -ne 0) {
        if ([string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "Index generation failed with exit code $indexExitCode."
        }
    }
    else {
        try {
            $graphifyResult = Invoke-ChildScript -ScriptPath $graphifyScriptPath -Arguments $graphifyArguments
            $graphifyExitCode = [int]$graphifyResult.ExitCode
        }
        catch {
            $graphifyExitCode = 1
            $errorMessage = $_.Exception.Message
        }

        if ($graphifyExitCode -ne 0 -and [string]::IsNullOrWhiteSpace($errorMessage)) {
            $errorMessage = "Graphify extraction failed with exit code $graphifyExitCode."
        }
    }
}
finally {
    Ensure-Directory -Path $stateDirectory -Description 'context state directory'

    if ($indexExitCode -eq 0 -and $graphifyExitCode -ne -1) {
        Write-FallbackGraphifyStatus `
            -Path $graphifyStatusPath `
            -CommandText $graphifyCommandText `
            -ExitCode $graphifyExitCode `
            -ErrorMessage $errorMessage `
            -ExecutionStartedAtUtc $startedAtUtc
    }

    $completedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
    $overallExitCode = if ($indexExitCode -eq 0) { 0 } else { 1 }
    $contextStatus = [ordered]@{
        startedAtUtc = $startedAtUtc
        completedAtUtc = $completedAtUtc
        mode = $Mode
        indexExitCode = $indexExitCode
        graphifyExitCode = $graphifyExitCode
        exitCode = $overallExitCode
        indexPath = $indexPath
        graphifyStatusPath = $graphifyStatusPath
        error = $errorMessage
    }
    Write-JsonAtomically -Path $contextStatusPath -Value $contextStatus
    Append-RefreshLog `
        -Path $refreshLogPath `
        -TimestampUtc $completedAtUtc `
        -CurrentMode $Mode `
        -IndexExitCode $indexExitCode `
        -GraphifyExitCode $graphifyExitCode
}

if ($indexExitCode -eq 0) {
    exit 0
}

exit 1
