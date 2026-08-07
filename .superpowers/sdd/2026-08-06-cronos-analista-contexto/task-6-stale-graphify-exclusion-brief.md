# Task 6 fix: exclude stale Graphify output from roots and corpus

## Root cause

`Get-ProjectSnapshots` skips only `ControlCenterPath`. The stale directory
`F:\Proyectos\graphify-out` created by the earlier Graphify behavior is therefore
listed as a project, even though `graphify-out` already exists in
`ignoredDirectoryNames` for recursive file filtering.

`F:\Proyectos\.graphifyignore` also lacks a root-level `graphify-out/` entry.

## Assigned files

- Modify: `scripts/actualizar-indice.ps1`
- Modify: `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- Modify: `F:\Proyectos\.graphifyignore`
- Modify: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Append report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

## Required fix

Use TDD:

1. Add a root-level fixture directory named `graphify-out` containing a file to
   the index smoke test. Run RED against the current indexer and assert that the
   generated index does not include `graphify-out` as a project.
2. Make `Get-ProjectSnapshots` skip direct child directories whose name is in
   the configured `ignoredDirectoryNames`, case-insensitively, while preserving
   the explicit control-center exclusion.
3. Add `graphify-out/` to the shared root `.graphifyignore` and the fixture ignore
   content in the Graphify smoke test. Assert the approved root exclusion is
   present and no fixture output path is included.
4. Run GREEN for the focal index and Graphify tests, then the context smoke and
   PowerShell parse checks.

Do not delete or modify `F:\Proyectos\graphify-out\cache\stat-index.json` in this
task; it is an existing generated artifact from the earlier failed behavior.

## Constraints

- Only assigned files may change.
- No project source/documentation, secrets, API keys, Git, commits, deployments,
  migrations, paid services, or subdelegation.
- Keep PowerShell 5.1 compatibility.
- A critical security finding blocks.

## Report

Append RED/GREEN evidence, root cause, files, and concerns to
`task-6-report.md`.
