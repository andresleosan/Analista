# Task 6 fix: bound test overrides to safe output roots

## Finding

The default configuration writes to `F:\Proyectos\Analista`, but public
parameters currently allow `ControlCenterPath`, `OutputPath`, or `StatusPath`
to point at an arbitrary project directory. This is unsafe even though tests
use temporary paths.

## Assigned files

- Modify: `scripts/actualizar-indice.ps1`
- Modify: `scripts/actualizar-graphify.ps1`
- Modify: `scripts/actualizar-contexto.ps1`
- Modify: `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- Modify: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Modify: `tests/Invoke-ContextRefreshSmokeTest.ps1`
- Append report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

## Required fix

Use TDD and add failing tests before production changes:

1. Indexer: reject `OutputPath` and `StatusPath` when their parent is outside
   `ControlCenterPath`. Temporary control-center fixtures remain valid.
2. Graphify: when the supplied `ControlCenterPath` is inside the configured
   `projectsRoot`, allow it only when it equals the configured control center;
   reject a project path such as `F:\Proyectos\hachi-greciaspa`. Temporary
   control centers outside the configured real root remain valid.
3. Context orchestrator: apply the same rule to an overridden control center;
   reject a project path inside the configured real projects root unless it is
   the configured control center.
4. Preserve normal defaults and all existing fixture overrides.
5. Error messages must identify the rejected path and state that output must
   remain inside the control center or equal the configured control center.
6. Run all three smoke tests and PowerShell parse checks.

Do not read project contents in the new safety tests. Use `-WhatIf` where
available and paths only. Do not alter or delete the stale cache; that is a
separate already-authorized cleanup.

## Constraints

- No project modifications, secrets, API keys, Git, commits, deployments,
  migrations, paid services, or subdelegation.
- Keep PowerShell 5.1 compatibility and existing public behavior for safe paths.
- A critical security finding blocks.

## Report

Append RED/GREEN evidence, root cause, files, and concerns to `task-6-report.md`.
