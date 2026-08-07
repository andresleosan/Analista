# Scoped review package — override path safety fix

Brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-override-safety-brief.md`
Report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

Original Important finding: test overrides could direct index, Graphify, or
context output into a user project. The fix adds normalized root-boundary checks
while preserving temporary fixture roots.

Review only:

- `scripts/actualizar-indice.ps1`, `Test-PathInsideOrEqual` and output-parent checks.
- `scripts/actualizar-graphify.ps1`, configured-root/control-center checks.
- `scripts/actualizar-contexto.ps1`, configured-root/control-center checks.
- The three smoke tests' unsafe-path regressions.
- The override-safety addendum in `task-6-report.md`.

Claimed evidence:

```text
RED: all three unsafe overrides accepted before fix
GREEN: PASS: project index smoke test
GREEN: PASS: Graphify safety smoke test
GREEN: PASS: context refresh smoke test
Parse: 6 assigned files PASS
```

Global constraints: no project modifications, no cache deletion in this fix,
no secrets/API keys, no Git/commits, no deployments/migrations/payments, and no
subdelegation.
