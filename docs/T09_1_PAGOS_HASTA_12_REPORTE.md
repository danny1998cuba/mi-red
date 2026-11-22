# T09.1 · Pagos de 1 a 12 mensualidades

Mi Red 1.1.0 · Android código 3 · CoreX4Dev · 22 de noviembre de 2026.

## Cambios de producto

**Registrar pago** empieza en una mensualidad. El selector abre una lista desplazable de 1 a 12. La vista previa lista mes, importe y contexto de cada cargo. Muestra la suma y la próxima mensualidad pendiente, incluso cuando quedan meses pagados después de un impago. Una mensualidad genera un pago individual con nota opcional. De 2 a 12 se crea una operación con un pago completo por cargo. Los clientes archivados conservan el flujo individual anterior para cargos existentes. Los suspendidos reciben una advertencia y su estado sigue siendo manual.

El servicio proyecta en memoria los cargos que corresponderían a la conciliación actual. Ordena los impagados por período de servicio, omite los que tienen un pago activo y añade únicamente los cargos futuros que faltan. Un cargo existente aporta su importe persistido. Un cargo nuevo usa la tarifa individual vigente. La suma usa unidades menores enteras y comprueba el límite de SQLite antes de cada adición.

La confirmación concilia y vuelve a calcular la selección dentro de una sola transacción. Comprueba día local, período, cliente, moneda, cargos, importes y deuda restante. Si algo cambia, revierte y muestra una revisión actualizada que exige otro toque. La identidad de la revisión se guarda como ID del pago individual o del grupo. La restricción de un pago vigente por cargo protege también frente a otras llamadas simultáneas.

## Orden comprobable

Con noviembre de 2026 seleccionado, el bloque **Período seleccionado** muestra noviembre y sus acciones. **Próximos meses / Anticipos** muestra diciembre, enero, febrero y los demás cargos posteriores persistidos, siempre de menor a mayor. **Períodos anteriores** muestra octubre, septiembre y agosto al retroceder. Un pago con fecha anterior a la apertura del cargo se identifica como anticipado. Elegir enero o un mes anterior recompone las secciones sin emitir cargos. La conciliación ordinaria sigue ejecutándose al arrancar, reanudar y preparar Cobros.

**Ver operaciones** alterna en la misma pantalla entre los períodos y una lista de pagos individuales y grupos. Las entradas se ordenan por fecha original del cobro, más reciente primero. Las anulaciones y sus fechas se consultan dentro de su operación. Cada grupo aparece una vez y sus meses se enumeran de menor a mayor dentro del detalle. Volver al historial conserva el período elegido y su posición de desplazamiento.

## Anulación y auditoría

- **Anular esta mensualidad** comprueba que el pago sigue vigente y pertenece al grupo y cliente revisados. Solo escribe su fecha de anulación. Los demás hijos y otros grupos conservan su estado.
- **Anular grupo completo** o **Anular mensualidades restantes del grupo** exige revisar los miembros aún vigentes y su importe. La transacción compara sus IDs con los confirmados. El trigger anula solo esos pagos y conserva la auditoría anterior. Una anulación corrige el registro contable. La app informa que no devuelve dinero.
- El estado deriva de los hijos: **Vigente** si ninguno está anulado, **Parcialmente anulado** si quedan hijos de ambos estados y **Totalmente anulado** si todos están anulados. El total original permanece inmutable. El importe vigente suma hijos activos y el anulado es la diferencia. Los listados, Inicio, WhatsApp y las vistas abiertas desde los recordatorios siguen usando los pagos activos por cargo.
- Un cargo anulado vuelve a tener la prioridad de su período. Volver a cobrarlo crea un nuevo pago con su propia identidad. El pago anulado y su grupo original se conservan.

## Persistencia y respaldo

En v4 las tablas ya admitían varios hijos por grupo. Los triggers limitaban la cantidad a dos y exigían la anulación conjunta. v5 sustituye `payments_match_batch`, `payments_immutable`, `payment_batches_immutable` y `payment_batches_void_children`. La migración v4→v5 conserva tablas, columnas, índices y filas. Las rutas desde versiones anteriores aplican sus cambios previos y luego los triggers v5. Se conservan los snapshots v1–v4 y se añade v5.

La fecha del grupo registra la acción conjunta, si se ejecutó. Un grupo totalmente anulado por acciones individuales puede tener esa fecha vacía. El estado se obtiene siempre de los miembros. Los grupos históricos v4 activos y anulados conservan todos sus valores.

