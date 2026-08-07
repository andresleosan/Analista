# Cronos Analyst Context Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert `F:\Proyectos\Analista` into Cronos's persistent control center for project context, durable memory, agenda management, and safe Graphify-assisted discovery.

**Architecture:** Markdown files remain the human-readable source of truth for the assistant. PowerShell 5.1 scripts maintain a metadata index and orchestration status without modifying project code. Graphify runs locally in code-only mode for unattended updates; semantic document extraction stays in an active Cronos session unless an explicitly approved external backend is configured.

**Tech Stack:** Markdown, JSON, PowerShell 5.1, Python 3.14.6, Graphify 0.9.32, Windows Task Scheduler. No database, web server, paid API, or frontend.

## Global Constraints

- The control center is `F:\Proyectos\Analista`.
- Project roots under `F:\Proyectos` remain independent.
- Context refresh may write only to the control center and the shared `F:\Proyectos\.graphifyignore` file.
- Context refresh must never modify project source code, project documentation, Git history, or credentials.
- `.git`, `node_modules`, build output, caches, secrets, and generated Graphify output are excluded.
- Scheduled work uses local deterministic extraction only and never sends project content to a paid API.
- Semantic document extraction is performed only in an active Cronos session or after explicit external-backend approval.
- If a source is unavailable or contradictory, the result is reported as unverified instead of silently promoted to memory.
- Production deploys, destructive migrations, data deletion, spending, secret handling, and new global skills remain human-approved operations.
- `F:\Proyectos\Analista` is not currently a Git repository; no commit step is included until a repository exists.

## Implementation Order

The tasks are intentionally ordered by dependency:

1. Create the control-center documents and configuration.
2. Implement and test the project metadata index.
3. Add the memory and agenda operating rules.
4. Add safe Graphify extraction and graph status handling.
5. Add the session/scheduled orchestrator and an opt-in Windows task definition.
6. Run the complete verification and security review.

The Graphify layer can be disabled while the index and assistant workflow remain usable.

### Task 1: Create the Control Center

**Files:**
- Create: `BRIEF.md`
- Create: `STACK.md`
- Create: `MEMORIA.md`
- Create: `AGENDA.md`
- Create: `AGENTS.md`
- Create: `tasks.md`
- Create: `config/contexto.json`
- Test: PowerShell file and JSON validation commands

**Interfaces:**
- `config/contexto.json` is the shared configuration consumed by every script.
- `BRIEF.md`, `STACK.md`, `MEMORIA.md`, and `AGENDA.md` are Markdown sources read by Cronos.
- `AGENTS.md` is the local entry point read when OpenCode opens the control center.

- [ ] **Step 1: Write the shared configuration**

Create `config/contexto.json` with these exact keys and default paths:

```json
{
  "projectsRoot": "F:/Proyectos",
  "controlCenter": "F:/Proyectos/Analista",
  "indexPath": "F:/Proyectos/Analista/INDICE-PROYECTOS.md",
  "statusPath": "F:/Proyectos/Analista/state/context-status.json",
  "graphifyOutput": "F:/Proyectos/Analista/graphify-out",
  "ignoredDirectoryNames": [
    ".git",
    "node_modules",
    "dist",
    "build",
    "coverage",
    ".next",
    ".nuxt",
    ".cache",
    "graphify-out"
  ],
  "ignoredFilePatterns": [
    ".env",
    ".env.*",
    "*.pem",
    "*.key",
    "*.p12",
    "*.pfx",
    "*credentials*",
    "*secret*"
  ],
  "knownDocumentNames": [
    "BRIEF.md",
    "STACK.md",
    "tasks.md",
    "README.md"
  ]
}
```

- [ ] **Step 2: Create the durable control-center documents**

Create `BRIEF.md` with the approved purpose: Cronos is a chat-based expert web-project analyst for one user, not a standalone application; it reads `F:\Proyectos`, maintains context in the control center, and does not alter project code during context refresh.

Create `STACK.md` with this candidate classification and stack:

```markdown
# Stack del centro de control

Nivel candidato: 1 — automatización local y asistencia documental
Lenguaje de automatización: PowerShell 5.1
Formato de datos: Markdown y JSON
Análisis de relaciones: Graphify 0.9.32
Programación periódica: Windows Task Scheduler
Base de datos: ninguna
Frontend: ninguno
Testing: smoke tests de PowerShell y verificaciones de salida
Secretos: ninguno requerido
Modelo semántico externo: desactivado por defecto
Despliegue: no aplica
```

