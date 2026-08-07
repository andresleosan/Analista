# Scoped re-review package — Task 2 fix round 1

Plan: `docs/superpowers/plans/2026-08-06-cronos-analista-contexto.md`
Brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-brief.md`
Report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-report.md`

The original task review found one Important issue:

`Write-ProjectOutputs` replaced `OutputPath` before `StatusPath`; if the second
move failed, the prior Markdown was not restored. The fix must preserve both
previous destinations and restore them after a failure at the second move.

This checkout has no Git repository. Review only the fix-related portions of:

- `scripts/actualizar-indice.ps1`, especially `Remove-TransactionPath`,
  `Move-TransactionItem`, and `Write-ProjectOutputs`.
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`, especially the locked-status
  regression.
- The addendum in `task-2-report.md` containing RED/GREEN evidence.

Claimed fix behavior:

- Create unique backups for both existing outputs.
- Move both temporary outputs.
- Restore both prior outputs if either move fails.
- Remove backups only after both moves succeed.
- Remove temporary files after the failing handle is released.

Claimed tests:

```text
RED: Assertion failed: the previous Markdown should be restored
GREEN: PASS: project index smoke test, exit code 0
Suite: 1 test, exit code 0
PowerShell 5.1 parse errors: 0
```

Global constraints: no project modifications, no secrets, no Git, no commits,
PowerShell 5.1 compatibility, no new public test interface, and no scope beyond
the atomic-output fix.
