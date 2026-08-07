# Task 4: Add Safe Graphify Integration

**Files:**
- Create: `config/graphify.json`
- Create: `scripts/actualizar-graphify.ps1`
- Create: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Create or modify: `F:\Proyectos\.graphifyignore`
- Create: `state/graphify-status.json`

**Interfaces:**
- Command: `scripts/actualizar-graphify.ps1` with `-Mode Scheduled|Manual`, `-ProjectsRoot`, `-ControlCenterPath`, and `-WhatIf` parameters.
- Scheduled mode invokes deterministic `graphify extract $ProjectsRoot --out $ControlCenterPath --code-only --no-cluster`.
- Manual mode must be rejected while `manualSemanticMode` is `disabled`.
- Status JSON keys: `startedAtUtc`, `completedAtUtc`, `mode`, `command`, `exitCode`, `semanticMode`, and `error`.
- Do not print environment variable values or command-line secrets.

## Required implementation

Use TDD: write and run `tests/Invoke-GraphifySafetySmokeTest.ps1` before creating the production script; observe RED because the script is absent; then implement the minimum behavior and obtain GREEN.

Create `config/graphify.json` exactly:

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

Create or update `F:\Proyectos\.graphifyignore` exactly with:

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

Implement `scripts/actualizar-graphify.ps1` so it:

1. Validates that `graphify --version` is available and matches `0.9.32`.
2. Resolves paths from parameters, falling back to `config/graphify.json`.
3. Scheduled mode invokes Graphify with an argument array, not one interpolated shell string:

```powershell
graphify extract $ProjectsRoot --out $ControlCenterPath --code-only --no-cluster
```

4. Captures `$LASTEXITCODE`, writes `state/graphify-status.json` atomically, and returns the same nonzero code after recording an error.
5. In `-WhatIf`, validates paths and prints the command without invoking Graphify or modifying files.
6. Rejects Manual mode while `manualSemanticMode` is `disabled` with an explicit message that semantic extraction requires an active Cronos session or explicit backend/cost approval.
7. Never prints API keys, environment values, or command-line secrets.

The smoke fixture must contain `src/App.ts`, `.env`, `node_modules/ignored.js`, `dist/generated.js`, and a fixture-local `.graphifyignore` containing the exclusions. Run the deterministic command with `--out` pointing to temporary output and assert:

- Exit code `0`.
- Temporary `graphify-out/graph.json` exists.
- The graph includes the TypeScript source or a structural symbol.
- The graph contains none of `.env`, `node_modules`, `dist`, `TOKEN=`, or `secret-value`.
- Real `F:\Proyectos\Analista\graphify-out` is untouched.
- `-WhatIf` does not invoke Graphify or create output.
- Manual mode fails while disabled and does not print environment values.

Always remove fixture and temporary output in `finally`.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-GraphifySafetySmokeTest.ps1'
```

Expected output: `PASS: Graphify safety smoke test`, exit code `0`, no warnings.

## Constraints

- Work only in `F:\Proyectos\Analista` and the specifically assigned `F:\Proyectos\.graphifyignore`.
- Do not scan or modify real projects during tests.
- Do not use API keys, paid services, secrets, Git, commits, deployments, migrations, or global skills.
- Do not delegate or subdelegate.
- Keep PowerShell 5.1 compatibility and use `apply_patch`.
- A critical security finding blocks the task.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-4-report.md`. Include TDD RED/GREEN commands and outputs, files, safety checks, self-review, concerns, and status. Return only the short SDD status contract after writing it.
