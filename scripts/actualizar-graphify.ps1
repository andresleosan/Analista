[CmdletBinding()]
param(
    [ValidateSet('Scheduled', 'Manual')]
    [string]$Mode = 'Scheduled',
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

function Assert-NoReparsePointsBelow {
    param(
        [string]$RootPath,
        [string[]]$IgnoredDirectoryNames
    )

    $rootFullPath = [System.IO.Path]::GetFullPath($RootPath)
    $rootItem = Get-Item -LiteralPath $rootFullPath -Force -ErrorAction Stop
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "ProjectsRoot '$rootFullPath' is unsafe: reparse point '$rootFullPath' is not allowed."
    }

    $pendingDirectories = New-Object 'System.Collections.Generic.Stack[string]'
    $pendingDirectories.Push($rootFullPath)
    while ($pendingDirectories.Count -gt 0) {
        $currentDirectory = $pendingDirectories.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $currentDirectory -Force -ErrorAction Stop)) {
            if ($item.PSIsContainer -and $IgnoredDirectoryNames -contains $item.Name) {
                continue
            }

            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Graphify source path '$($item.FullName)' is unsafe: reparse point '$($item.FullName)' is not allowed."
            }

            if ($item.PSIsContainer) {
                $pendingDirectories.Push($item.FullName)
            }
        }
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

function Get-GraphifyCommand {
    try {
        $command = Get-Command -Name 'graphify' -CommandType Application -ErrorAction Stop |
            Select-Object -First 1
    }
    catch {
        throw 'Graphify executable is not available.'
    }

    if ($null -eq $command) {
        throw 'Graphify executable is not available.'
    }

    if (-not [string]::IsNullOrWhiteSpace([string]$command.Path)) {
        return [string]$command.Path
    }

    return [string]$command.Source
}

function Assert-GraphifyVersion {
    param(
        [string]$CommandPath,
        [string]$ExpectedVersion
    )

    $versionOutput = @(& $CommandPath '--version' 2>&1)
    $versionExitCode = [int]$LASTEXITCODE
    $versionText = [string]::Join("`n", @($versionOutput | ForEach-Object { [string]$_ }))
    if ($versionExitCode -ne 0 -or $versionText -notmatch ('(?<![0-9])' + [regex]::Escape($ExpectedVersion) + '(?![0-9])')) {
        throw "Graphify version $ExpectedVersion is required."
    }
}

function Quote-CommandArgument {
    param([string]$Value)

    return '"' + $Value.Replace('"', '\"') + '"'
}

function New-GraphifyCommandText {
    param(
        [string]$ProjectsRootPath,
        [string]$OutputPath,
        [string]$CurrentMode
    )

    $parts = @(
        'graphify',
        'extract',
        (Quote-CommandArgument -Value $ProjectsRootPath),
        '--out',
        (Quote-CommandArgument -Value $OutputPath)
    )
    if ($CurrentMode -eq 'Scheduled') {
        $parts += @('--code-only', '--no-cluster')
    }
    else {
        $parts += '--no-cluster'
    }

    return [string]::Join(' ', $parts)
}

function Write-StatusAtomically {
    param(
        [string]$StatusPath,
        [object]$Status
    )

    $temporaryPath = "$StatusPath.tmp"
    $json = $Status | ConvertTo-Json -Depth 6
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    try {
        Assert-NoReparsePoint -Path $temporaryPath -Description 'Graphify temporary status'
        [System.IO.File]::WriteAllText($temporaryPath, $json, $utf8)
        Move-Item -LiteralPath $temporaryPath -Destination $StatusPath -Force -ErrorAction Stop
    }
    catch {
        Remove-AtomicTemporaryPath -Path $temporaryPath
        throw
    }
}

$configPath = Join-Path $PSScriptRoot '..\config\graphify.json'
if (-not (Test-Path -LiteralPath $configPath -PathType Leaf)) {
    throw "Graphify configuration file not found: $configPath"
}

$config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
$expectedVersion = [string](Get-ConfigValue -Config $config -Name 'graphifyVersionVerified' -DefaultValue '')
$scheduledSemanticMode = [string](Get-ConfigValue -Config $config -Name 'scheduledSemanticMode' -DefaultValue '')
$manualSemanticMode = [string](Get-ConfigValue -Config $config -Name 'manualSemanticMode' -DefaultValue '')
$configuredProjectsRoot = [string](Get-ConfigValue -Config $config -Name 'projectsRoot' -DefaultValue '')
$configuredControlCenterPath = [string](Get-ConfigValue -Config $config -Name 'controlCenter' -DefaultValue '')
$ignoredDirectoryNames = @(
    Get-ConfigValue -Config $config -Name 'ignoredDirectoryNames' -DefaultValue @(
        '.git',
        'node_modules',
        'dist',
        'build',
        'coverage',
        '.next',
        '.nuxt',
        '.cache',
        'graphify-out',
        '.firebase-config',
        '.playwright-browsers',
        'Analista'
    )
)

