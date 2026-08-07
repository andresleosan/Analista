[CmdletBinding()]
param(
    [string]$ConfigPath,
    [string]$ProjectsRoot,
    [string]$ControlCenterPath,
    [string]$OutputPath,
    [string]$StatusPath
)

$ErrorActionPreference = 'Stop'

function Test-ExcludedPath {
    param(
        [string]$Path,
        [string[]]$IgnoredDirectoryNames,
        [string[]]$IgnoredFilePatterns
    )

    $normalized = [System.IO.Path]::GetFullPath($Path)
    foreach ($segment in $normalized -split '[\\/]') {
        if ($IgnoredDirectoryNames -contains $segment) {
            return $true
        }
    }

    $leaf = [System.IO.Path]::GetFileName($normalized)
    foreach ($pattern in $IgnoredFilePatterns) {
        if ($leaf -like $pattern) {
            return $true
        }
    }

    return $false
}

function Get-RelativePath {
    param(
        [string]$RootPath,
        [string]$Path
    )

    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\'
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside root: $Path"
    }

    return $full.Substring($root.Length).Replace('\', '/')
}

function Test-PathInsideOrEqual {
    param(
        [string]$Path,
        [string]$RootPath
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $fullRoot = [System.IO.Path]::GetFullPath($RootPath)
    if ([System.String]::Equals($fullPath, $fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $true
    }

    $rootPrefix = $fullRoot.TrimEnd('\') + '\'
    return $fullPath.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)
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

function Get-ConfigStringArray {
    param(
        [object]$Config,
        [string]$Name
    )

    $value = Get-ConfigValue -Config $Config -Name $Name -DefaultValue @()
    return @($value | ForEach-Object { [string]$_ })
}

function ConvertTo-UtcString {
    param([DateTime]$Value)

    return $Value.ToUniversalTime().ToString('o', [System.Globalization.CultureInfo]::InvariantCulture)
}

function Get-Sha256Fingerprint {
    param([string[]]$Rows)

    $payload = [string]::Join("`n", @($Rows))
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($payload)
        $digest = $sha256.ComputeHash($bytes)
    }
    finally {
        $sha256.Dispose()
    }

    return ([System.BitConverter]::ToString($digest)).Replace('-', '').ToLowerInvariant()
}

function Ensure-Directory {
    param(
        [string]$Path,
        [string]$Description
    )

    try {
        $fullPath = [System.IO.Path]::GetFullPath($Path)
        if (Test-Path -LiteralPath $fullPath) {
            $existing = Get-Item -LiteralPath $fullPath -Force -ErrorAction Stop
            if (-not $existing.PSIsContainer) {
                throw "Path is not a directory: $fullPath"
            }
        }
        else {
            New-Item -ItemType Directory -Path $fullPath -Force -ErrorAction Stop | Out-Null
        }

        return $fullPath
    }
    catch {
        throw "Unable to create $Description '$Path': $($_.Exception.Message)"
    }
}

function Remove-TransactionPath {
    param([string]$Path)

    for ($attempt = 0; $attempt -lt 10; $attempt++) {
        if (-not (Test-Path -LiteralPath $Path)) {
            return $true
        }

        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
            return $true
        }
        catch {
            Start-Sleep -Milliseconds 25
        }
    }

    return (-not (Test-Path -LiteralPath $Path))
}

function Move-TransactionItem {
    param(
        [string]$Source,
        [string]$Destination
    )

    Move-Item -LiteralPath $Source -Destination $Destination -Force -ErrorAction Stop
}

function Restore-TransactionPath {
    param(
        [string]$BackupPath,
        [string]$Destination,
        [bool]$ExistedBefore
    )

    if (-not $ExistedBefore) {
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            return $null
        }

        if (-not (Remove-TransactionPath -Path $Destination)) {
            return "restore failed for '$Destination': newly created destination could not be removed"
        }
        if (Test-Path -LiteralPath $Destination -PathType Leaf) {
            return "restore failed for '$Destination': destination still exists after removal"
        }
        return $null
    }

    if (-not (Test-Path -LiteralPath $BackupPath -PathType Leaf)) {
        return "restore failed for '$Destination': backup is missing"
    }

    try {
        Copy-Item -LiteralPath $BackupPath -Destination $Destination -Force -ErrorAction Stop
        if (-not (Test-Path -LiteralPath $Destination -PathType Leaf)) {
            throw 'destination is missing after restore'
        }
        return $null
    }
    catch {
        return "restore failed for '$Destination': $($_.Exception.Message)"
    }
}

