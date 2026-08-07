# Informe de la Tarea 2

## Archivos cambiados

- `scripts/actualizar-indice.ps1`
- `tests/Invoke-ActualizarIndiceSmokeTest.ps1`
- `INDICE-PROYECTOS.md`
- `state/context-status.json`
- `.superpowers/sdd/2026-08-06-cronos-analista-contexto/task-2-report.md`

No se leyeron ni modificaron proyectos externos. No se usó Git, no hubo commits,
despliegues, migraciones, credenciales ni servicios pagos.

## Evidencia TDD

### RED

Se creó primero `tests/Invoke-ActualizarIndiceSmokeTest.ps1`, antes de crear el
script de producción.

Comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\Invoke-ActualizarIndiceSmokeTest.ps1"
```

Salida observada:

```text
F:\Proyectos\Analista\tests\Invoke-ActualizarIndiceSmokeTest.ps1 : Index invocation failed:
El término 'F:\Proyectos\Analista\tests\..\scripts\actualizar-indice.ps1' no se reconoce como
nombre de un cmdlet, función, archivo de script o programa ejecutable.
```

El fallo fue el esperado por ausencia de `scripts/actualizar-indice.ps1`.

### GREEN

Después se implementó el script mínimo y se ejecutó:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\Invoke-ActualizarIndiceSmokeTest.ps1"
```

Salida:

```text
PASS: project index smoke test
```

La prueba cubre el fixture aislado con `alpha/docs`, `alpha/node_modules`,
`alpha/README.md`, `alpha/.env` y `alpha/node_modules/ignored.js`; verifica la
exclusión de `.env` y `node_modules`, el proyecto agregado en la primera corrida,
la ausencia de cambios en la segunda y `alpha` cambiado después de modificar
`README.md`.

### Refactorización y GREEN final

Se centralizó la conversión de listas de configuración en
`Get-ConfigStringArray`. Se repitió el mismo comando y volvió a producir:

```text
PASS: project index smoke test
```

También se corrigió la representación de acentos para PowerShell 5.1 usando
códigos Unicode explícitos en el script ASCII y escritura UTF-8 con BOM. El
encabezado generado se leyó correctamente como `# Índice de proyectos`.

## Verificaciones adicionales

PowerShell 5.1 y parseo del script:

```text
PowerShell version: 5.1.26100.8894
script parse errors: 0
index UTF-8 header valid: True
status generatedAtUtc present: True
status projects present: True
status diff keys present: True
temporary output files present: False
```

La generación real de `INDICE-PROYECTOS.md` y `state/context-status.json` se
ejecutó con un fixture temporal aislado y se limpió al finalizar. Los artefactos
del centro quedaron generados sin inventariar `F:\Proyectos`.

Pruebas de error de creación de rutas:

```text
projects-root exit code: 1
output-parent exit code: 1
```

Los dos casos emitieron el error real y devolvieron código no cero, como exige
el brief.

## Auto-revisión

### Seguridad

- No hay endpoints, autenticación, integraciones externas ni dependencias nuevas.
- No hay secretos hardcodeados ni contenido de archivos secreto leído por
  `Get-ProjectSnapshot`.
- Cada path se filtra con `Test-ExcludedPath` antes de crear `FileInfo` y leer
  metadata.
- El fingerprint usa solo `relativePath|length|lastWriteTimeUtc`; no lee el
  contenido de los proyectos.
- Los paths de salida y el root se normalizan y sus directorios se validan o
  crean; los fallos son no cero.
- No se detectó un hallazgo crítico de seguridad.

### QA

- RED observado por ausencia del script.
- GREEN observado con salida `PASS`.
- GREEN repetido después de refactorización y corrección de codificación.
- Parseo PowerShell 5.1 sin errores.
- Estado JSON validado con las claves `generatedAtUtc`, `projects`, `added`,
  `changed`, `removed` y `errors`.
- Temporales `.tmp` ausentes después de la generación.

## Preocupaciones

- `INDICE-PROYECTOS.md` y `state/context-status.json` se generaron con un
  fixture vacío para respetar la prohibición de leer proyectos externos; por eso
  no representan todavía el inventario real de `F:\Proyectos`.
- No se agregó una prueba automatizada específica para permisos ACL; la
  regresión del addendum cubre el fallo del segundo `Move-Item`, y los paths
  imposibles de root y parent de salida también fueron verificados.

## Estado

`revisión`: implementación y pruebas completadas; queda sujeta a revisión de
Cronos según el brief.

## Addendum: rollback transaccional

### Hallazgo verificado

La revisión detectó que `Write-ProjectOutputs` movía el Markdown y luego el
estado sin conservar copias de ambos destinos. Si el segundo movimiento fallaba,
el `catch` eliminaba temporales pero dejaba el Markdown nuevo en lugar del
contenido anterior.

### TDD RED

