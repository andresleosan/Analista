# Task 3: Document Memory, Agenda, and Session Operations

**Files:**
- Create: `docs/runbook-contexto.md`
- Modify: `AGENTS.md`
- Modify: `MEMORIA.md`
- Modify: `AGENDA.md`

**Interfaces:**
- The runbook defines commands Cronos uses at session start and before a project-specific answer.
- `MEMORIA.md` stores durable knowledge only.
- `AGENDA.md` is the sole source of active work items.

## Required implementation

Create `docs/runbook-contexto.md` documenting this session procedure:

```powershell
Test-Path -LiteralPath 'F:\Proyectos'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\actualizar-indice.ps1'
```

The runbook must instruct Cronos to read the control-center files, ask for a project when one is not named, inspect only relevant project documentation, cite source paths, and record durable results after the answer. It must distinguish session refresh from the later scheduled Graphify task and state that Graphify failure does not invalidate the index.

Add this exact memory entry format to `MEMORIA.md`:

```markdown
## [fecha AAAA-MM-DD] — [título]

Proyecto: [nombre o transversal]
Tipo: preferencia | decisión | lección | regla
Hecho: [información durable confirmada]
Aplicación futura: [cómo debe cambiar una respuesta futura]
Fuente: [ruta o conversación]
Estado: vigente | reemplazada
```

State that every bracketed field must be replaced with real values in an actual entry, and that the template itself is not a memory entry. Preserve the existing rules that active work belongs in `AGENDA.md` and secrets never belong in memory.

Add this exact agenda table to `AGENDA.md` without inventing any due date:

```markdown
| ID | Proyecto | Pendiente | Próximo paso | Prioridad | Estado | Fecha objetivo |
|---|---|---|---|---|---|---|
```

Use `sin fecha` when a date is not supplied. Preserve the four allowed statuses.

Ensure `AGENTS.md`, `MEMORIA.md`, `AGENDA.md`, and the runbook state the same project-selection rule, the same memory boundary, and the same no-secret rule. Resolve any conflict before reporting.

## Constraints

- Work only in `F:\Proyectos\Analista` and assigned files.
- Do not modify projects, code, credentials, Git, deployments, migrations, paid services, or skills.
- Do not delegate or subdelegate.
- Do not commit; no Git repository exists.
- This task is documentation/configuration; no production code or tests are required.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-3-report.md`. Include files, consistency checks, self-review, concerns, and status. Return only the short SDD status contract after writing it.