Create `MEMORIA.md` with sections for user preferences, confirmed rules, durable decisions, and lessons. State that active work items belong only in `AGENDA.md` and that secrets never belong in memory.

Create `AGENDA.md` with an empty table using `pendiente`, `en progreso`, `revisión`, and `completada` as the only statuses.

- [ ] **Step 3: Add local agent instructions**

Create `AGENTS.md` with these operational rules:

```markdown
# Cronos Analista

Antes de responder, leer `BRIEF.md`, `STACK.md`, `MEMORIA.md`, `AGENDA.md` e `INDICE-PROYECTOS.md` cuando existan.

Si la pregunta no identifica un proyecto, preguntar cuál debe usarse antes de leer contexto específico.

Ejecutar la actualización de índice antes de una consulta que dependa de cambios recientes.

Registrar solo preferencias, decisiones, lecciones y reglas durables. Los pendientes activos viven en `AGENDA.md`.

No modificar código ni documentación de los proyectos durante una actualización de contexto.

Distinguir hechos verificados, inferencias, supuestos y recomendaciones. Citar rutas de archivos cuando respalden una respuesta.
```

- [ ] **Step 4: Initialize the project task ledger**

Create `tasks.md` with the six implementation tasks from this plan and the state `pendiente` for each. The ledger is for the control-center setup, not for the user's individual projects.

- [ ] **Step 5: Validate the control-center base**

Run from `F:\Proyectos\Analista`:

```powershell
$required = @('BRIEF.md','STACK.md','MEMORIA.md','AGENDA.md','AGENTS.md','tasks.md','config/contexto.json')
$missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing) { throw "Missing control-center files: $($missing -join ', ')" }
$config = Get-Content -LiteralPath 'config/contexto.json' -Raw | ConvertFrom-Json
if ($config.projectsRoot -ne 'F:/Proyectos') { throw 'Unexpected projectsRoot' }
if ($config.controlCenter -ne 'F:/Proyectos/Analista') { throw 'Unexpected controlCenter' }
Write-Output 'PASS: control-center base'
```

- [ ] **Step 6: Apply the Cronos classification gate**

Show the complete `STACK.md` to the operator and wait for explicit confirmation of the project level before creating automation scripts. The current recommendation is Nivel 1 because this is local documentation and automation without a deployed application.

### Task 2: Implement the Project Metadata Index

**Files:**
- Create: `scripts/actualizar-indice.ps1`
- Create: `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- Create: `INDICE-PROYECTOS.md`
- Create: `state/context-status.json`

**Interfaces:**
- Command: `scripts/actualizar-indice.ps1` with `-ConfigPath`, `-ProjectsRoot`, `-ControlCenterPath`, `-OutputPath`, and `-StatusPath` parameters.
- `-ProjectsRoot`, `-ControlCenterPath`, `-OutputPath`, and `-StatusPath` override configuration paths for isolated tests.
- The script exits nonzero when the configured projects root or output parent cannot be created.
- The script writes Markdown to `OutputPath` and machine-readable JSON to `StatusPath`.
- The JSON status contains `generatedAtUtc`, `projects`, `added`, `changed`, `removed`, and `errors`.

- [ ] **Step 1: Define exclusion and path helpers**

Implement these PowerShell functions in `scripts/actualizar-indice.ps1`:

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

The implementation must normalize paths with `GetFullPath`, compare them case-insensitively, and never read file contents while calculating freshness.

- [ ] **Step 2: Build one project snapshot**

Implement `Get-ProjectSnapshot` with parameters `ProjectPath`, `Config`, and `ControlCenterPath`. It must:

1. Recursively enumerate files with `Get-ChildItem -File -Recurse`.
2. Filter every file through `Test-ExcludedPath` before reading metadata.
3. Record the maximum `LastWriteTimeUtc`, file count, byte count, and relative paths for known documents only.
4. Never include the contents or paths of files matching secret patterns.
5. Return a `[pscustomobject]` containing `name`, `path`, `lastModifiedUtc`, `fileCount`, `byteCount`, `knownDocuments`, and `fingerprint`.

The fingerprint must be a SHA-256 hash of sorted `relativePath|length|lastWriteTimeUtc` rows, computed with `System.Security.Cryptography.SHA256`, so a second unchanged run can be identified without parsing project files.

- [ ] **Step 3: Enumerate direct project folders**

Implement `Get-ProjectSnapshots` with parameters `ProjectsRoot`, `ControlCenterPath`, and `Config`. Enumerate only direct child directories of `ProjectsRoot`, skip the directory whose normalized path equals `ControlCenterPath`, and return snapshots sorted by case-insensitive project name.

- [ ] **Step 4: Render the Markdown index**

Implement `ConvertTo-ProjectIndexMarkdown` so `INDICE-PROYECTOS.md` contains:

```markdown
# Índice de proyectos

