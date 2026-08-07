# Runbook de contexto

Este runbook define la operación de sesión de Cronos en `F:\Proyectos\Analista`.

## Reglas compartidas

Antes de responder, leer `BRIEF.md`, `STACK.md`, `MEMORIA.md`, `AGENDA.md` e `INDICE-PROYECTOS.md` cuando existan.

Si la pregunta no identifica un proyecto, preguntar cuál debe usarse antes de leer contexto específico.

MEMORIA.md solo conserva información durable confirmada: preferencias, decisiones, lecciones y reglas; las consultas aisladas, inferencias no verificadas y pendientes activos no pertenecen a la memoria.

Los pendientes activos solo se registran en `AGENDA.md`; no se registran en `MEMORIA.md`.

Los secretos nunca pertenecen a la memoria: no registrar contraseñas, tokens, credenciales ni datos sensibles.

La actualización de contexto no modifica código ni documentación de los proyectos. Las fuentes deben citarse por su ruta cuando respalden una respuesta.

## Inicio de sesión

1. Confirmar que la raíz de proyectos existe:

   ```powershell
   Test-Path -LiteralPath 'F:\Proyectos'
   ```

   El resultado esperado es `True`. Si es `False`, detener el refresco y reportar la ruta no disponible.

2. Actualizar el índice local antes de una consulta que dependa de cambios recientes:

   ```powershell
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\actualizar-indice.ps1'
   ```

   Este comando actualiza el inventario del centro de control. No habilita cambios en código ni documentación de los proyectos.

3. Leer los archivos de control indicados en `AGENTS.md`, incluyendo el índice recién actualizado cuando exista.

4. Si la pregunta no identifica un proyecto, preguntar cuál debe usarse antes de leer contexto específico. No inferir el proyecto solo por el tema de la pregunta.

## Antes de una respuesta específica

1. Usar el proyecto que el usuario haya identificado. Inspeccionar únicamente la documentación relevante de ese proyecto, por ejemplo `BRIEF.md`, `STACK.md`, `tasks.md` o `README.md` cuando existan y sean necesarios; no recorrer código o documentación de proyectos no relacionados.
2. Separar hechos verificados, inferencias, supuestos y recomendaciones.
3. Citar las rutas de los archivos que respaldan cada hecho relevante. Una relación o inferencia auxiliar no reemplaza la fuente original.
4. Después de responder, registrar solo resultados durables confirmados en `MEMORIA.md`, con el formato definido allí. Los pendientes, próximos pasos y seguimientos se registran únicamente en `AGENDA.md`.
5. No registrar secretos, contraseñas, tokens, credenciales ni datos sensibles en ningún registro de memoria.

## Refresco de sesión y Graphify programado

El refresco de sesión y la tarea programada posterior de Graphify son operaciones distintas. El refresco de sesión ejecuta la comprobación de la raíz, actualiza el índice y permite leer directamente la documentación relevante antes de responder. No depende de que Graphify esté disponible.

La tarea programada posterior de Graphify es un proceso separado para análisis de relaciones en segundo plano. No sustituye la selección explícita del proyecto, la lectura de las fuentes originales ni el registro controlado de memoria y agenda.

Un fallo de Graphify no invalida el índice. Si Graphify falla, continuar con el índice y la lectura directa de documentación, informar la limitación si afecta la respuesta y no presentar relaciones del grafo como hechos no verificados.

### Comandos operativos

Refresco de sesión:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\actualizar-contexto.ps1' -Mode Session
```

Refresco programado:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\actualizar-contexto.ps1' -Mode Scheduled
```

Mostrar la definición de la tarea sin registrarla:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\registrar-tarea-contexto.ps1' -WhatIf -DayOfWeek Sunday -At '03:00'
```

Registrar la tarea, de forma opt-in:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\registrar-tarea-contexto.ps1' -DayOfWeek Sunday -At '03:00'
```

