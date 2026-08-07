# Scoped review package — Graphify output-root fix

Brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-graphify-output-fix-brief.md`
Report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

Root-cause evidence: Graphify 0.9.32 reads `GRAPHIFY_OUT` at process startup;
the real refresh passed `--out F:\Proyectos\Analista` but still created a stat
cache at `F:\Proyectos\graphify-out`. The fix sets an absolute child-process
`GRAPHIFY_OUT` under the selected control center and restores the prior value.

Review only:

- `scripts/actualizar-graphify.ps1`, child environment handling around the real invocation.
- `tests/Invoke-GraphifySafetySmokeTest.ps1`, environment marker regression and cleanup.
- The addendum in `task-6-report.md`.

Claimed evidence:

```text
RED: Graphify child should receive the temporary control-center GRAPHIFY_OUT
GREEN: PASS: Graphify safety smoke test
PASS: project index smoke test
PASS: context refresh smoke test
PASS: PowerShell parse check
```

Binding constraints: no real Graphify run in this fix, no deletion or mutation
of `F:\Proyectos\graphify-out`, no project changes, no secrets/API keys, no Git
or commits, no deployments/migrations/payments, no new public test switch, and
WhatIf must not set or change the environment.
