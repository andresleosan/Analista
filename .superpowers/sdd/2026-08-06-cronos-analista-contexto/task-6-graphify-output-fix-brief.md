# Task 6 fix: keep Graphify cache inside the control center

## Root cause evidence

The real Session refresh used:

```text
graphify extract "F:\Proyectos" --out "F:\Proyectos\Analista" --code-only --no-cluster
```

Graphify 0.9.32 still created `F:\Proyectos\graphify-out\cache\stat-index.json`.
The installed package reads `GRAPHIFY_OUT` at process startup in
`graphify/paths.py`; an absolute value makes cache and output paths resolve to
the shared destination. The wrapper does not currently set that environment
variable for the child process.

## Assigned files

- Modify: `scripts/actualizar-graphify.ps1`
- Modify: `tests/Invoke-GraphifySafetySmokeTest.ps1`
- Append report: `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`

## Required fix

Use TDD. First add a regression to the Graphify safety smoke test that runs a
fake Graphify command through the real PowerShell wrapper and asserts that the
child receives:

```text
GRAPHIFY_OUT=<temporary control center>\graphify-out
```

The test must fail before the production fix because the marker is absent or
wrong. After the fix it must pass and the test must restore any prior
`GRAPHIFY_OUT` value in `finally`.

In `scripts/actualizar-graphify.ps1`, immediately around the real Graphify
child invocation:

1. Resolve `GRAPHIFY_OUT` to `Join-Path $controlCenterFullPath 'graphify-out'`.
2. Save the prior process environment value, if any.
3. Set the child-process environment value before calling `& $graphifyCommandPath @arguments`.
4. Restore the prior value in `finally`, or remove it if it was previously unset.
5. Do not print the environment value or put it in the status JSON.
6. Preserve existing version checks, exit codes, status writing, WhatIf behavior,
   Manual boundary, and argument arrays.

The WhatIf branch must not set or change the environment and must continue to
avoid invoking Graphify.

Run the focal Graphify safety test, the index and context smoke tests, and a
PowerShell parse check. Do not run Graphify against `F:\Proyectos` in this fix.

## Constraints

- Only the assigned files may change.
- No deletion or modification of `F:\Proyectos\graphify-out` in this task.
- No project source/documentation changes, secrets, API keys, Git, commits,
  deployments, migrations, paid services, or subdelegation.
- A critical security finding blocks.

## Report

Append RED/GREEN evidence, the root-cause conclusion, files, and concerns to
`task-6-report.md`.
