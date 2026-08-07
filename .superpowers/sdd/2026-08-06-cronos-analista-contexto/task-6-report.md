# Task 6: Complete Verification and Security Review

Revision UTC: `2026-08-07T18:07:44.2563586Z`

## Status

`en progreso` y no aceptada para cierre.

No se encontro un hallazgo critico de seguridad en los archivos del centro. Task 6 queda pendiente por dos decisiones/evidencias operativas:

- El filesystem tiene 17 proyectos independientes. `Analista` es el centro de control y no se cuenta; no se agrego una fila inventada.
- El diagnostico Graphify sigue reportando warning de integridad. Requiere aceptacion explicita del operador.

El fix de aislamiento de Graphify fue verificado: el proceso hijo fuerza `GRAPHIFY_OUT` a `F:\Proyectos\Analista\graphify-out`. El cache viejo `F:\Proyectos\graphify-out\cache\stat-index.json` no se borro ni se modifico; su timestamp permanecio intacto antes y despues del fix y del refresco real.

## Alcance y restricciones

Se revisaron los archivos creados por Tasks 1-5: configuraciones JSON, scripts PowerShell, smoke tests, documentacion, indice, estados, log y `.graphifyignore`. No se leyo contenido de archivos secretos ni contenido de proyectos. Las inspecciones de `F:\Proyectos\hachi-greciaspa` se limitaron a rutas y metadata. No se uso Git, no se hicieron commits, despliegues, migraciones, APIs pagas, registro/eliminacion real de tareas ni subdelegacion.

## Decisiones verificadas

- `F:\Proyectos\Analista` es el centro de control y se excluye del indice.
- La cantidad real de proyectos independientes es 17.
- `graphify-out` es una raiz generada, no un proyecto; el indexador la excluye por `ignoredDirectoryNames`.
- `F:\Proyectos\.graphifyignore` contiene `graphify-out/` y las reglas de secretos/generados.
- El cache externo stale permanece intacto por instruccion del operador.

## Verificacion de fixes

Comandos/validaciones ejecutados:

```text
graphify 0.9.32
True
PASS: control-center base
FIX_GRAPHIFY_OUT_PROCESS_ISOLATION=True
FIX_INDEX_DIRECT_GRAPHIFY_ROOT_EXCLUSION=True
GRAPHIFYIGNORE_GRAPHIFY_OUT_LINE=True
GRAPHIFYIGNORE_LINES=18
POST_FIX_STATIC_CHECK: PASS
```

La validacion estatica comprobo que `actualizar-graphify.ps1` guarda y restaura `GRAPHIFY_OUT` alrededor del proceso hijo, que `actualizar-indice.ps1` aplica `ignoredDirectoryNames` a las raices directas y que el `.graphifyignore` compartido contiene `graphify-out/`.

## Parse check

Se uso el parser de PowerShell 5.1 sobre todos los `*.ps1` recursivamente bajo `scripts` y `tests`.

Salida real:

```text
PASS: scripts\actualizar-contexto.ps1
PASS: scripts\actualizar-graphify.ps1
PASS: scripts\actualizar-indice.ps1
PASS: scripts\eliminar-tarea-contexto.ps1
PASS: scripts\registrar-tarea-contexto.ps1
PASS: tests\Invoke-ActualizarIndiceSmokeTest.ps1
PASS: tests\Invoke-ContextRefreshSmokeTest.ps1
PASS: tests\Invoke-GraphifySafetySmokeTest.ps1
Parsed scripts: 8
```

Exit code: `0`.

## Smoke tests y WhatIf

Comandos:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
```

Salidas reales:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
TaskName: Cronos-Actualizar-Contexto
Trigger: Weekly Sunday at 03:00
Principal: current user (InteractiveToken, limited, no stored credentials)
Action: powershell.exe -NoProfile -ExecutionPolicy Bypass -File "F:\Proyectos\Analista\scripts\actualizar-contexto.ps1" -Mode Scheduled
WhatIf: scheduled task was not registered.
not-found: Cronos-Actualizar-Contexto
```

La identidad concreta del usuario del output de `Principal` se omite para no registrar datos de identidad. No se registro ni elimino una tarea real.

## Seguridad baseline

La auditoria se ejecuto sobre los archivos del centro, scripts, tests, configuraciones y documentacion asignada.