Eliminar la tarea:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'F:\Proyectos\Analista\scripts\eliminar-tarea-contexto.ps1'
```

El controlador no registra la tarea automáticamente. El registro cambia el comportamiento de Windows en segundo plano y requiere la ejecución explícita del script de registro sin `-WhatIf`.

## Evidencia de verificación final

Evidencia capturada en UTC: `2026-08-07T16:59:16.6641906Z`.

Los resultados siguientes contienen solo estados, rutas del centro, rutas de metadatos de proyectos y fingerprints; no contienen secretos ni contenido de proyectos.

### Comandos y resultados

```text
Test-Path -LiteralPath 'F:\Proyectos' -> True
PASS: control-center base
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
Parsed scripts: 8
PASS: scheduler -WhatIf (no se registro la tarea)
not-found: Cronos-Actualizar-Contexto
graphify 0.9.32
TASK3_DOCUMENT_CONSISTENCY: PASS
SECURITY_BASELINE_CENTER: PASS_WITH_GIT_NOT_APPLICABLE
```

El parse check cubrio `scripts\actualizar-contexto.ps1`, `scripts\actualizar-graphify.ps1`, `scripts\actualizar-indice.ps1`, `scripts\eliminar-tarea-contexto.ps1`, `scripts\registrar-tarea-contexto.ps1` y los tres smoke tests bajo `tests`; los ocho resultaron `PASS`.

### Refresco real

El comando ejecutado fue:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/actualizar-contexto.ps1' -Mode Session
```

La primera corrida termino con `SESSION_COMMAND_EXIT_CODE: 0`, pero el fingerprint de metadatos de `F:\Proyectos\hachi-greciaspa` cambio de `111116` archivos y `1daa32446582d30e552192efb5146f271fb8acf390f1d6d129f09433ae9db24d` a `111117` archivos y `2e1348b17b3b42f8b2fd8a5f7694476d5f896dc95afc30a549d467901d5dcc84`. La metadata registro la creacion de `Dev\docs\adr\ADR-005-react-router-audit-remediation.md` a las `2026-08-07T16:44:02.5237902Z`, dentro de la ventana iniciada a las `2026-08-07T16:43:01.3304455Z`. No se leyo su contenido ni se modifico el proyecto.

Luego de una medicion de estabilidad de cinco segundos (`HACHI_STABILITY: PASS`), se repitio la sesion controlada:

```text
CONTROLLED_REFRESH_BEFORE timestamp=2026-08-07T16:51:17.2446799Z files=111117 sha256=2e1348b17b3b42f8b2fd8a5f7694476d5f896dc95afc30a549d467901d5dcc84
SESSION_COMMAND_EXIT_CODE: 0
CONTROLLED_REFRESH_AFTER timestamp=2026-08-07T16:53:46.9378694Z files=111117 sha256=2e1348b17b3b42f8b2fd8a5f7694476d5f896dc95afc30a549d467901d5dcc84
HACHI_IMMUTABILITY: PASS
```

El estado generado de esa segunda corrida fue `indexExitCode=0`, `graphifyExitCode=0`, `exitCode=0`, con inicio `2026-08-07T16:51:17.6108832Z` y fin `2026-08-07T16:53:37.8183292Z`. El log solo contiene las cuatro columnas permitidas por linea y las dos lineas observadas son:

```text
2026-08-07T16:47:10.4640084Z|Session|0|0
2026-08-07T16:53:37.8183292Z|Session|0|0
```

### Indice y Graphify

La verificacion corregida de las filas de datos encontro `17` proyectos actuales y `17` filas en el indice, sin faltantes ni extras entre ambos conjuntos. El directorio adicional `F:\Proyectos\graphify-out` no es un proyecto: fue creado durante la segunda corrida, a las `2026-08-07T16:53:37.6616214Z`, y contenia el cache `cache\stat-index.json`. Este fue un hallazgo de ese snapshot historico; el cache se elimino posteriormente con confirmacion explicita del operador y el indexador ahora excluye esa raiz.

El estado Graphify real fue:

```text
mode=Scheduled semanticMode=code-only exitCode=0
command=graphify extract "F:\Proyectos" --out "F:\Proyectos\Analista" --code-only --no-cluster
GRAPHIFY_CODE_ONLY: PASS
```