if ([string]::IsNullOrWhiteSpace($ProjectsRoot)) {
    $ProjectsRoot = [string](Get-ConfigValue -Config $config -Name 'projectsRoot' -DefaultValue '')
}
if ([string]::IsNullOrWhiteSpace($ControlCenterPath)) {
    $ControlCenterPath = [string](Get-ConfigValue -Config $config -Name 'controlCenter' -DefaultValue '')
}

if ($Mode -eq 'Manual' -and $manualSemanticMode -eq 'disabled') {
    throw 'Manual semantic extraction requires an active Cronos session or explicit backend/cost approval; manualSemanticMode is disabled.'
}
if ($Mode -eq 'Scheduled' -and $scheduledSemanticMode -ne 'code-only') {
    throw 'Scheduled Graphify extraction must remain code-only.'
}
if ([string]::IsNullOrWhiteSpace($expectedVersion)) {
    throw 'Graphify version is not configured.'
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
Assert-NoReparsePoint -Path $projectsRootFullPath -Description 'ProjectsRoot'
Assert-NoReparsePoint -Path $controlCenterFullPath -Description 'ControlCenterPath'
Test-ExistingDirectory -Path $projectsRootFullPath -Description 'ProjectsRoot'
Assert-NoReparsePointsBelow -RootPath $projectsRootFullPath -IgnoredDirectoryNames $ignoredDirectoryNames
$controlCenterParent = [System.IO.Path]::GetDirectoryName($controlCenterFullPath)
if ([string]::IsNullOrWhiteSpace($controlCenterParent)) {
    throw "ControlCenterPath has no parent directory: $ControlCenterPath"
}
Test-ExistingDirectory -Path $controlCenterParent -Description 'ControlCenterPath parent'
$stateDirectory = Join-Path $controlCenterFullPath 'state'
$statusPath = Join-Path $stateDirectory 'graphify-status.json'
$graphifyOutPath = Join-Path $controlCenterFullPath 'graphify-out'
Assert-NoReparsePoint -Path $stateDirectory -Description 'Graphify state directory'
Assert-NoReparsePoint -Path $statusPath -Description 'Graphify status output'
Assert-NoReparsePoint -Path $graphifyOutPath -Description 'Graphify output directory'
if (Test-Path -LiteralPath $graphifyOutPath -PathType Container) {
    Assert-NoReparsePointsBelow -RootPath $graphifyOutPath -IgnoredDirectoryNames @()
}

$graphifyCommandPath = Get-GraphifyCommand
$commandText = New-GraphifyCommandText `
    -ProjectsRootPath $projectsRootFullPath `
    -OutputPath $controlCenterFullPath `
    -CurrentMode $Mode

if ($WhatIf) {
    Write-Output "WhatIf: $commandText"
    exit 0
}

Ensure-Directory -Path $controlCenterFullPath -Description 'ControlCenterPath'
Ensure-Directory -Path $stateDirectory -Description 'Graphify state directory'

$startedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
$semanticMode = if ($Mode -eq 'Scheduled') { $scheduledSemanticMode } else { $manualSemanticMode }
$arguments = @('extract', $projectsRootFullPath, '--out', $controlCenterFullPath)
if ($Mode -eq 'Scheduled') {
    $arguments += @('--code-only', '--no-cluster')
}
else {
    $arguments += '--no-cluster'
}
$exitCode = 1
$errorMessage = $null
try {
    Assert-GraphifyVersion -CommandPath $graphifyCommandPath -ExpectedVersion $expectedVersion
    $previousGraphifyOut = [System.Environment]::GetEnvironmentVariable('GRAPHIFY_OUT', 'Process')
    try {
        $env:GRAPHIFY_OUT = $graphifyOutPath
        $previousErrorActionPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = 'Continue'
            $graphifyOutput = @(& $graphifyCommandPath @arguments 2>&1)
            $exitCode = [int]$LASTEXITCODE
        }
        finally {
            $ErrorActionPreference = $previousErrorActionPreference
        }
    }
    finally {
        if ($null -eq $previousGraphifyOut) {
            Remove-Item Env:GRAPHIFY_OUT -ErrorAction SilentlyContinue
        }
        else {
            $env:GRAPHIFY_OUT = $previousGraphifyOut
        }
    }
    if ($exitCode -ne 0) {
        $errorMessage = "Graphify extraction failed with exit code $exitCode."
    }
}
catch {
    $errorMessage = $_.Exception.Message
    $nativeExitCode = Get-Variable -Name LASTEXITCODE -ValueOnly -ErrorAction SilentlyContinue
    if ($null -ne $nativeExitCode -and [int]$nativeExitCode -ne 0) {
        $exitCode = [int]$nativeExitCode
    }
    else {
        $exitCode = 1
    }
}
finally {
    $status = [ordered]@{
        startedAtUtc = $startedAtUtc
        completedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
        mode = $Mode
        command = $commandText
        exitCode = $exitCode
        semanticMode = $semanticMode
        error = $errorMessage
    }
    Write-StatusAtomically -StatusPath $statusPath -Status $status
}

if ($exitCode -ne 0) {
    Write-Error $errorMessage -ErrorAction Continue
    exit $exitCode
}

exit 0