Salida real:

```text
SECURITY_SCANNED_CENTER_FILES=20
SECURITY_PUBLIC_ENDPOINT_PATTERNS=0
SECURITY_HARDCODED_SECRET_ASSIGNMENT_PATTERNS=0
SECURITY_LOG_FORMAT_PASS=True
SECURITY_INPUT_VALIDATION_PASS=True
SECURITY_ARGUMENT_ARRAYS_PASS=True
SECURITY_GIT_REPOSITORY_PRESENT=False
SECURITY_GITIGNORE_PRESENT=False
SECURITY_PACKAGE_JSON_PRESENT=False
SECURITY_SECRET_NAMED_FILES_IN_CENTER=0
SECURITY_GRAPHIFYIGNORE_HAS_GENERATED_AND_SECRET_RULES=True
SECURITY_BASELINE_POST_FIX: PASS_WITH_GIT_NOT_APPLICABLE
```

No se observaron endpoints publicos, credenciales hardcodeadas, valores de entorno en logs, archivos sensibles generados ni dependencias nuevas. `ValidateSet`, `ParseExact`, `GetFullPath` y arrays de argumentos fueron verificados. El centro no es un repositorio Git; historial y `.gitignore` son no aplicables.

## Fingerprints y refresco real

El primer intento de wrapper con limite de 300 segundos no alcanzo a emitir el resultado final:

```text
REAL_REFRESH_BEFORE_HACHI files=111145 sha256=69dbd748ffc816eaf576c0c09184a5c0dae991be800fb9ff77a9b76c1ded0142
REAL_REFRESH_BEFORE_CACHE exists=True length=610634 createdUtc=2026-08-07T16:53:37.6616214Z lastWriteUtc=2026-08-07T16:53:37.6656370Z
shell tool terminated command after exceeding timeout 300000 ms
```

