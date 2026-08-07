# Task 1: Create the Control Center

**Files:**
- Create: `BRIEF.md`
- Create: `STACK.md`
- Create: `MEMORIA.md`
- Create: `AGENDA.md`
- Create: `AGENTS.md`
- Create: `tasks.md`
- Create: `config/contexto.json`
- Test: PowerShell file and JSON validation commands

**Interfaces:**
- `config/contexto.json` is the shared configuration consumed by every script.
- `BRIEF.md`, `STACK.md`, `MEMORIA.md`, and `AGENDA.md` are Markdown sources read by Cronos.
- `AGENTS.md` is the local entry point read when OpenCode opens the control center.

## Requirements

Create `config/contexto.json` with these exact keys and default paths:

```json
{
  "projectsRoot": "F:/Proyectos",
  "controlCenter": "F:/Proyectos/Analista",
  "indexPath": "F:/Proyectos/Analista/INDICE-PROYECTOS.md",
  "statusPath": "F:/Proyectos/Analista/state/context-status.json",
  "graphifyOutput": "F:/Proyectos/Analista/graphify-out",
  "ignoredDirectoryNames": [
    ".git",
    "node_modules",
    "dist",
    "build",
    "coverage",
    ".next",
    ".nuxt",
    ".cache",
    "graphify-out"
  ],
  "ignoredFilePatterns": [
    ".env",
    ".env.*",
    "*.pem",
    "*.key",
    "*.p12",
    "*.pfx",
    "*credentials*",
    "*secret*"
  ],
  "knownDocumentNames": [
    "BRIEF.md",
    "STACK.md",
    "tasks.md",
    "README.md"
  ]
}
```

Create `BRIEF.md` with the approved purpose: Cronos is a chat-based expert web-project analyst for one user, not a standalone application; it reads `F:\Proyectos`, maintains context in the control center, and does not alter project code during context refresh.

Create `STACK.md` with this candidate classification and stack:

```markdown
# Stack del centro de control

Nivel candidato: 1 — automatización local y asistencia documental
Lenguaje de automatización: PowerShell 5.1
Formato de datos: Markdown y JSON
Análisis de relaciones: Graphify 0.9.32
Programación periódica: Windows Task Scheduler
Base de datos: ninguna
Frontend: ninguno
Testing: smoke tests de PowerShell y verificaciones de salida
Secretos: ninguno requerido
Modelo semántico externo: desactivado por defecto
Despliegue: no aplica
```

Create `MEMORIA.md` with sections for user preferences, confirmed rules, durable decisions, and lessons. State that active work items belong only in `AGENDA.md` and that secrets never belong in memory.

Create `AGENDA.md` with an empty table using `pendiente`, `en progreso`, `revisión`, and `completada` as the only statuses.

Create `AGENTS.md` with these operational rules:

```markdown
# Cronos Analista

Antes de responder, leer `BRIEF.md`, `STACK.md`, `MEMORIA.md`, `AGENDA.md` e `INDICE-PROYECTOS.md` cuando existan.

Si la pregunta no identifica un proyecto, preguntar cuál debe usarse antes de leer contexto específico.

Ejecutar la actualización de índice antes de una consulta que dependa de cambios recientes.

Registrar solo preferencias, decisiones, lecciones y reglas durables. Los pendientes activos viven en `AGENDA.md`.

No modificar código ni documentación de los proyectos durante una actualización de contexto.

Distinguir hechos verificados, inferencias, supuestos y recomendaciones. Citar rutas de archivos cuando respalden una respuesta.
```

Create `tasks.md` with the six implementation tasks from the plan and state `pendiente` for each. This ledger is for the control-center setup, not individual projects.

Run from `F:\Proyectos\Analista`:

```powershell
$required = @('BRIEF.md','STACK.md','MEMORIA.md','AGENDA.md','AGENTS.md','tasks.md','config/contexto.json')
$missing = $required | Where-Object { -not (Test-Path -LiteralPath $_) }
if ($missing) { throw "Missing control-center files: $($missing -join ', ')" }
$config = Get-Content -LiteralPath 'config/contexto.json' -Raw | ConvertFrom-Json
if ($config.projectsRoot -ne 'F:/Proyectos') { throw 'Unexpected projectsRoot' }
if ($config.controlCenter -ne 'F:/Proyectos/Analista') { throw 'Unexpected controlCenter' }
Write-Output 'PASS: control-center base'
```

The current recommendation is Nivel 1 because this is local documentation and automation without a deployed application. Do not create automation scripts in this task; the controller will show `STACK.md` and wait for the mandatory classification checkpoint after review.

## Constraints

- Work only in `F:\Proyectos\Analista` and assigned files.
- Do not modify user projects, Git, secrets, credentials, deployments, migrations, or paid services.
- Do not create a new skill or delegate further.
- Do not commit; this directory is not a Git repository.
- Use ASCII where practical, preserve the project's Spanish language, and do not add unnecessary dependencies.
- Run the validation command above and report its real output.

## Report

Write the detailed report to `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-1-report.md`. Include files changed, validation command/output, self-review, concerns, and status. Return only the short SDD status contract after writing the report.
