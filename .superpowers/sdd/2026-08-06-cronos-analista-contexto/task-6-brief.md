# Task 6: Complete Verification and Security Review

**Files:**
- Modify: `tasks.md`
- Modify: `docs/runbook-contexto.md`
- Review: all files created by Tasks 1-5

## Required verification

Run the complete evidence set from the control center:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
```

All commands must exit `0` and output must be free of unexpected warnings. Run a PowerShell parse check for every script under `scripts` and `tests`.

Run a controlled real session refresh against `F:\Proyectos`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/actualizar-contexto.ps1' -Mode Session
```

The real refresh may write only the control center and the approved
`F:\Proyectos\.graphifyignore`. It must not register a scheduled task or modify
any project.

Capture before/after file fingerprints for `F:\Proyectos\hachi-greciaspa` and
assert they are equal. Verify the real index lists the 17 current independent
project roots and excludes the `Analista` control center,
the Graphify status is code-only, and the graph source paths do not include
`Analista`, `.env`, `node_modules`, build output, or secret markers.

If `graphify-out/graph.json` exists, run:

```powershell
```

Record the actual result. Do not claim graph health without command evidence.

Security baseline over newly written files:

- No endpoints or public services exist.
- No hardcoded credentials, API keys, tokens, private keys, or sensitive values exist.
- Logs and console output contain no project content or environment values.
- Inputs are constrained by path validation, ValidateSet, ParseExact, and argument arrays.
- No new dependency or external integration is enabled in scheduled mode.
- The center is not a Git repository, so history and `.gitignore` checks are recorded as not applicable; no secrets are present in the generated files.
- The shared `.graphifyignore` excludes generated and secret paths.

After evidence is complete, update `tasks.md` states for Tasks 1-5 to `revisión` with the verification command and result references. Keep Task 6 `en progreso` until Cronos accepts the final review. Add the actual command outputs and UTC timestamp to `docs/runbook-contexto.md`, without recording secrets or project contents.

## Constraints

- Do not register or remove a real scheduled task.
- Do not modify project code or documentation.
- Do not read secret file contents.
- Do not use Git, commits, deployments, migrations, paid APIs, or new skills.
- A critical security finding blocks completion.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-6-report.md`. Include every command and real output, security findings, immutability evidence, Graphify diagnosis, task-state changes, self-review, and final status. Return only the short SDD status contract after writing it.