Se verificaron los estados sin tocar proyectos ni cache. El refresco real posterior con limite de 15 minutos uso el comando exigido:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/actualizar-contexto.ps1' -Mode Session
```

Antes del wrapper se obtuvo estabilidad de cinco segundos:

```text
HACHI_STABILITY_BEFORE_FIRST files=111144 sha256=f15747a03c19995632878264ca58d8ae541693fc989d0d84163e43adaae9144f
HACHI_STABILITY_BEFORE_SECOND files=111144 sha256=f15747a03c19995632878264ca58d8ae541693fc989d0d84163e43adaae9144f
HACHI_STABILITY_BEFORE: PASS
```

La corrida real post-fix produjo:

```text
REAL_REFRESH_POST_FIX_STARTED_UTC=2026-08-07T18:00:13.7571343Z
REAL_REFRESH_BEFORE_HACHI files=111144 sha256=f48747a03c19995632878264ca58d8ae541693fc989d0d84163e43adaae9144f
REAL_REFRESH_BEFORE_CACHE exists=True length=610634 createdUtc=2026-08-07T16:53:37.6616214Z lastWriteUtc=2026-08-07T16:53:37.6656370Z
REAL_REFRESH_CACHE_TIMESTAMP_MATCHES_PRIOR_EVIDENCE=True
REAL_REFRESH_SESSION_EXIT_CODE: 0
REAL_REFRESH_POST_FIX_COMPLETED_UTC=2026-08-07T18:05:34.0749463Z
REAL_REFRESH_AFTER_HACHI files=111145 sha256=078b12f6badb57993bff0625364f2cedc54c94d2b0b4378ee89857db094ae4a1
REAL_REFRESH_AFTER_CACHE exists=True length=610634 createdUtc=2026-08-07T16:53:37.6616214Z lastWriteUtc=2026-08-07T16:53:37.6656370Z
HACHI_IMMUTABILITY_POST_FIX=False
STALE_CACHE_TIMESTAMP_UNCHANGED_POST_FIX=True
```

El estado generado confirmo:

```text
startedAtUtc=2026-08-07T18:00:42.9264451Z
completedAtUtc=2026-08-07T18:05:18.3429475Z
indexExitCode=0
graphifyExitCode=0
exitCode=0
```

El log completo posterior contiene solo timestamp, modo y codigos:

```text
2026-08-07T16:47:10.4640084Z|Session|0|0
2026-08-07T16:53:37.8183292Z|Session|0|0
2026-08-07T17:22:15.5534728Z|Session|0|0
2026-08-07T17:46:58.9758530Z|Session|0|0
2026-08-07T18:05:18.3429475Z|Session|0|0
```

La igualdad de `hachi-greciaspa` no se puede afirmar porque se detectaron 27 cambios de metadata dentro de la ventana. Se listan solo rutas y metadata, nunca contenido:

```text
Dev\functions\src\email\resend.test.ts
Dev\functions\src\email\resend.ts
Dev\functions\lib\assignment.js
Dev\functions\lib\assignment.test.js
Dev\functions\lib\employeeRepository.js
Dev\functions\lib\assignmentService.js
Dev\functions\lib\assignmentService.test.js
Dev\functions\lib\types.js
Dev\functions\lib\templates\html.js
Dev\functions\lib\templates\confirmation.js
Dev\functions\lib\templates\reminder.js
Dev\functions\lib\email\resend.js
Dev\functions\lib\reminders.js
Dev\functions\lib\confirmations.js
Dev\functions\lib\confirmations.test.js
Dev\functions\lib\scheduledSendReminders.js
Dev\functions\lib\emulator-reminder.test.js
Dev\functions\lib\rescheduleReserva.js
Dev\functions\lib\onReservaConfirmationCreated.js
Dev\functions\lib\index.js
Dev\functions\lib\onReservaConfirmationCreated.test.js
Dev\functions\lib\reminders.test.js
Dev\functions\lib\rescheduleReserva.test.js
Dev\functions\lib\scheduledSendReminders.test.js
Dev\functions\lib\email\resend.test.js
Dev\functions\src\timeZone.test.ts
Dev\node_modules\.vite\vitest\da39a3ee5e6b4b0d3255bfef95601890afd80709\results.json
```

La actividad concurrente explica el cambio de fingerprint observado; el emisor no fue identificado. No se ejecutaron comandos de escritura sobre proyectos desde esta verificacion.

## Indice real

La verificacion cuenta filas de datos y excluye `Analista` y `graphify-out` como raices no proyectuales:

```text
INDEX_DATA_ROWS=17
CURRENT_INDEPENDENT_PROJECT_ROOTS=17
INDEX_HAS_ANALISTA_ROW=False
INDEX_HAS_GRAPHIFY_OUT_ROW=False
INDEX_MISSING_ROOTS=0
INDEX_EXTRA_ROWS=0
INDEX_17_PROJECTS: PASS
```

Los 17 nombres son: `BPT Jersey`, `Coctelsops-F--main`, `donaciones-venezuela`, `donaciones-venezuela(Andres)`, `Fullstack-Challenge---E-commerce`, `hachi-greciaspa`, `la-parada`, `mercado-inteligente`, `Mundo_Celular`, `Peludos Al Poder`, `performai`, `PintuMaster`, `Primer Proyecto 14-11`, `Santel`, `SurtiFacil`, `tecnifullgas` y `Titan-Monitor`.

## Graphify code-only y rutas

Estado real de `state/graphify-status.json`:

```text
GRAPHIFY_STATUS mode=Scheduled semanticMode=code-only exitCode=0
GRAPHIFY_STATUS_COMMAND=graphify extract "F:\Proyectos" --out "F:\Proyectos\Analista" --code-only --no-cluster
```

Comprobacion de `graphify-out/graph.json`:

```text
GRAPH_JSON_NODES=8583
GRAPH_JSON_EDGES=18235
GRAPH_SOURCE_VALUES=1402
GRAPH_SOURCE_ANALISTA_VIOLATIONS=0
GRAPH_SOURCE_ENV_VIOLATIONS=0
GRAPH_SOURCE_NODEMODULES_VIOLATIONS=0
GRAPH_SOURCE_BUILDOUTPUT_VIOLATIONS=0
GRAPH_SOURCE_SECRETMARKERS_VIOLATIONS=0
GRAPH_SOURCE_GRAPHIFYOUT_VIOLATIONS=0
GRAPH_SOURCE_PLAYWRIGHT_BROWSER_PATHS=9
GRAPH_SOURCE_FORBIDDEN_MARKERS_ALL_ZERO=True
GRAPHIFY_CODE_ONLY_AND_SOURCE_EXCLUSIONS: PASS
```

Se observaron 9 rutas `.playwright-browsers`, una preocupacion no bloqueante de calidad del corpus porque no forma parte de la lista aprobada de exclusiones.

Diagnostico valido:

```powershell
graphify diagnose multigraph --graph 'graphify-out/graph.json'
```

Salida relevante real:

```text
nodes: 8583
unverified_code_nodes: 0
raw_edges: 18235
valid_candidate_edges: 16176
missing_endpoint_edges: 0
self_loop_edges: 26
post_build_edges: 15947
producer_suppression_sites: 11
```

No se declara salud del grafo. El warning de integridad queda pendiente de aceptacion explicita del operador.

## `.graphifyignore`

Comprobacion exacta:

```text
GRAPHIFYIGNORE_LINES=18
GRAPHIFYIGNORE_FINAL: PASS
```

La lista final contiene `Analista/`, `graphify-out/`, las exclusiones de `.git`, dependencias/build output y los marcadores `.env`, `pem`, `key`, `p12`, `pfx`, `credentials` y `secret`.

## Consistencia documental y estado

La comparacion literal de las reglas de seleccion de proyecto, memoria durable y no secretos en `AGENTS.md`, `MEMORIA.md`, `AGENDA.md` y `docs/runbook-contexto.md` produjo:

```text
TASK3_DOCUMENT_CONSISTENCY_POST_EDIT: PASS
```

`tasks.md` conserva Tasks 1-5 en `revisión` y Task 6 en `en progreso`, con referencias concisas a la evidencia post-fix.

## Autocritica final

### Seguridad

PASS sin hallazgos criticos en los archivos del centro.

### Inmutabilidad

El cache externo permanecio intacto. La igualdad del fingerprint de `hachi-greciaspa` queda inconclusa por actividad concurrente observable durante la ventana; no se fuerza un PASS.

### Indice

PASS para la regla real de 17 proyectos independientes, sin contar `Analista` ni `graphify-out` y sin inventar filas.

### Graphify

PASS en aislamiento de salida, modo `code-only` y exclusiones de rutas prohibidas. Warning abierto por `2059` aristas colgantes, `26` self-loops y `203` grupos de endpoints colapsados.

## Conclusion

En ese snapshot Task 6 permanecia `en progreso` porque faltaban las confirmaciones del operador. Esas confirmaciones ya fueron recibidas; queda la revision final de Cronos.

Commits: `none (no Git repository)`.

## Task 6 - Override safety fix

Revision UTC: `2026-08-07T18:42:55.6418226Z`

### Estado

Implementacion terminada y verificada. No se modificaron proyectos objetivo ni el cache externo.

### Causa raiz

- `actualizar-indice.ps1` aceptaba `OutputPath` y `StatusPath` sin comprobar que sus directorios padre estuvieran dentro de `ControlCenterPath`.
- `actualizar-graphify.ps1` y `actualizar-contexto.ps1` aceptaban un `ControlCenterPath` arbitrario dentro de `projectsRoot`, incluyendo una raiz de proyecto.
- Las validaciones nuevas normalizan con `GetFullPath`, comparan sin distinguir mayusculas y exigen el separador de raiz para evitar coincidencias por prefijo.

### TDD RED

Se agregaron primero las regresiones y se ejecutaron antes de la validacion de produccion:

```text
Invoke-ActualizarIndiceSmokeTest.ps1: Assertion failed: OutputPath outside the control center should be rejected
Invoke-GraphifySafetySmokeTest.ps1: Assertion failed: a project directory must not be used as the Graphify output root
Invoke-ContextRefreshSmokeTest.ps1: Assertion failed: a project directory must not be used as the context output root
```

Los fallos fueron los esperados: los tres overrides inseguros aun eran aceptados.

### GREEN

Comandos ejecutados:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-ActualizarIndiceSmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-GraphifySafetySmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-ContextRefreshSmokeTest.ps1'
```

