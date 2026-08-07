# Scoped re-review package — Task 5 fix round 1

Plan: `docs/superpowers/plans/2026-08-06-cronos-analista-contexto.md`
Brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-5-brief.md`
Report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-5-report.md`

The task review found these Important requirements missing:

1. Do not preserve a stale `graphify-status.json` after a current Graphify
   failure; preserve only a valid status from the current execution.
2. Test a failing index and prove Graphify is not invoked and overall exit code
   is `1`.
3. Prove orchestrator `-WhatIf` does not modify fixture, marker, or outputs.
4. Test default-path `Scheduled -WhatIf` without overrides.
5. Distinguish an absent scheduled task from query/service/permission errors.

The fix also adds scheduler WhatIf assertions for `InteractiveToken`, limited
privileges, no stored credentials, and exit code `0`.

This checkout has no Git repository. Review only these fix-related files:

- `scripts/actualizar-contexto.ps1`
- `scripts/eliminar-tarea-contexto.ps1`
- `scripts/registrar-tarea-contexto.ps1`
- `tests/Invoke-ContextRefreshSmokeTest.ps1`
- The correction addendum in `task-5-report.md`

Claimed evidence:

```text
RED: stale fallback, scheduler WhatIf details, and service-unavailable query
GREEN: PASS: context refresh smoke test
Suite: context, index, Graphify and PowerShell parse all PASS
```

Global constraints: no real refresh against `F:\Proyectos`, no real task
registration, no secrets, no Git/commits, no deployments/migrations/payments,
and no project modifications.