function Get-ProjectFilePaths {
    param(
        [string]$RootPath,
        [string[]]$IgnoredDirectoryNames,
        [string[]]$IgnoredFilePatterns
    )

    $rootFullPath = [System.IO.Path]::GetFullPath($RootPath)
    $rootItem = Get-Item -LiteralPath $rootFullPath -Force -ErrorAction Stop
    if (($rootItem.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
        throw "Project root '$rootFullPath' is unsafe: reparse point '$rootFullPath' is not allowed."
    }

    $pendingDirectories = New-Object 'System.Collections.Generic.Stack[string]'
    $pendingDirectories.Push($rootFullPath)
    while ($pendingDirectories.Count -gt 0) {
        $currentDirectory = $pendingDirectories.Pop()
        foreach ($item in @(Get-ChildItem -LiteralPath $currentDirectory -Force -ErrorAction Stop)) {
            if (Test-ExcludedPath `
                -Path $item.FullName `
                -IgnoredDirectoryNames $IgnoredDirectoryNames `
                -IgnoredFilePatterns $IgnoredFilePatterns) {
                continue
            }

            if (($item.Attributes -band [System.IO.FileAttributes]::ReparsePoint) -ne 0) {
                throw "Project path '$($item.FullName)' is unsafe: reparse point '$($item.FullName)' is not allowed."
            }

            if ($item.PSIsContainer) {
                $pendingDirectories.Push($item.FullName)
            }
            else {
                Write-Output $item.FullName
            }
        }
    }
}

function Get-ProjectSnapshot {
    param(
        [string]$ProjectPath,
        [object]$Config,
        [string]$ControlCenterPath
    )

    $projectFullPath = [System.IO.Path]::GetFullPath($ProjectPath)
    $ignoredDirectoryNames = Get-ConfigStringArray -Config $Config -Name 'ignoredDirectoryNames'
    $ignoredFilePatterns = Get-ConfigStringArray -Config $Config -Name 'ignoredFilePatterns'
    $knownDocumentNames = Get-ConfigStringArray -Config $Config -Name 'knownDocumentNames'

    $rows = New-Object 'System.Collections.Generic.List[string]'
    $knownDocuments = New-Object 'System.Collections.Generic.List[string]'
    $fileCount = 0
    [int64]$byteCount = 0
    $hasLastModified = $false
    $lastModifiedUtc = [DateTime]::MinValue

    foreach ($filePath in Get-ProjectFilePaths `
        -RootPath $projectFullPath `
        -IgnoredDirectoryNames $ignoredDirectoryNames `
        -IgnoredFilePatterns $ignoredFilePatterns) {
        $fileInfo = New-Object System.IO.FileInfo($filePath)
        $relativePath = Get-RelativePath -RootPath $projectFullPath -Path $fileInfo.FullName
        $lastWriteTimeUtc = $fileInfo.LastWriteTimeUtc
        $lastWriteTimeText = ConvertTo-UtcString -Value $lastWriteTimeUtc

        $fileCount++
        $byteCount += [int64]$fileInfo.Length
        if (-not $hasLastModified -or $lastWriteTimeUtc -gt $lastModifiedUtc) {
            $lastModifiedUtc = $lastWriteTimeUtc
            $hasLastModified = $true
        }

        [void]$rows.Add("$relativePath|$($fileInfo.Length)|$lastWriteTimeText")
        if ($knownDocumentNames -contains $fileInfo.Name) {
            [void]$knownDocuments.Add($relativePath)
        }
    }

    $sortedRows = @($rows | Sort-Object)
    $sortedDocuments = @($knownDocuments | Sort-Object)
    $directoryInfo = New-Object System.IO.DirectoryInfo($projectFullPath)

    return [pscustomobject][ordered]@{
        name = $directoryInfo.Name
        path = $projectFullPath
        lastModifiedUtc = if ($hasLastModified) { ConvertTo-UtcString -Value $lastModifiedUtc } else { $null }
        fileCount = $fileCount
        byteCount = $byteCount
        knownDocuments = $sortedDocuments
        fingerprint = Get-Sha256Fingerprint -Rows $sortedRows
    }
}

function Get-ProjectSnapshots {
    param(
        [string]$ProjectsRoot,
        [string]$ControlCenterPath,
        [object]$Config
    )

    $projectsRootFullPath = [System.IO.Path]::GetFullPath($ProjectsRoot)
    $controlCenterFullPath = [System.IO.Path]::GetFullPath($ControlCenterPath)
    $ignoredDirectoryNames = Get-ConfigStringArray -Config $Config -Name 'ignoredDirectoryNames'
    $directories = @(
        [System.IO.Directory]::GetDirectories($projectsRootFullPath) |
            Sort-Object { [System.IO.Path]::GetFileName($_) }
    )

    foreach ($directory in $directories) {
        $directoryFullPath = [System.IO.Path]::GetFullPath($directory)
        if ([System.String]::Equals(
            $directoryFullPath,
            $controlCenterFullPath,
            [System.StringComparison]::OrdinalIgnoreCase
        )) {
            continue
        }

        $directoryName = [System.IO.Path]::GetFileName($directoryFullPath)
        $isIgnoredDirectory = $false
        foreach ($ignoredDirectoryName in $ignoredDirectoryNames) {
            if ([System.String]::Equals(
                $directoryName,
                [string]$ignoredDirectoryName,
                [System.StringComparison]::OrdinalIgnoreCase
            )) {
                $isIgnoredDirectory = $true
                break
            }
        }
        if ($isIgnoredDirectory) {
            continue
        }

        Get-ProjectSnapshot -ProjectPath $directoryFullPath -Config $Config -ControlCenterPath $controlCenterFullPath
    }
}

function ConvertTo-MarkdownCell {
    param([object]$Value)

    if ($null -eq $Value) {
        return ''
    }

    return ([string]$Value).Replace('|', '\|')
}

function ConvertTo-ProjectIndexMarkdown {
    param(
        [object[]]$ProjectSnapshots,
        [string]$GeneratedAtUtc,
        [string[]]$AddedProjects,
        [string[]]$ChangedProjects
    )

    $added = @{}
    foreach ($projectName in @($AddedProjects)) {
        if ($null -ne $projectName) {
            $added[[string]$projectName] = $true
        }
    }

    $changed = @{}
    foreach ($projectName in @($ChangedProjects)) {
        if ($null -ne $projectName) {
            $changed[[string]$projectName] = $true
        }
    }

    $lines = New-Object 'System.Collections.Generic.List[string]'
    [void]$lines.Add(('# ' + [char]0x00CD + 'ndice de proyectos'))
    [void]$lines.Add('')
    [void]$lines.Add("Actualizado: $GeneratedAtUtc")
    [void]$lines.Add('')
    [void]$lines.Add(('| Proyecto | Ruta | Archivos | Documentaci' + [char]0x00F3 + 'n conocida | ' + [char]0x00DA + 'ltimo cambio | Estado |'))
    [void]$lines.Add('|---|---|---:|---|---|---|')

    foreach ($snapshot in @($ProjectSnapshots)) {
        $name = ConvertTo-MarkdownCell -Value $snapshot.name
        $path = ConvertTo-MarkdownCell -Value ([string]$snapshot.path).Replace('\', '/')
        $documents = @(@($snapshot.knownDocuments) | ForEach-Object {
            ConvertTo-MarkdownCell -Value $_
        })
        $documentsText = if ($documents.Count -gt 0) { [string]::Join(', ', $documents) } else { '-' }
        $lastModified = if ($null -ne $snapshot.lastModifiedUtc) { [string]$snapshot.lastModifiedUtc } else { '-' }
        if ($added.ContainsKey([string]$snapshot.name)) {
            $status = 'nuevo'
        }
        elseif ($changed.ContainsKey([string]$snapshot.name)) {
            $status = 'cambiado'
        }
        else {
            $status = 'sin cambios'
        }

        [void]$lines.Add("| $name | ``$path`` | $($snapshot.fileCount) | $documentsText | $lastModified | $status |")
    }

    return ([string]::Join("`n", $lines) + "`n")
}

function Write-ProjectOutputs {
    param(
        [string]$OutputPath,
        [string]$StatusPath,
        [object[]]$ProjectSnapshots,
        [string]$GeneratedAtUtc,
        [string[]]$AddedProjects,
        [string[]]$ChangedProjects,
        [string[]]$RemovedProjects,
        [string[]]$Errors
    )

    $outputTemporaryPath = "$OutputPath.tmp"
    $statusTemporaryPath = "$StatusPath.tmp"
    $transactionId = [guid]::NewGuid().ToString('N')
    $outputBackupPath = "$OutputPath.$transactionId.bak"
    $statusBackupPath = "$StatusPath.$transactionId.bak"
    $outputExisted = Test-Path -LiteralPath $OutputPath -PathType Leaf
    $statusExisted = Test-Path -LiteralPath $StatusPath -PathType Leaf
    $transactionStarted = $false
    $transactionCommitted = $false

    try {
        Assert-NoReparsePoint -Path $outputTemporaryPath -Description 'index temporary output'
        Assert-NoReparsePoint -Path $statusTemporaryPath -Description 'index temporary status'
        $markdown = ConvertTo-ProjectIndexMarkdown `
            -ProjectSnapshots $ProjectSnapshots `
            -GeneratedAtUtc $GeneratedAtUtc `
            -AddedProjects $AddedProjects `
            -ChangedProjects $ChangedProjects

        $status = [ordered]@{
            generatedAtUtc = $GeneratedAtUtc
            projects = @($ProjectSnapshots)
            added = @($AddedProjects)
            changed = @($ChangedProjects)
            removed = @($RemovedProjects)
            errors = @($Errors)
        }
        $statusJson = $status | ConvertTo-Json -Depth 8
        $utf8 = New-Object System.Text.UTF8Encoding($true)

        [System.IO.File]::WriteAllText($outputTemporaryPath, $markdown, $utf8)
        [System.IO.File]::WriteAllText($statusTemporaryPath, $statusJson, $utf8)
        if ($outputExisted) {
            Copy-Item -LiteralPath $OutputPath -Destination $outputBackupPath -Force -ErrorAction Stop
        }
        if ($statusExisted) {
            Copy-Item -LiteralPath $StatusPath -Destination $statusBackupPath -Force -ErrorAction Stop
        }
        $transactionStarted = $true
        Move-TransactionItem -Source $outputTemporaryPath -Destination $OutputPath
        Move-TransactionItem -Source $statusTemporaryPath -Destination $StatusPath
        $transactionCommitted = $true
        $cleanupErrors = New-Object 'System.Collections.Generic.List[string]'
        foreach ($backupPath in @($outputBackupPath, $statusBackupPath)) {
            if (-not (Remove-TransactionPath -Path $backupPath)) {
                [void]$cleanupErrors.Add("backup cleanup failed for '$backupPath'")
            }
        }
        if ($cleanupErrors.Count -gt 0) {
            throw ('transaction cleanup incomplete: ' + [string]::Join('; ', $cleanupErrors))
        }
    }
    catch {
        if ($transactionCommitted) {
            throw
        }

        if (-not $transactionStarted) {
            $preparationCleanupErrors = New-Object 'System.Collections.Generic.List[string]'
            foreach ($backupPath in @($outputBackupPath, $statusBackupPath)) {
                if (-not (Remove-TransactionPath -Path $backupPath)) {
                    [void]$preparationCleanupErrors.Add("backup cleanup failed for '$backupPath'")
                }
            }
            if ($preparationCleanupErrors.Count -gt 0) {
                throw ('transaction cleanup incomplete: ' + [string]::Join('; ', $preparationCleanupErrors))
            }
            throw
        }

        $rollbackErrors = New-Object 'System.Collections.Generic.List[string]'
        $outputRestoreError = Restore-TransactionPath `
            -BackupPath $outputBackupPath `
            -Destination $OutputPath `
            -ExistedBefore $outputExisted
        if ($null -ne $outputRestoreError) {
            [void]$rollbackErrors.Add($outputRestoreError)
        }

        $statusRestoreError = Restore-TransactionPath `
            -BackupPath $statusBackupPath `
            -Destination $StatusPath `
            -ExistedBefore $statusExisted
        if ($null -ne $statusRestoreError) {
            [void]$rollbackErrors.Add($statusRestoreError)
        }

        if ($rollbackErrors.Count -gt 0) {
            throw ('rollback incomplete: ' + [string]::Join('; ', $rollbackErrors))
        }

        $rollbackCleanupErrors = New-Object 'System.Collections.Generic.List[string]'
        foreach ($backupPath in @($outputBackupPath, $statusBackupPath)) {
            if (-not (Remove-TransactionPath -Path $backupPath)) {
                [void]$rollbackCleanupErrors.Add("backup cleanup failed for '$backupPath'")
            }
        }
        if ($rollbackCleanupErrors.Count -gt 0) {
            throw ('rollback incomplete: ' + [string]::Join('; ', $rollbackCleanupErrors))
        }

        throw
    }
}

if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path $PSScriptRoot '..\config\contexto.json'
}

if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
    throw "Configuration file not found: $ConfigPath"
}

$config = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json

$configuredProjectsRoot = [string](Get-ConfigValue -Config $config -Name 'projectsRoot' -DefaultValue '')
$configuredControlCenterPath = [string](Get-ConfigValue -Config $config -Name 'controlCenter' -DefaultValue '')
if ([string]::IsNullOrWhiteSpace($ProjectsRoot)) {
    $ProjectsRoot = $configuredProjectsRoot
}
if ([string]::IsNullOrWhiteSpace($ControlCenterPath)) {
    $ControlCenterPath = $configuredControlCenterPath
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = [string](Get-ConfigValue -Config $config -Name 'indexPath' -DefaultValue $null)
}
if ([string]::IsNullOrWhiteSpace($StatusPath)) {
    $StatusPath = [string](Get-ConfigValue -Config $config -Name 'statusPath' -DefaultValue $null)
}

if ([string]::IsNullOrWhiteSpace($ProjectsRoot)) {
    throw 'ProjectsRoot is required.'
}
if ([string]::IsNullOrWhiteSpace($ControlCenterPath)) {
    throw 'ControlCenterPath is required.'
}
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    throw 'OutputPath is required.'
}
if ([string]::IsNullOrWhiteSpace($StatusPath)) {
    throw 'StatusPath is required.'
}

$controlCenterFullPath = [System.IO.Path]::GetFullPath($ControlCenterPath)
$configuredProjectsRootFullPath = if ([string]::IsNullOrWhiteSpace($configuredProjectsRoot)) {
    [System.IO.Path]::GetFullPath($ProjectsRoot)
}
else {
    [System.IO.Path]::GetFullPath($configuredProjectsRoot)
}
$configuredControlCenterFullPath = if ([string]::IsNullOrWhiteSpace($configuredControlCenterPath)) {
    $controlCenterFullPath
}
else {
    [System.IO.Path]::GetFullPath($configuredControlCenterPath)
}
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

$projectsRootFullPath = [System.IO.Path]::GetFullPath($ProjectsRoot)
$outputFullPath = [System.IO.Path]::GetFullPath($OutputPath)
$statusFullPath = [System.IO.Path]::GetFullPath($StatusPath)
Assert-NoReparsePoint -Path $projectsRootFullPath -Description 'ProjectsRoot'
Assert-NoReparsePoint -Path $controlCenterFullPath -Description 'ControlCenterPath'
Assert-NoReparsePoint -Path $outputFullPath -Description 'OutputPath'
Assert-NoReparsePoint -Path $statusFullPath -Description 'StatusPath'
$ProjectsRoot = Ensure-Directory -Path $ProjectsRoot -Description 'projects root'
$outputParent = [System.IO.Path]::GetDirectoryName($outputFullPath)
$statusParent = [System.IO.Path]::GetDirectoryName($statusFullPath)
if ([string]::IsNullOrWhiteSpace($outputParent)) {
    throw "OutputPath has no parent directory: $OutputPath"
}
if ([string]::IsNullOrWhiteSpace($statusParent)) {
    throw "StatusPath has no parent directory: $StatusPath"
}
if (-not (Test-PathInsideOrEqual -Path $outputParent -RootPath $controlCenterFullPath)) {
    throw "OutputPath '$outputFullPath' is unsafe: output must remain inside the control center '$controlCenterFullPath'."
}
if (-not (Test-PathInsideOrEqual -Path $statusParent -RootPath $controlCenterFullPath)) {
    throw "StatusPath '$statusFullPath' is unsafe: output must remain inside the control center '$controlCenterFullPath'."
}
Ensure-Directory -Path $outputParent -Description 'output parent' | Out-Null
Ensure-Directory -Path $statusParent -Description 'status parent' | Out-Null

$previousStatus = $null
$errors = New-Object 'System.Collections.Generic.List[string]'
if (Test-Path -LiteralPath $statusFullPath -PathType Leaf) {
    try {
        $previousStatus = Get-Content -LiteralPath $statusFullPath -Raw | ConvertFrom-Json
    }
    catch {
        [void]$errors.Add("Could not read previous status: $($_.Exception.Message)")
    }
}

$snapshots = @(Get-ProjectSnapshots -ProjectsRoot $ProjectsRoot -ControlCenterPath $controlCenterFullPath -Config $config)
$previousProjects = @()
if ($null -ne $previousStatus) {
    $projectsProperty = $previousStatus.PSObject.Properties['projects']
    if ($null -ne $projectsProperty -and $null -ne $projectsProperty.Value) {
        $previousProjects = @($projectsProperty.Value)
    }
}

$previousByName = @{}
foreach ($previousProject in $previousProjects) {
    if ($null -ne $previousProject.name) {
        $previousByName[[string]$previousProject.name] = $previousProject
    }
}

$currentByName = @{}
$added = New-Object 'System.Collections.Generic.List[string]'
$changed = New-Object 'System.Collections.Generic.List[string]'
foreach ($snapshot in $snapshots) {
    $name = [string]$snapshot.name
    $currentByName[$name] = $snapshot
    if (-not $previousByName.ContainsKey($name)) {
        [void]$added.Add($name)
    }
    elseif ([string]$previousByName[$name].fingerprint -ne [string]$snapshot.fingerprint) {
        [void]$changed.Add($name)
    }
}

$removed = New-Object 'System.Collections.Generic.List[string]'
foreach ($previousName in $previousByName.Keys) {
    if (-not $currentByName.ContainsKey($previousName)) {
        [void]$removed.Add([string]$previousName)
    }
}

$generatedAtUtc = ConvertTo-UtcString -Value ([DateTime]::UtcNow)
try {
    Write-ProjectOutputs `
        -OutputPath $outputFullPath `
        -StatusPath $statusFullPath `
        -ProjectSnapshots $snapshots `
        -GeneratedAtUtc $generatedAtUtc `
        -AddedProjects @($added | Sort-Object) `
        -ChangedProjects @($changed | Sort-Object) `
        -RemovedProjects @($removed | Sort-Object) `
        -Errors @($errors)
}
catch {
    $originalErrorMessage = $_.Exception.Message
    $temporaryCleanupErrors = New-Object 'System.Collections.Generic.List[string]'
    foreach ($temporaryPath in @("$outputFullPath.tmp", "$statusFullPath.tmp")) {
        if (-not (Remove-TransactionPath -Path $temporaryPath)) {
            [void]$temporaryCleanupErrors.Add("temporary cleanup failed for '$temporaryPath'")
        }
    }
    if ($temporaryCleanupErrors.Count -gt 0) {
        throw ($originalErrorMessage + '; ' + [string]::Join('; ', $temporaryCleanupErrors))
    }
    throw
}