Salida real final:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
```

Las regresiones usan un root temporal sin archivos para el indexer y `-WhatIf` para Graphify/contexto. Los defaults reales y los fixtures temporales existentes siguen pasando.

### Parse check

El parser de PowerShell 5.1 verifico los seis archivos asignados:

```text
PASS: scripts\actualizar-indice.ps1
PASS: scripts\actualizar-graphify.ps1
PASS: scripts\actualizar-contexto.ps1
PASS: tests\Invoke-ActualizarIndiceSmokeTest.ps1
PASS: tests\Invoke-GraphifySafetySmokeTest.ps1
PASS: tests\Invoke-ContextRefreshSmokeTest.ps1
Parsed assigned files: 6
```

### Seguridad

- El indexer rechaza ambos destinos antes de crear sus directorios padres o leer el estado previo.
- Graphify y el orquestador rechazan una ruta dentro de `F:\Proyectos` salvo `F:\Proyectos\Analista`, antes de crear directorios o ejecutar procesos hijos.
- Los errores incluyen la ruta rechazada y explican que la salida debe permanecer dentro del centro de control o igualar el centro configurado.
- No se detectaron endpoints, secretos, ejecucion dinamica, dependencias nuevas ni hallazgos criticos.

### Archivos modificados

- `scripts/actualizar-indice.ps1`
- `scripts/actualizar-graphify.ps1`
- `scripts/actualizar-contexto.ps1`
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- `tests/Invoke-GraphifySafetySmokeTest.ps1`
- `tests/Invoke-ContextRefreshSmokeTest.ps1`
- Este informe.

### Preocupaciones

No quedan preocupaciones nuevas bloqueantes para este fix. Las decisiones operativas y el warning de integridad Graphify descritos anteriormente en este informe permanecen visibles y aceptados como limitacion no bloqueante.

## Cierre post-confirmacion y verificacion fresca

El operador confirmo que `Analista` es el centro de control, que existen 17 proyectos independientes y que el warning de integridad Graphify no bloquea el uso del mapa mientras se informe explicitamente.

Se elimino unicamente `F:\Proyectos\graphify-out\cache\stat-index.json`, cache generado por el intento anterior. Verificacion posterior:

```text
STALE_CACHE_EXISTS=False
```

El directorio padre vacio se conserva sin contenido. No se eliminaron archivos de ningun proyecto.

Verificacion fresca despues de la correccion de overrides:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
Parsed scripts: 8
```

