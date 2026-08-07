# Task 5: Orchestrate Session Refresh and Optional Scheduling

**Files:**
- Create: `scripts/actualizar-contexto.ps1`
- Create: `scripts/registrar-tarea-contexto.ps1`
- Create: `scripts/eliminar-tarea-contexto.ps1`
- Create: `tests/Invoke-ContextRefreshSmokeTest.ps1`
- Modify: `docs/runbook-contexto.md`
- Create: `state/context-refresh.log`

**Interfaces:**
- `scripts/actualizar-contexto.ps1 -Mode Session|Scheduled -WhatIf`
- Optional test-safe overrides on the orchestrator: `-ProjectsRoot` and `-ControlCenterPath`; defaults come from existing configs.
- `scripts/registrar-tarea-contexto.ps1 -WhatIf -DayOfWeek Sunday -At '03:00'`
- `scripts/eliminar-tarea-contexto.ps1 -WhatIf`
- Scheduled task name: `Cronos-Actualizar-Contexto`

## Required implementation

Use TDD: write `tests/Invoke-ContextRefreshSmokeTest.ps1` first and observe RED because the orchestrator is absent; then implement and get GREEN.

Implement `actualizar-contexto.ps1` so it:

1. Calls `actualizar-indice.ps1` first, passing optional roots and output/status paths derived from the selected control center.
2. Stops before Graphify if index generation fails.
3. Calls `actualizar-graphify.ps1 -Mode Scheduled` for Scheduled mode.
4. Calls `actualizar-graphify.ps1 -Mode Scheduled` for Session mode by default; local code extraction is deterministic and safe.
5. Preserves index success when Graphify fails; Graphify failure is recorded in `state/graphify-status.json`, overall status in `state/context-status.json`, and the return code is `0` when index succeeds and `1` when index fails.
6. Appends one UTF-8 line to `state/context-refresh.log` containing only UTC timestamp, mode, index exit code, and Graphify exit code. Never append project content or environment values.
7. Uses `-WhatIf` to validate paths and print child commands without changing files.

The orchestrator may pass `-ProjectsRoot` and `-ControlCenterPath` to child scripts for isolated tests, but normal invocation must use `config/contexto.json` and `config/graphify.json` defaults.

Implement `registrar-tarea-contexto.ps1` with `Register-ScheduledTask` only when `-WhatIf` is absent. Defaults:

- Task name: `Cronos-Actualizar-Contexto`
- Action: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File F:\Proyectos\Analista\scripts\actualizar-contexto.ps1 -Mode Scheduled`
- Principal: current user, limited privileges, no stored credentials
- Trigger: weekly Sunday at `03:00`

`-WhatIf` prints task name, trigger, principal, and action without registering anything. Registration remains opt-in because it changes Windows background behavior.

Implement `eliminar-tarea-contexto.ps1` so it checks for the task, removes it only without `-WhatIf`, and reports `not-found` without failure when absent.

The smoke test must:

- Use a temporary projects root and temporary control center.
- Assert the index is produced before Graphify.
- Make a fake Graphify command return nonzero and assert the index remains and overall exit code is `0`.
- Assert `-WhatIf` produces no files.
- Assert the log contains only the four permitted fields.
- Assert scheduler `-WhatIf` outputs the expected task definition and does not register a task.
- Assert removal `-WhatIf` is safe when the task is absent.
- Clean every fixture in `finally`.

Run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ContextRefreshSmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/registrar-tarea-contexto.ps1' -WhatIf -DayOfWeek Sunday -At '03:00'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/eliminar-tarea-contexto.ps1' -WhatIf
```

Expected output: `PASS: context refresh smoke test`, expected scheduler details, exit code `0`, and no warnings.

Update `docs/runbook-contexto.md` with the session command, the scheduled command, the opt-in registration command, and the removal command. State clearly that the controller does not register the task automatically.

## Constraints

- Work only in `F:\Proyectos\Analista` and assigned files.
- Do not register a real scheduled task during tests.
- Do not modify user projects, credentials, Git, deployments, migrations, paid services, or global skills.
- Do not delegate or subdelegate.
- Keep PowerShell 5.1 compatibility and use `apply_patch`.
- A critical security finding blocks the task.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-5-report.md`. Include TDD RED/GREEN commands and outputs, files, scheduler safety checks, self-review, concerns, and status. Return only the short SDD status contract after writing it.
