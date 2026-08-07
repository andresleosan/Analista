# Task 6 fix: final output-root and corpus exclusions

## Findings

1. `scripts/actualizar-indice.ps1` checks that outputs are inside the supplied
   `ControlCenterPath`, but does not reject a supplied control center that is a
   real project under configured `F:\Proyectos`. That can still write an index
   and state into a project.
2. The real Graphify manifest contains `.firebase-config/configstore/firebase-tools.json`.
   This directory may contain local Firebase configuration and must not enter the
   context corpus. `.playwright-browsers` is generated output and should also be
   excluded from both metadata and Graphify corpora.

## Assigned files

- Modify: `config/contexto.json`
- Modify: `scripts/actualizar-indice.ps1`
- Modify: `scripts/actualizar-graphify.ps1` only if needed for shared exclusion behavior
- Modify: `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- Modify: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Modify: `F:\Proyectos\.graphifyignore`
- Append report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

## Required fix

Use TDD:

1. Add an index regression passing `ControlCenterPath=F:\Proyectos\hachi-greciaspa`
   with outputs under that path; it must fail before any output creation. Keep
   temporary control-center fixtures valid.
2. Add `.firebase-config` and `.playwright-browsers` to
   `ignoredDirectoryNames` in `config/contexto.json` and matching fixture config;
   assert the index excludes files under both directories.
3. Add `**/.firebase-config/` and `**/.playwright-browsers/` to the shared and
   fixture `.graphifyignore`; add fixture files including a `secret-value` and
   assert Graphify output contains none of those paths or values.
4. Preserve all existing defaults, fixture behavior, Graphify isolation, and
   output-root checks.
5. Run all three smoke tests, parse all scripts, and report RED/GREEN evidence.

Do not read project contents, run Graphify against real projects, delete caches,
or use Git/API keys/paid services/deployments/migrations/subdelegation.

## Report

Append root cause, RED/GREEN evidence, files, and concerns to
`task-6-report.md`.