La re-revision de seguridad de overrides quedo limpia: los destinos bajo una
raiz de proyecto son rechazados, los fixtures temporales siguen permitidos y
los defaults no cambian.

El refresco real posterior termino con `indexExitCode=0`, `graphifyExitCode=0` y
`semanticMode=code-only`; el indice contiene 17 proyectos independientes y no
incluye `Analista` ni `graphify-out`. El diagnostico Graphify continua mostrando
aristas colgantes, self-loops y colapsos de endpoints; no se declara salud total
del grafo, conforme a la aceptacion del operador.

## Estado final sujeto a revision

Tasks 1-5 permanecen en `revision` con evidencia. Task 6 queda en `en progreso`
hasta la revision whole-branch final de Cronos.

## Task 6 - Final security fixes: output root and corpus exclusions

Revision: `2026-08-07`

### Estado

Implementacion terminada y verificada. No se modificaron contenidos de proyectos
reales, no se ejecuto Graphify contra proyectos reales y no se uso Git.

### Causa raiz

- `scripts/actualizar-indice.ps1` validaba los padres de `OutputPath` y `StatusPath`,
  pero aceptaba un `ControlCenterPath` alternativo dentro de la raiz configurada de
  proyectos. Eso podia dirigir el estado y el indice hacia un proyecto real.
- `config/contexto.json` no excluia `.firebase-config` ni `.playwright-browsers` del
  indice.
- `F:\Proyectos\.graphifyignore` tampoco excluia esas carpetas del corpus Graphify.

### TDD RED

Las regresiones se escribieron antes del cambio de produccion y fallaron contra el
codigo anterior:

```text
Invoke-ActualizarIndiceSmokeTest.ps1: Assertion failed: the index error should identify the rejected control center
Invoke-GraphifySafetySmokeTest.ps1: TEST FAILURE: Assertion failed: shared root ignore should exclude Firebase configuration
```

La regresion del indexer usa `ControlCenterPath=F:\Proyectos\hachi-greciaspa` y
destinos con nombres validos bajo esa ruta. Para mantener el RED sin riesgo de
escritura, `ProjectsRoot` apunta a un archivo temporal en vez de un directorio;
el caso temporal de control center existente sigue siendo valido y separado.

### Cambios minimos