Se amplió `tests/Invoke-ActualizarIndiceSmokeTest.ps1` con una regresión real:
tras generar outputs válidos, guarda los bytes anteriores, bloquea
`state/context-status.json` con `FileShare.None` justo antes del segundo
`Move-Item` mediante un breakpoint interno del test, ejecuta el indexador, libera
el `FileStream` en `finally` y compara ambos destinos byte a byte, además de
revisar los temporales. El breakpoint es solo de sincronización del smoke test;
no agrega una interfaz pública al script.

Comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\Invoke-ActualizarIndiceSmokeTest.ps1"; "exit code: $LASTEXITCODE"
```

Salida RED:

```text
Assertion failed: the previous Markdown should be restored
exit code: 1
```

El fallo reprodujo el defecto del flujo anterior.

### Fix y GREEN

`Write-ProjectOutputs` ahora:

- Crea backups hermanos únicos para ambos destinos existentes antes de mover
  temporales.
- Mueve ambos temporales solo después de preparar los dos backups.
- Ante cualquier error, restaura desde backup cada destino existente y elimina
  únicamente un destino que no existía antes.
- Limpia backups durante rollback y difiere la limpieza de temporales al nivel
  superior después de liberar el handle del movimiento fallido, con reintentos
  para locks breves.
- Elimina backups únicamente después de completar ambos movimientos.

La prueba focal volvió a pasar:

```text
PASS: project index smoke test
exit code: 0
```

La suite completa de la Tarea 2 ejecutó el único test asignado:

```powershell
$overallExitCode = 0; $tests = @(Get-ChildItem -LiteralPath "tests" -Filter "*.ps1" -File); foreach ($test in $tests) { & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $test.FullName; if ($LASTEXITCODE -ne 0) { $overallExitCode = 1 } }; "suite test count: $($tests.Count)"; "suite exit code: $overallExitCode"
```

Salida limpia:

```text
PASS: project index smoke test
suite test count: 1
suite exit code: 0
```

### Auto-revisión del fix

- La regresión conserva y compara bytes, no solo contenido parseado.
- La regresión confirma que el fallo ocurre en el segundo `Move-Item`.
- El lock se libera siempre en `finally`, incluso si la invocación falla.
- No se agregaron parámetros ni interfaces públicas de prueba.
- La solución mantiene PowerShell 5.1 y no lee contenido de proyectos externos.
- No hay endpoints, secretos, dependencias nuevas ni integraciones.
- No se detectó un hallazgo crítico de seguridad.

### Estado del fix

`revisión`: RED y GREEN observados con salida real; el cambio queda sujeto a
revisión de Cronos.

## Addendum 2: rollback incompleto verificable

### Hallazgo verificado

La re-revisión detectó que las restauraciones y la eliminación de backups usaban
errores silenciosos. Si `OutputPath` estaba bloqueado durante el rollback, el
output nuevo podía quedar activo y los backups podían eliminarse sin confirmar la
restauración.

### TDD RED

Se conservó el escenario existente que bloquea `StatusPath` antes del segundo
`Move-Item`. Se agregó un segundo escenario que mantiene ese lock, abre
`OutputPath` con `FileShare.None` justo antes del tercer `Copy-Item` (la primera
restauración), comprueba antes de liberar ambos locks que la invocación falla con
`rollback incomplete` y que permanecen los backups de Markdown y estado. El
`finally` libera ambos locks y elimina los backups de la fixture.

Comando:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "tests\Invoke-ActualizarIndiceSmokeTest.ps1"; "exit code: $LASTEXITCODE"
```

Salida RED observada contra el rollback silencioso:

```text
Assertion failed: the failure should identify incomplete rollback
exit code: 1
```

### Fix y GREEN

El rollback ahora usa `Restore-TransactionPath`, que verifica cada copia o
eliminación y devuelve el error concreto. `Write-ProjectOutputs` acumula los
errores de ambos destinos y lanza `rollback incomplete: ...` sin borrar backups
si alguna restauración falla. Los backups solo se limpian después de dos
restauraciones verificadas o tras completar la transacción; cada resultado de
limpieza se comprueba. La limpieza superior de temporales también informa si no
puede completarse.

Prueba focal:

```text
PASS: project index smoke test
focal exit code: 0
```

Suite completa de la Tarea 2:

```text
PASS: project index smoke test
suite test count: 1
suite exit code: 0
```

Verificaciones adicionales:

```text
PowerShell version: 5.1.26100.8894
script parse errors: 0
SilentlyContinue occurrences: 0
```

No quedaron archivos `.tmp` ni `.bak` en el proyecto después de las pruebas.

### Auto-revisión de la segunda ronda

- Se mantiene la prueba del segundo `Move-Item` y se añade el bloqueo de
  `OutputPath` durante la restauración.
- El mensaje de fallo expone `rollback incomplete` antes de liberar locks.
- Los backups se verifican presentes durante el fallo y se limpian únicamente
  después de liberar locks en el `finally` del fixture.
- No se agregaron switches ni interfaces públicas de test.
- No hay endpoints, secretos, dependencias, integraciones ni proyectos externos.
- No se detectó un hallazgo crítico de seguridad.

### Estado de la segunda ronda

`revisión`: RED y GREEN observados con salida real; el cambio queda sujeto a
revisión de Cronos.
