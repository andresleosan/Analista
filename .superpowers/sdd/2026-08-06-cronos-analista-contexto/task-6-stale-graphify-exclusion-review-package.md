# Scoped review package — stale Graphify exclusion fix

Brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-stale-graphify-exclusion-brief.md`
Report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

Root cause: direct project enumeration skipped only the control center, so the
old generated `F:\Proyectos\graphify-out` directory appeared as a project. The
root Graphify ignore also did not explicitly exclude that stale directory.

Review only:

- `scripts/actualizar-indice.ps1`, direct-child exclusion in `Get-ProjectSnapshots`.
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`, stale root fixture regression.
- `F:\Proyectos\.graphifyignore` and the corresponding fixture ignore in
  `tests/Invoke-GraphifySafetySmokeTest.ps1`.
- The latest addendum in `task-6-report.md`.

Claimed evidence:

```text
RED: stale graphify-out appeared as a project
GREEN: PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
PowerShell parse: 8 files PASS
```

Constraints: do not delete or modify the external stale cache; no project,
secret, Git, API, deployment, migration, payment, or subdelegation changes.