- `actualizar-indice.ps1` compara el control center solicitado con las rutas
  configuradas, antes de crear directorios de salida, y rechaza rutas bajo la raiz
  de proyectos que no sean el centro configurado.
- `contexto.json` agrega `.firebase-config` y `.playwright-browsers` a
  `ignoredDirectoryNames`.
- El fixture del indexer contiene archivos `README.md` bajo ambas carpetas y
  verifica que no aparezcan en la salida.
- El ignore compartido y el fixture Graphify agregan
  `**/.firebase-config/` y `**/.playwright-browsers/`.
- El fixture Graphify contiene `firebase-tools.json` y `browser-cache.json` con el
  marcador `secret-value`; la salida verifica que no aparezcan rutas ni valores.

### GREEN

Comandos ejecutados en una corrida fresca:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-ActualizarIndiceSmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-GraphifySafetySmokeTest.ps1'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests\Invoke-ContextRefreshSmokeTest.ps1'
```

Salida real:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
```

### Parse check

El parser de PowerShell 5.1 verifico los ocho scripts bajo `scripts` y `tests`:

```text
PASS: scripts\registrar-tarea-contexto.ps1
PASS: scripts\eliminar-tarea-contexto.ps1
PASS: scripts\actualizar-indice.ps1
PASS: scripts\actualizar-graphify.ps1
PASS: scripts\actualizar-contexto.ps1
PASS: tests\Invoke-GraphifySafetySmokeTest.ps1
PASS: tests\Invoke-ContextRefreshSmokeTest.ps1
PASS: tests\Invoke-ActualizarIndiceSmokeTest.ps1
Parsed scripts: 8
```

Validacion adicional:

```text
PASS: context JSON and shared Graphify exclusions
```

### Seguridad y preocupaciones

- La validacion del control center ocurre antes de crear padres de salida o leer el
  estado previo.
- No se agregaron endpoints, dependencias, ejecucion dinamica ni credenciales.
- `secret-value` existe solo como marcador de fixture temporal para probar la
  exclusion del corpus; no es una credencial.
- No se ejecuto Graphify contra proyectos reales por la restriccion explicita del
  brief, por lo que no se afirma una verificacion del corpus real en esta tarea.
- El warning historico de integridad de Graphify permanece fuera del alcance de
  este fix y no fue reevaluado.

### Archivos modificados

- `config/contexto.json`
- `scripts/actualizar-indice.ps1`
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- `tests/Invoke-GraphifySafetySmokeTest.ps1`
- `F:\Proyectos\.graphifyignore`
- Este informe.

Commits: `none (no Git repository)`.

## Cierre final de seguridad

Revision final: `2026-08-07`

Se corrigieron las brechas detectadas durante la whole-branch review:

- Las tres entradas rechazan reparse points en `ProjectsRoot`, `ControlCenterPath`,
  rutas derivadas, temporales atomicos y, cuando corresponde, descendientes del
  corpus o de `graphify-out`.
- El indexador ya no crea `ProjectsRoot` antes de validar las rutas de salida y
  enumera proyectos sin atravesar reparse points no ignorados.
- Graphify valida `state`, `graphify-out` existente y el corpus antes de `WhatIf` o
  de invocar el ejecutable; la extraccion programada sigue siendo `code-only`.
- Los cleanups de fixtures desvinculan junctions explicitamente y los cleanups de
  temporales no intentan borrar un reparse point potencialmente externo.

Verificacion fresca posterior a estos cambios:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
Parsed scripts: 8
```

La revision independiente final no encontro hallazgos bloqueantes ni importantes.
Persisten como riesgos residuales no bloqueantes la ventana TOCTOU entre validacion
y escritura y la posibilidad de que un error de permisos haga que una ruta parezca
inexistente. No se ejecuto Graphify contra proyectos reales, no se modificaron
archivos de proyectos y no se uso Git.

Archivos modificados en esta revision final:

- `config/graphify.json`
- `scripts/actualizar-indice.ps1`
- `scripts/actualizar-contexto.ps1`
- `scripts/actualizar-graphify.ps1`
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- `tests/Invoke-ContextRefreshSmokeTest.ps1`
- `tests/Invoke-GraphifySafetySmokeTest.ps1`
- `F:\Proyectos\.graphifyignore`
- Este informe.
