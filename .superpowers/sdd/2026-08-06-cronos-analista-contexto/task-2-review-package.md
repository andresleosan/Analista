# Review package — Task 2

Plan: `docs/superpowers/plans/2026-08-06-cronos-analista-contexto.md`
Task brief: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-brief.md`
Implementer report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-report.md`

This checkout is not a Git repository. There are no BASE/HEAD commits and no
Git diff. Review the listed files as the complete Task 2 change set. Do not
crawl other project directories.

## Changed files

- `scripts/actualizar-indice.ps1`
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- `INDICE-PROYECTOS.md`
- `state/context-status.json`

## Verification claimed by implementer

TDD RED: test failed because `scripts/actualizar-indice.ps1` did not exist.
TDD GREEN: `PASS: project index smoke test`, exit code `0`.
Additional checks: PowerShell 5.1 parse errors `0`, temporary output files absent,
invalid root/output parent exit codes `1`.

## Binding global constraints

- Work only in `F:\Proyectos\Analista` and assigned files.
- Do not modify projects, secrets, credentials, Git, deployments, migrations, paid services, or global skills.
- Keep PowerShell 5.1 compatibility.
- The index must exclude `.git`, `node_modules`, build output, caches, secret patterns, and generated Graphify output.
- The index must not read project file contents while calculating freshness.
- Atomic output failures must preserve the previous index and remove only temporary files.
- No commits exist because this directory is not a Git repository.