El contenedor `.miredbk` sigue en formato 1 con AES-GCM y PBKDF2. La copia nueva declara esquema 5. La restauración autentica y verifica cardinalidad 2–12, cargos distintos del mismo cliente, fecha original, sumas y fechas de anulación. Los esquemas 2/3 restauran pagos individuales con vínculos nulos. El esquema 4 conserva grupos de dos y sus anulaciones conjuntas. Para abrir nuevas copias hace falta la versión compatible con esquema 5.

## Archivos

| Área | Archivos |
|---|---|
| Selección, transacciones y anulaciones | `lib/features/billing/data/payment_service.dart` |
| Selector, detalle y orden visual | `lib/features/billing/{billing_screen,client_billing_screen}.dart` y `widgets/{payment_action,batch_payment_action,billing_widgets}.dart` |
| Esquema y migraciones | `lib/core/database/{app_database.dart,schema.drift,app_database.g.dart}`, `drift_schemas/drift_schema_v5.json`, `test/generated_migrations/` |
| Respaldo | `lib/features/backups/{backup_snapshot,backup_section}.dart` |
| Regresión y casos nuevos | `test/features/billing/`, `test/features/backups/`, `test/core/database/`, `tool/device_ip_smoke.dart` |
| Guías | Especificación, modelo, plan, README, changelog y documentación de usuario |

## Pruebas

| Casos solicitados | Verificación automatizada |
|---|---|
| 1–6 | Cantidades válidas e inválidas, selección desde la deuda más antigua, saltos de pagados, cruce de año, febrero, día 30, tarifa histórica, fallo SQLite en hijo 7, doble confirmación y revisión obsoleta. |
| 7–10 | Orden visual y posición de cada período, selección anterior y futura, operaciones por hora de registro, hijos por período, retorno al mes elegido, y controles a 320 dp/200 % en claro y oscuro. |
| 11–20 | Anulación de un miembro intermedio y de los extremos, prioridad de la nueva deuda, completar un grupo parcial, anular 12, fallo a mitad de la anulación, rechazo de repeticiones y grupo/cliente incorrecto, pago individual heredado, recobro sin duplicar y proyecciones de deuda y recaudación. |
| 21–24 | Reapertura con grupo parcial, migraciones desde v1–v4, respaldo cifrado de esquemas 2–5 y suma de 12 cargos cerca del límite entero de SQLite. |

Baseline de T09: 323 pruebas. Se mantienen los escenarios anteriores y se actualizan las expectativas relativas a anulación conjunta exclusiva, formato y esquema.

| Comando o verificación | Resultado observado |
|---|---|
| Comparación de snapshots Drift v4/v5 | Las únicas diferencias en los objetos SQLite son los cuatro triggers documentados. |
| `dart format .` | Aplicado a los 107 archivos antes de la última pasada de widgets. |
| Suite general de la revisión previa | 342 de 344. Fallaron la selección de 12 meses a 200 % y la expectativa de un solo rótulo para el período seleccionado. |
| Widgets de Cobros e Inicio en la revisión corregida | **41 de 41** en 40 s. Pasaron ambos casos corregidos, la revisión obsoleta, el orden de secciones y la anulación de un miembro a 200 %. |
| `dart analyze --fatal-infos` / `flutter analyze` | La pasada anterior de Dart señaló tres avisos que se corrigieron. Queda confirmar el análisis de la revisión final. |
| `flutter test` completo final y `flutter build apk --release` | Pendientes. El rechazo de la revisión automática impidió ejecutar ambos comandos en la revisión final. El APK de T09 anterior no contiene T09.1. |
| `git diff --check` | Pasó. |
| QA Android | Dos arranques del AVD desechable API 35 no habilitaron el destino ADB. No se instaló ningún APK de T09.1 en teléfono ni emulador. |

El 22 de noviembre la revisión automática rechazó ejecutar el análisis final, repetir toda la suite, compilar Release y detener el proceso del emulador de T09.1. Informó un límite de uso y disponibilidad para reintentar a las 15:22, hora de Toronto. Estos comandos no se ejecutaron en ese intento.

## Validación previa a distribución

La actualización de producción requiere un APK firmado manualmente con el mismo certificado CoreX4Dev. Debe instalarse sobre Mi Red 1.0 en Android sin desinstalar ni borrar datos. Verifica antes el código de la versión instalada. Si ya se distribuyó el código 3, la próxima distribución deberá usar uno mayor.

En un dispositivo de prueba, con datos sintéticos, crea una copia cifrada desde la versión anterior y guarda la contraseña por separado. Tras actualizar, compara clientes, importes y auditoría. Restaura la copia, cobra 12, anula un miembro, vuelve a abrir Mi Red, comprueba los importes, anula el resto y restaura una nueva copia. Comprueba los estados y la integridad de los registros después de cada operación.