Actualizado: fecha UTC generada por el script

| Proyecto | Ruta | Archivos | Documentación conocida | Último cambio | Estado |
|---|---|---:|---|---|---|
```

Use inline code for filesystem paths, escape pipe characters in names, and report `nuevo`, `cambiado`, or `sin cambios` based on the previous status JSON. Do not infer product status, deployment status, or technology stack from filenames.

- [ ] **Step 5: Write outputs atomically**

Write the Markdown and JSON to sibling `.tmp` files using UTF-8, then replace the target with `Move-Item -Force`. If rendering fails, remove only the temporary files and leave the previous index intact.

- [ ] **Step 6: Add the isolated smoke test**

Create `tests/Invoke-ActualizarIndiceSmokeTest.ps1` using a temporary fixture with:

```powershell
$fixture = Join-Path $env:TEMP 'cronos-index-fixture'
$output = Join-Path $env:TEMP 'cronos-index-output'
Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $output -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path (Join-Path $fixture 'alpha/docs') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture 'alpha/node_modules') -Force | Out-Null
Set-Content -LiteralPath (Join-Path $fixture 'alpha/README.md') -Value '# Alpha' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $fixture 'alpha/.env') -Value 'TOKEN=must-not-index' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $fixture 'alpha/node_modules/ignored.js') -Value 'ignored' -Encoding UTF8
```

Run the indexer against the fixture and assert that `alpha` appears, `.env` and `node_modules` do not appear, the first status reports one `added` project, the second identical run reports no `changed` project, and appending to `README.md` makes the third run report `alpha` as changed. The test must delete the fixture in a `finally` block.

- [ ] **Step 7: Run the index smoke test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
```

Expected output: `PASS: project index smoke test` and exit code `0`.

### Task 3: Document Memory, Agenda, and Session Operations

**Files:**
- Create: `docs/runbook-contexto.md`
- Modify: `AGENTS.md`
- Modify: `MEMORIA.md`
- Modify: `AGENDA.md`

**Interfaces:**
- The runbook defines the commands Cronos uses at session start and before a project-specific answer.
- `MEMORIA.md` stores durable knowledge only.
- `AGENDA.md` is the sole source of active work items.

- [ ] **Step 1: Write the runbook**

Document this session procedure in `docs/runbook-contexto.md`:

```powershell
Test-Path -LiteralPath 'F:\Proyectos'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\actualizar-indice.ps1'
```

Then instruct Cronos to read the control-center files, ask for a project when one is not named, inspect only relevant project documentation, cite source paths, and record durable results after the answer.

- [ ] **Step 2: Define memory entry format**

Add this exact format to `MEMORIA.md`:

```markdown
## [fecha AAAA-MM-DD] — [título]

Proyecto: [nombre o transversal]
Tipo: preferencia | decisión | lección | regla
Hecho: [información durable confirmada]
Aplicación futura: [cómo debe cambiar una respuesta futura]
Fuente: [ruta o conversación]
Estado: vigente | reemplazada
```

The implementation must replace every bracketed field with real values when writing entries; the template itself is documentation, not a memory entry.

- [ ] **Step 3: Define agenda entry format**

Add this table format to `AGENDA.md`:

```markdown
| ID | Proyecto | Pendiente | Próximo paso | Prioridad | Estado | Fecha objetivo |
|---|---|---|---|---|---|---|
```

Use `sin fecha` when the user has not supplied a date. Never invent due dates.

- [ ] **Step 4: Validate the operating rules**

Read `AGENTS.md`, `MEMORIA.md`, `AGENDA.md`, and `docs/runbook-contexto.md` and confirm that they contain the same project-selection rule, the same memory boundary, and the same no-secret rule. Resolve any conflict before continuing.

### Task 4: Add Safe Graphify Integration

**Files:**
- Create: `config/graphify.json`
- Create: `scripts/actualizar-graphify.ps1`
- Create: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Create or modify: `F:\Proyectos\.graphifyignore`
- Create: `state/graphify-status.json`

