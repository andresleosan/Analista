# Task 2: Implement the Project Metadata Index

**Files:**
- Create: `scripts/actualizar-indice.ps1`
- Create: `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- Create: `INDICE-PROYECTOS.md`
- Create: `state/context-status.json`

**Interfaces:**
- Command: `scripts/actualizar-indice.ps1` with `-ConfigPath`, `-ProjectsRoot`, `-ControlCenterPath`, `-OutputPath`, and `-StatusPath` parameters.
- The override parameters allow isolated tests with temporary roots and outputs.
- Exit nonzero when the configured projects root or output parent cannot be created.
- Write Markdown to `OutputPath` and machine-readable JSON to `StatusPath`.
- JSON status keys: `generatedAtUtc`, `projects`, `added`, `changed`, `removed`, and `errors`.

## Required implementation

Use TDD: write the smoke test first, run it and observe the expected failure because the script does not exist, then implement the smallest behavior that makes it pass, rerun it, and refactor only while green.

Implement `Test-ExcludedPath`:

```powershell
function Test-ExcludedPath {
    param([string]$Path, [string[]]$IgnoredDirectoryNames, [string[]]$IgnoredFilePatterns)
    $normalized = [System.IO.Path]::GetFullPath($Path)
    foreach ($segment in $normalized -split '[\\/]') {
        if ($IgnoredDirectoryNames -contains $segment) { return $true }
    }
    $leaf = [System.IO.Path]::GetFileName($normalized)
    foreach ($pattern in $IgnoredFilePatterns) {
        if ($leaf -like $pattern) { return $true }
    }
    return $false
}
```

Implement `Get-RelativePath` compatibly with PowerShell 5.1:

```powershell
function Get-RelativePath {
    param([string]$RootPath, [string]$Path)
    $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd('\') + '\'
    $full = [System.IO.Path]::GetFullPath($Path)
    if (-not $full.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Path is outside root: $Path"
    }
    return $full.Substring($root.Length).Replace('\', '/')
}
```

Implement `Get-ProjectSnapshot` with `ProjectPath`, `Config`, and `ControlCenterPath` parameters. It must recursively enumerate files, filter every file before metadata access, calculate maximum `LastWriteTimeUtc`, file count, byte count, and known document relative paths, and return `name`, `path`, `lastModifiedUtc`, `fileCount`, `byteCount`, `knownDocuments`, and `fingerprint`. Never read secret file contents or include secret paths. The fingerprint is SHA-256 over sorted `relativePath|length|lastWriteTimeUtc` rows.

Implement `Get-ProjectSnapshots` with `ProjectsRoot`, `ControlCenterPath`, and `Config`: enumerate only direct child directories, skip the normalized control-center directory, and sort case-insensitively by name.

Implement `ConvertTo-ProjectIndexMarkdown`. It must render:

```markdown
# Índice de proyectos

Actualizado: fecha UTC generada por el script

| Proyecto | Ruta | Archivos | Documentación conocida | Último cambio | Estado |
|---|---|---:|---|---|---|
```

Escape pipe characters in names, use inline code for paths, and report `nuevo`, `cambiado`, or `sin cambios` from the previous status JSON. Do not infer product status, deployment status, or stack from filenames.

Write Markdown and JSON atomically to sibling `.tmp` files with UTF-8 and replace targets with `Move-Item -Force`. On render failure remove only temporary files and preserve previous outputs.

The smoke fixture must contain `alpha/docs`, `alpha/node_modules`, `alpha/README.md`, `alpha/.env`, and `alpha/node_modules/ignored.js`. Assert that `alpha` appears, `.env` and `node_modules` do not appear, the first run reports one added project, the identical second run reports no changed project, and appending to `README.md` makes the third run report `alpha` changed. Delete the fixture in `finally`.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
```

Expected output: `PASS: project index smoke test`, exit code `0`, and no warnings.

## Constraints

- Work only in `F:\Proyectos\Analista` and the assigned files.
- Do not modify projects, secrets, credentials, Git, deployments, migrations, paid services, or global skills.
- Do not delegate or subdelegate.
- Do not commit; no Git repository exists.
- Keep PowerShell 5.1 compatibility and use `apply_patch` for edits.
- Report any critical security issue as BLOCKED.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-report.md`. Include files, TDD RED and GREEN evidence with commands and outputs, self-review, concerns, and status. Return only the short SDD status contract after writing it.
