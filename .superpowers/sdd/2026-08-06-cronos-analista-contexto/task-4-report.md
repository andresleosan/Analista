# Informe Task 4: integracion segura de Graphify

Fecha de verificacion: 2026-08-07
Centro de control: `F:\Proyectos\Analista`
Estado: verificado, sujeto a revision de Cronos
Commits: `none (no Git repository)`

## Alcance aplicado

Se implemento la integracion local y determinista de Graphify 0.9.32 con estas
garantias:

- El modo `Scheduled` ejecuta solamente `graphify extract` con `--code-only` y
  `--no-cluster`.
- Los argumentos se entregan mediante un array de PowerShell, no como una
  cadena shell interpolada.
- `Manual` se rechaza cuando `manualSemanticMode` es `disabled`, con un mensaje
  explicito sobre la sesion activa de Cronos o la aprobacion de backend/costo.
- `-WhatIf` valida rutas y la disponibilidad del ejecutable sin invocar
  Graphify ni crear salidas.
- La version se valida con `graphify --version` antes de una ejecucion real y
  debe coincidir con `0.9.32`.
- El estado se escribe en `state/graphify-status.json` mediante archivo
  temporal y reemplazo atomico.
- Los fallos de Graphify conservan el mismo codigo de salida en el proceso y
  en el estado persistido.
- La salida del binario no se retransmite; no se imprimen valores de entorno,
  API keys ni secretos de argumentos.

## TDD RED/GREEN

### RED inicial

La prueba se creo antes de `scripts/actualizar-graphify.ps1` y se ejecuto con:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-GraphifySafetySmokeTest.ps1'
```

Resultado observado: exit code `1`.

```text
RED: production script is absent: F:\Proyectos\Analista\tests\..\scripts\actualizar-graphify.ps1
```

El fallo fue el esperado: faltaba el script de produccion, no un error de
configuracion del arnes.

### GREEN inicial

Despues de crear la configuracion, el script, el estado inicial y el ignore
compartido, la misma prueba termino con:

```text
PASS: Graphify safety smoke test
```

### Regresion de salida no cero

Durante el self-review se agrego una prueba con un `graphify.cmd` temporal que
devuelve `23` y escribe en `stderr`. Primero fallo con el codigo del proceso
degradado a `1`:

```text
TEST FAILURE: Assertion failed: scheduled extraction should return the Graphify failure exit code (actual: 1; output: ... Graphify extraction failed with exit code 23.)
```

La causa fue que `stderr` de un binario nativo, combinado con
`$ErrorActionPreference = 'Stop'`, interrumpia la captura antes del retorno
normal. Se corrigio capturando la salida con preferencia temporal `Continue` y
leyendo `$LASTEXITCODE` inmediatamente.

La prueba final volvio a GREEN:

```text
PASS: Graphify safety smoke test
```

## Archivos

- `config/graphify.json`
- `scripts/actualizar-graphify.ps1`
- `tests/Invoke-GraphifySafetySmokeTest.ps1`
- `state/graphify-status.json`
- `F:\Proyectos\.graphifyignore`
- Este informe en `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-4-report.md`

`tasks.md` no se modifico porque no forma parte de los archivos asignados para
esta tarea; tampoco se uso Git.

## Pruebas ejecutadas

### Smoke de seguridad Graphify

Comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-GraphifySafetySmokeTest.ps1'
```

Salida final:

```text
PASS: Graphify safety smoke test
```

La prueba usa exclusivamente un fixture bajo `%TEMP%` y elimina fixture y
salidas en `finally`. Verifica:

- `graphify-out/graph.json` temporal existente.
- Inclusion de `src/App.ts` o del simbolo `appName`.
- Ausencia de `.env`, `node_modules`, `dist`, `TOKEN=` y `secret-value` en el
  grafo.
- `-WhatIf` sin invocacion mediante un ejecutable falso con marcador y sin
  crear el directorio de salida.
- Modo `Manual` rechazado con `manualSemanticMode` deshabilitado.
- Ausencia de un valor de entorno de prueba en la salida de `Manual`.
- Codigo de salida `23` preservado y registrado en el estado ante un fallo de
  Graphify.
- Estado exitoso con las siete claves requeridas y sin archivo `.tmp` residual.
- `F:\Proyectos\Analista\graphify-out` sin cambios.

### Regresion del indice

Comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File 'tests/Invoke-ActualizarIndiceSmokeTest.ps1'
```

Salida:

```text
PASS: project index smoke test
```

El test existente tambien trabaja con fixtures temporales.

### Version instalada

Comando:

```powershell
graphify --version
```

Salida:

```text
graphify 0.9.32
```

### Configuracion y ignore

Se validaron mediante PowerShell el parseo JSON, los valores exactos de
`config/graphify.json` y las 17 lineas exactas de `F:\Proyectos\.graphifyignore`.

Salida:

```text
PASS: Graphify config and ignore validation
```

### Limpieza

Se comprobo que no quedaron `graphify-out`, archivos `.tmp` de estado/config o
scripts temporales en el centro de control. La busqueda del prefijo de fixture
`cronos-graphify-smoke-*` bajo `%TEMP%` no encontro archivos.

Salida:

```text
PASS: no local Graphify test artifacts
```

## Self-review de seguridad

- No se agregaron API keys, credenciales, tokens reales, servicios pagos ni
  backends externos.
- El camino programado queda fijado a extraccion local `--code-only`.
- Los patrones de secreto, artefactos y dependencias fueron incluidos en el
  ignore compartido y en el fixture local.
- El script no consulta ni imprime el entorno y no retransmite la salida de
  Graphify.
- Los parametros de ruta llegan al proceso como argumentos separados.
- Las rutas se normalizan y se valida que el root de proyectos exista; en
  `-WhatIf` no se crean directorios.
- El unico archivo escrito fuera de `F:\Proyectos\Analista` fue
  `F:\Proyectos\.graphifyignore`, expresamente permitido por el brief.
- No se ejecuto Graphify contra `F:\Proyectos` ni contra ningun proyecto real.
- No existe un repositorio Git en el centro, por lo que no habia historial que
  auditar y no se hicieron commits.
- No hay hallazgos criticos de seguridad abiertos.

## QA y rendimiento

QA funcional: GREEN con evidencia real en el smoke de Graphify y en la
regresion del indice.

Rendimiento: no aplica una medicion de release; el proyecto esta clasificado
como Nivel 1 y esta tarea agrega una automatizacion local pequena, no una
release grande.

## Preocupaciones residuales

- `-WhatIf` resuelve la disponibilidad del ejecutable pero no ejecuta
  `graphify --version`, deliberadamente, para cumplir la garantia de no
  invocacion. La validacion de version se ejecuta en toda ejecucion real.
- El camino semantico de `Manual` solo seria alcanzable si se cambia
  explicitamente la configuracion fuera del valor entregado (`disabled`); no
  se habilito ni se probo contra ningun backend.
- El archivo de estado inicial usa valores nulos hasta la primera ejecucion
  real; esto evita fingir que Graphify ya corrio.