**Interfaces:**
- Command: `scripts/actualizar-graphify.ps1` with `-Mode Scheduled|Manual`, `-ProjectsRoot`, `-ControlCenterPath`, and `-WhatIf` parameters.
- `Scheduled` always uses deterministic `graphify extract $ProjectsRoot --out $ControlCenterPath --code-only --no-cluster`.
- `Manual` may omit `--code-only` only when the operator has explicitly configured and accepted a semantic backend and its cost.
- The script writes `state/graphify-status.json` with `startedAtUtc`, `completedAtUtc`, `mode`, `command`, `exitCode`, `semanticMode`, and `error`.
- The script never prints environment variable values or command-line secrets.

- [ ] **Step 1: Configure Graphify output and modes**

Create `config/graphify.json`:

```json
{
  "projectsRoot": "F:/Proyectos",
  "controlCenter": "F:/Proyectos/Analista",
  "outputDirectory": "F:/Proyectos/Analista",
  "scheduledSemanticMode": "code-only",
  "manualSemanticMode": "disabled",
  "graphifyVersionVerified": "0.9.32"
}
```

- [ ] **Step 2: Add the shared ignore file**

Create `F:\Proyectos\.graphifyignore` with these entries:

```text
Analista/
graphify-out/
**/.git/
**/node_modules/
**/dist/
**/build/
**/coverage/
**/.next/
**/.nuxt/
**/.cache/
**/.env
**/.env.*
**/*.pem
**/*.key
**/*.p12
**/*.pfx
**/*credentials*
**/*secret*
```

This keeps the control center, generated graph, and secret material out of the project graph. The file is the only write outside `F:\Proyectos\Analista` allowed by this plan.

- [ ] **Step 3: Implement scheduled deterministic extraction**

In `scripts/actualizar-graphify.ps1`, validate that `graphify --version` is available and matches `0.9.32` before execution. Resolve the project root and output directory from parameters, then invoke:

```powershell
graphify extract $ProjectsRoot --out $ControlCenterPath --code-only --no-cluster
```

Use `&` with an argument array rather than interpolating one shell command string. Capture `$LASTEXITCODE`, write the status JSON atomically, and return the same nonzero exit code after recording an error. In `-WhatIf` mode, validate paths and print the command without invoking Graphify.

- [ ] **Step 4: Define the manual semantic boundary**

Reject `-Mode Manual` when `manualSemanticMode` is `disabled`. The error must state that semantic document extraction is an active-session operation or requires explicit backend and cost approval. Do not inspect, print, or request API keys from the script.

- [ ] **Step 5: Add Graphify safety coverage**

Create a temporary fixture containing `src/App.ts`, `.env`, `node_modules/ignored.js`, and `dist/generated.js`, plus a fixture-local `.graphifyignore` containing the same exclusion rules. Run the deterministic command with `--out` pointing to a temporary output directory, then assert:

1. The command exits `0`.
2. `graphify-out/graph.json` exists in the temporary output.
3. The graph contains the TypeScript source or its structural symbol.
4. The graph JSON contains none of `.env`, `node_modules`, `dist`, `TOKEN=`, or `secret-value`.
5. The real `F:\Proyectos\Analista\graphify-out` is not touched by the fixture test.

Always remove the fixture and temporary output in `finally`.

- [ ] **Step 6: Run the Graphify safety test**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-GraphifySafetySmokeTest.ps1'
```

Expected output: `PASS: Graphify safety smoke test` and exit code `0`.

### Task 5: Orchestrate Session Refresh and Optional Scheduling

**Files:**
- Create: `scripts/actualizar-contexto.ps1`
- Create: `scripts/registrar-tarea-contexto.ps1`
- Create: `scripts/eliminar-tarea-contexto.ps1`
- Create: `tests/Invoke-ContextRefreshSmokeTest.ps1`
- Modify: `docs/runbook-contexto.md`
- Create: `state/context-refresh.log`

**Interfaces:**
- Command: `scripts/actualizar-contexto.ps1 -Mode Session|Scheduled -WhatIf`
- Command: `scripts/registrar-tarea-contexto.ps1 -WhatIf -DayOfWeek Sunday -At '03:00'`
- Command: `scripts/eliminar-tarea-contexto.ps1 -WhatIf`
- Scheduled task name: `Cronos-Actualizar-Contexto`

- [ ] **Step 1: Implement the context orchestrator**

`actualizar-contexto.ps1` must:

1. Call `actualizar-indice.ps1` first.
2. Stop before Graphify if index generation fails.
3. Call `actualizar-graphify.ps1 -Mode Scheduled` for scheduled mode.
4. Call `actualizar-graphify.ps1 -Mode Scheduled` for session mode by default, because local code extraction is safe and deterministic.
5. Preserve the index success result if Graphify fails, while writing the Graphify failure to `state/graphify-status.json` and the overall refresh status to `state/context-status.json`.
6. Return `0` only when the index succeeds; return `1` when the index fails.

Use `-WhatIf` to validate every path and print both child commands without changing files.
Append one UTF-8 line to `state/context-refresh.log` containing only the UTC timestamp, mode, index exit code, and Graphify exit code; never append project contents or environment values.

- [ ] **Step 2: Add the refresh smoke test**

Run the orchestrator against a temporary projects root and temporary output paths. Assert that an index is produced, a failed Graphify invocation does not erase the index, and the final exit code is `0` when only Graphify fails.

- [ ] **Step 3: Define the scheduled task without registering it**

`registrar-tarea-contexto.ps1` must use `Register-ScheduledTask` only when `-WhatIf` is absent. The default action is:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File F:\Proyectos\Analista\scripts\actualizar-contexto.ps1 -Mode Scheduled
```