`graphify-out\graph.json` genero `8540` nodos y `18109` aristas. La comprobacion de rutas fuente encontro cero rutas con `Analista`, `.env`, `node_modules`, segmentos de build (`dist`, `build`, `coverage`, `.next`, `.nuxt`, `.cache`) o marcadores de secretos. Se observaron 9 rutas bajo `.playwright-browsers`, un artefacto generado no incluido en el `.graphifyignore` aprobado; queda como preocupacion de calidad de corpus, no como hallazgo critico de seguridad.

El comando requerido se probo primero sin modo y devolvio solo su uso. La sintaxis valida ejecutada fue:

```powershell
graphify diagnose multigraph --graph 'graphify-out/graph.json'
```

Resultado relevante real: `missing_endpoint_edges=0`, `dangling_endpoint_edges=2055`, `self_loop_edges=26`, `directed_same_endpoint_collapsed_edges=203`, `post_build_edges=15825` y `producer_suppression_sites=11`. Por lo tanto no se declara salud del grafo; el diagnostico muestra advertencias de integridad que deben investigarse.

La comparacion de `F:\Proyectos\.graphifyignore` encontro las 17 lineas aprobadas exactamente:

```text
GRAPHIFYIGNORE_APPROVED: PASS
```

### Seguridad

La auditoria sobre 20 archivos del centro encontro:

```text
SECURITY_PUBLIC_ENDPOINT_PATTERNS=0
SECURITY_HARDCODED_SECRET_ASSIGNMENT_PATTERNS=0
SECURITY_LOG_FORMAT_PASS=True
SECURITY_INPUT_VALIDATION_PASS=True
SECURITY_ARGUMENT_ARRAYS_PASS=True
SECURITY_GIT_REPOSITORY_PRESENT=False
SECURITY_GITIGNORE_PRESENT=False
SECURITY_PACKAGE_JSON_PRESENT=False
SECURITY_SECRET_NAMED_FILES_IN_CENTER=0
```

El centro no es un repositorio Git, por lo que historial y `.gitignore` son no aplicables. No se registro ninguna tarea programada real: el comando de registro se ejecuto con `-WhatIf` y removal devolvio `not-found`.

## Resultado de la autocrítica

No se detecto un hallazgo critico de seguridad en los archivos del centro. En ese snapshot historico, Task 6 quedaba en progreso por el cache externo y el conteo aun no resuelto. Esos dos puntos fueron resueltos despues: `Analista` se excluye como centro de control, el conteo aceptado es 17 proyectos independientes y el cache fue eliminado con autorizacion. El diagnostico Graphify mantiene una advertencia de aristas colgantes y colapsadas, aceptada como no bloqueante. No se modifico ningun proyecto, no se uso Git, no se registraron tareas reales, no se usaron APIs pagas ni se hicieron despliegues o migraciones.

Commits: `none (no Git repository)`.

## Evidencia final post-fixes

Evidencia capturada en UTC: `2026-08-07T18:07:44.2563586Z`. Esta sección supersede los snapshots anteriores de este runbook.

### Fixes y validaciones

```text
graphify 0.9.32
True
PASS: control-center base
FIX_GRAPHIFY_OUT_PROCESS_ISOLATION=True
FIX_INDEX_DIRECT_GRAPHIFY_ROOT_EXCLUSION=True
GRAPHIFYIGNORE_GRAPHIFY_OUT_LINE=True
GRAPHIFYIGNORE_LINES=18
GRAPHIFYIGNORE_FINAL: PASS
POST_FIX_STATIC_CHECK: PASS
```

El parse check final produjo `8` scripts PASS. Los smoke tests produjeron `PASS: project index smoke test`, `PASS: Graphify safety smoke test` y `PASS: context refresh smoke test`. Scheduler `-WhatIf` no registró tarea y removal `-WhatIf` devolvió `not-found: Cronos-Actualizar-Contexto`.

La auditoría de seguridad post-fix produjo:

```text
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

### Refresco real post-fix

Se ejecutó:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'scripts/actualizar-contexto.ps1' -Mode Session
```

El wrapper de verificación terminó con:

```text
REAL_REFRESH_POST_FIX_STARTED_UTC=2026-08-07T18:00:13.7571343Z
REAL_REFRESH_SESSION_EXIT_CODE: 0
REAL_REFRESH_POST_FIX_COMPLETED_UTC=2026-08-07T18:05:34.0749463Z
HACHI_IMMUTABILITY_POST_FIX=False
STALE_CACHE_TIMESTAMP_UNCHANGED_POST_FIX=True
```

El estado del proceso fue `startedAtUtc=2026-08-07T18:00:42.9264451Z`, `completedAtUtc=2026-08-07T18:05:18.3429475Z`, `indexExitCode=0`, `graphifyExitCode=0` y `exitCode=0`. El log agregó `2026-08-07T18:05:18.3429475Z|Session|0|0`.

El cache viejo permanecio existente durante ese snapshot, con tamaño `610634`, creacion `2026-08-07T16:53:37.6616214Z` y `LastWriteTimeUtc=2026-08-07T16:53:37.6656370Z` antes y despues del fix y del refresco. No se leyo ni modifico su contenido durante las pruebas; se elimino despues con confirmacion explicita del operador.

El fingerprint de `hachi-greciaspa` no pudo afirmarse igual porque hubo actividad concurrente durante la ventana. Se observaron 27 cambios de metadata, sin leer contenido:

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

La conclusión de inmutabilidad es `NO CONCLUYENTE POR ACTIVIDAD CONCURRENTE`, no un PASS. No se ejecutaron comandos de escritura sobre el proyecto.

### Índice real

La verificación excluye explícitamente el centro `Analista` y la raíz generada `graphify-out`, sin inventar filas:

```text
INDEX_DATA_ROWS=17
CURRENT_INDEPENDENT_PROJECT_ROOTS=17
INDEX_HAS_ANALISTA_ROW=False
INDEX_HAS_GRAPHIFY_OUT_ROW=False
INDEX_MISSING_ROOTS=0
INDEX_EXTRA_ROWS=0
INDEX_17_PROJECTS: PASS
```

### Graphify real

```text
GRAPHIFY_STATUS mode=Scheduled semanticMode=code-only exitCode=0
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
GRAPHIFY_CODE_ONLY_AND_SOURCE_EXCLUSIONS: PASS
```

Diagnóstico válido ejecutado:

```powershell
graphify diagnose multigraph --graph 'graphify-out/graph.json'
```

Resultado real relevante: `nodes=8583`, `raw_edges=18235`, `missing_endpoint_edges=0`, `dangling_endpoint_edges=2059`, `self_loop_edges=26`, `directed_same_endpoint_collapsed_edges=203`, `post_build_edges=15947` y `producer_suppression_sites=11`.

No se declara salud del grafo. El warning de integridad queda pendiente de aceptación explícita del operador.

### Estado de tareas

Tasks 1-5 permanecen en `revisión` con referencias actualizadas. Task 6 permanece en `en progreso` hasta la revisión final de Cronos; el operador ya confirmó contar 17 proyectos independientes y aceptar el warning de integridad Graphify como no bloqueante.

## Cierre post-confirmación

El operador confirmó que `Analista` es el centro de control, que existen 17 proyectos independientes y que el warning de integridad Graphify no bloquea el uso del mapa mientras se informe explícitamente.

Se eliminó únicamente `F:\Proyectos\graphify-out\cache\stat-index.json`, cache generado por el intento anterior. Verificación posterior: `STALE_CACHE_EXISTS=False`. El directorio padre vacío se conserva sin contenido.

Verificación fresca posterior a la corrección de overrides:

```text
PASS: project index smoke test
PASS: Graphify safety smoke test
PASS: context refresh smoke test
Parsed scripts: 8
```

Los overrides que apuntan a una raíz de proyecto ahora son rechazados; los fixtures temporales continúan permitidos. El refresco real posterior mantuvo `indexExitCode=0`, `graphifyExitCode=0`, `semanticMode=code-only`, 17 filas independientes y cero violaciones de rutas fuente prohibidas. El diagnóstico continúa mostrando aristas colgantes, self-loops y colapsos; no se declara salud total del grafo.