Use the current user principal with limited privileges, a weekly Sunday trigger at `03:00`, and no stored credentials. `-WhatIf` must print the task name, trigger, principal, and action without registering anything. Registration remains an explicit operator action because it changes Windows background behavior.

- [ ] **Step 4: Add task removal**

`eliminar-tarea-contexto.ps1` must check whether `Cronos-Actualizar-Contexto` exists, remove it only without `-WhatIf`, and report `not-found` without failure when it is absent.

- [ ] **Step 5: Validate task definitions**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/registrar-tarea-contexto.ps1' -WhatIf -DayOfWeek Sunday -At '03:00'
```

Expected output includes `Cronos-Actualizar-Contexto`, `Sunday`, `03:00`, and the absolute orchestrator path, with no new scheduled task created.

### Task 6: Complete Verification and Security Review

**Files:**
- Modify: `tasks.md`
- Modify: `docs/runbook-contexto.md`
- Review: all files created by Tasks 1-5

**Interfaces:**
- The final verification report is recorded in `state/context-status.json` and summarized in `docs/runbook-contexto.md`.
- `tasks.md` moves each task to `revisión` only after its command evidence exists.

- [ ] **Step 1: Run the base validation**

Run the control-center validation from Task 1 and confirm all required files and JSON documents parse successfully.

- [ ] **Step 2: Run all smoke tests**

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-GraphifySafetySmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ContextRefreshSmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/registrar-tarea-contexto.ps1' -WhatIf -DayOfWeek Sunday -At '03:00'
```

All smoke tests must exit `0`. A failing test blocks task approval.

- [ ] **Step 3: Audit generated files for leakage**

Search `INDICE-PROYECTOS.md`, `state`, and `graphify-out` for `.env`, `TOKEN=`, `secret-value`, private-key markers, and credential filenames. Any hit is a blocking security finding and must be removed before completion.

- [ ] **Step 4: Verify project immutability**

Capture a before/after file listing for one representative project, including `hachi-greciaspa`, while running the refresh in `-WhatIf` and normal mode. Confirm that no project file timestamp or content changes.

- [ ] **Step 5: Verify Graphify health**

If `graphify-out/graph.json` exists, run:

```powershell
graphify diagnose multigraph --graph 'F:\Proyectos\Analista\graphify-out\graph.json'
```

Record any dangling, missing, collapsed, or self-loop warning in the runbook; do not claim a healthy graph without the command output.

- [ ] **Step 6: Record evidence and task states**

Add the actual command results and UTC timestamps to `docs/runbook-contexto.md`. Move only verified tasks in `tasks.md` from `pendiente` to `revisión`. Do not mark the setup `aprobada` without the security and test evidence.

## Plan Self-Review

- The plan covers the control-center files, project discovery, change detection, durable memory, agenda rules, Graphify safety, scheduled orchestration, and verification criteria from the approved design.
- The design's requirement to continue when Graphify fails is implemented by preserving an index success result and recording Graphify failure separately.
- The design's no-paid-API requirement is enforced by scheduled `--code-only` extraction and disabled manual semantic mode.
- The design's project-selection rule is repeated in `AGENTS.md` and the runbook.
- The plan contains no database, frontend, deployment, destructive migration, or automatic project-code modification.
- The plan is compatible with the verified environment: PowerShell 5.1, Python 3.14.6, and Graphify 0.9.32.
