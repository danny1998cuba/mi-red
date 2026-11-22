# T09 · Pago de 2 mensualidades

Mi Red 1.1.0, código Android 3 · CoreX4Dev · 22 de noviembre de 2026.

## Comportamiento

**Registrar pago** abre la confirmación de una mensualidad y ofrece **2 mensualidades**. También se puede iniciar un grupo desde el historial del cliente si el período vigente ya está pagado. La revisión muestra cliente, períodos, importes, total, hora de revisión, anticipos y deuda restante. Se registra la hora real de confirmación. Un cambio de día, cliente, selección, importe, moneda o deuda restante exige volver a revisar el cobro. Los clientes suspendidos ven una advertencia y mantienen su estado. Los archivados pueden consultar y anular grupos existentes.

La priorización empieza después de conciliar los cargos del cliente. Se reutilizan las reglas de alta, reactivación, calendario y tarifa. Entre cargos impagados elegibles se toman primero los más antiguos, incluso si hay un mes pagado entre ellos. Si faltan lugares, la búsqueda avanza desde el primer período futuro elegible y salta cargos existentes. La reconciliación de clientes suspendidos conserva la regla anterior de no emitir cargos ordinarios. El usuario puede pagar su deuda existente o futuros períodos mediante confirmación explícita.

El historial muestra un grupo por operación y permite consultar sus dos pagos. La anulación afecta ambos pagos en la misma operación y conserva importes, fechas, cargos futuros y auditoría. Las mensualidades de otro grupo permanecen pagadas. La ficha muestra el pendiente más antiguo si hay deuda. Solo muestra «Cubierto hasta» cuando hay un tramo continuo desde el período vigente o el inicio elegible y no quedan cargos impagados.

## Persistencia y compatibilidad

- La auditoría de v1.0 confirmó una fila por cliente y período, un pago vigente por cargo, importe exacto en unidades menores, corrección limitada del cargo vigente impagado y conservación de pagos históricos. Inicio, Cobros, listados de texto y WhatsApp consultan cargos y pagos hijos. El total del grupo se utiliza en el historial. La recaudación sigue atribuida al período de servicio.
- SQLite v3→v4 crea `payment_batches(id, client_id, paid_at, total_minor, voided_at)` y añade `payments.batch_id` nullable con FK. Añade el índice del cliente por fecha, la unicidad de cargo por grupo y los triggers que validan pertenencia, fecha, estado, máximo de dos hijos, suma y anulación conjunta. Se conserva la unicidad previa de pago vigente por cargo. Las migraciones desde v1/v2 ejecutan primero los pasos existentes de IP y tipo de dispositivo. Se verifica `foreign_key_check` antes del commit y se conservan los snapshots v1–v3. [Documentación de migraciones Drift](https://drift.simonbinder.eu/migrations/)
- La previsualización calcula los cargos faltantes con el mismo generador de conciliación sin persistirlos. Al confirmar, una transacción concilia, vuelve a calcular y comparar, inserta los cargos futuros necesarios, el grupo y dos pagos completos. Se rechaza un total fuera del rango entero de SQLite. El identificador de la revisión se convierte en la clave primaria del grupo. Repetir esa confirmación o presentar otra revisión que ya quedó obsoleta no genera otro cobro. [Transacciones Drift](https://drift.simonbinder.eu/dart_api/transactions/)
- El contenedor `.miredbk` sigue en formato 1 con AES-256-GCM y el mismo PBKDF2. El payload nuevo declara esquema 4 e incluye seis tablas. Valida dos hijos con cargos distintos, cliente, instantes, estado y suma. Los payloads de esquema 2/3 se validan según su forma de cinco tablas antes de restaurarlos con grupos vacíos y vínculos NULL. El reemplazo se confirma en una sola transacción. Una app 1.0 no acepta el payload nuevo.
- Los avisos de Android siguen siendo recordatorios locales generales. Al abrir Cobros, los estados y candidatos se derivan de cargos impagados. Una mensualidad anticipada con pago vigente no aparece entre ellos. No existe una métrica de caja por fecha real. Si se incorpora en una etapa futura, deberá contar los pagos hijos una sola vez.

## Archivos

| Área | Rutas |
|---|---|
| Dominio y consultas | `lib/features/billing/data/{billing_service,payment_service,billing_queries}.dart` |
| Pantallas y acciones | `lib/features/billing/client_billing_screen.dart`, `lib/features/billing/widgets/{payment_action,batch_payment_action,billing_widgets}.dart`, `lib/features/clients/client_detail_screen.dart` |
| Esquema, migración y generación | `lib/core/database/{schema.drift,app_database.dart,app_database.g.dart}`, `drift_schemas/drift_schema_v4.json`, `test/generated_migrations/` |
| Formato y restauración | `lib/features/backups/{backup_snapshot,backup_service,backup_section}.dart` |
| Pruebas y herramienta | `test/features/billing/{payment_batch,billing_widgets}_test.dart`, `test/features/backups/{backup_data_test,backup_fixture}.dart`, `test/core/database/`, `tool/device_ip_smoke.dart` |
| Versión y documentación | `pubspec.yaml`, README, CHANGELOG, especificación, modelo, plan, manual, guía rápida y guía de recuperación |

## Verificación automatizada

| Casos | Evidencia |
|---|---|
| P01–P08 | Selección por deuda y tarifa individual, mes pagado intercalado, creación mínima, períodos sin cargos, diciembre–enero–febrero, último día de febrero, corte día 30, morosidad día 3, snapshot de tarifa y filtro de pagados. |
| P09–P10 | Trigger de fallo en la segunda inserción y verificación de rollback de conciliación, cargo futuro, grupo y pagos. Confirmaciones simultáneas y repetidas, incluso después de anular. |
| P11–P16 | Anulación conjunta, rechazo por API y SQL del pago hijo, rechazo repetido, conservación del grupo posterior y deuda anterior, elegibilidad y advertencia en UI, y regresión de pago/anulación individual. |
| P17 | Bases sintéticas de archivos SQLite v1, v2 y v3 migradas con Drift SchemaVerifier y reabiertas. Comparación de las filas previas, estructura, FK e integridad. La suite también usa bases nuevas v4. [Verificación de esquemas Drift](https://drift.simonbinder.eu/migrations/tests/) |
| P18–P20 | Archivos temporales `.miredbk` cifrados con registros sintéticos en la forma de v1.0, esquemas 2 y 3. Restauración a v4 sin asignar grupos. Copia v4 con un grupo vigente y otro anulado, comparación de todos los registros, rechazo de contraseña errónea, bytes dañados e inconsistencias de grupos. |
| P21–P22 | Recaudación del período sin sumar el grupo, estados que alimentan el reporte, candidato del día 3 y recorrido de cobro/anulación a 320 dp con tema oscuro y texto al 200 %. |

- `dart format .` procesó 106 archivos. `dart analyze --fatal-infos .` finalizó sin incidencias. El servidor de análisis iniciado por `flutter analyze --no-pub` quedó sin responder en dos intentos y se cerraron solo esos procesos de la tarea. Se completó la cobertura de análisis con el comando Dart.
- `flutter test --no-pub --reporter expanded` aprobó **323 de 323** pruebas. Incluye las regresiones de Mi Red 1.0 de pagos individuales, corrección, archivado, conciliación, apariencia, reportes y avisos.
- `dart run build_runner build` y los comandos `drift_dev schema dump` y `schema generate` actualizaron el código generado y añadieron el snapshot v4. `git diff --check` pasó.
- `flutter build apk --release` compiló el [APK sin firma](../build/app/outputs/flutter-apk/app-release.apk) en 47,9 s (67,2 MB). `aapt` confirmó `com.mired.offline`, versión 1.1.0, código 3. `apksigner verify` devolvió el error esperado para un archivo sin firma. SHA-256 `13e547a5fa0c91e0cf9758ec1be38ad9f2077609899dc0cef723d218ce33e61d`.
- El primer build con `--no-pub` leyó un registro generado que todavía incluía `integration_test`. Flutter regeneró ese archivo al compilar con el comando normal. El build final emitió avisos de Kotlin de dos plugins y de referencia a la fuente CupertinoIcons durante la reducción de fuentes. Se conservó el conjunto actual de dependencias.

El APK anterior inspeccionado al preparar 1.0.1 declara 1.0.0 y código 1. La versión 1.0.1 del proyecto y su APK Debug verificado declaran código 2. El cambio prepara 1.1.0+3 con el ID `com.mired.offline`.

## Validación manual previa a distribución

La evidencia de esta iteración es automatizada. La migración Android con firma de distribución y el recorrido por el selector de documentos con una copia creada por la app instalada de 1.0 quedan pendientes. T09 requiere esas comprobaciones antes de aprobar la distribución.

1. En un Android de prueba con Mi Red 1.0 Release y datos sintéticos, registra clientes, equipos, una mensualidad pendiente, un pago vigente y uno anulado. Crea y verifica una copia externa, y guarda la contraseña fuera del chat y del repositorio.
2. Firma manualmente la compilación 1.1.0 con el certificado original de distribución y verifica el paquete y el código Android. Instálala sobre 1.0 sin desinstalar. Abre la app y comprueba los mismos clientes, equipos, importes y pagos individuales.
3. En ese entorno de prueba, importa la copia externa exportada por 1.0. Confirma que los valores y la auditoría coinciden. Registra y anula un grupo, crea una copia 1.1 y restáurala para revisar ambos pagos y sus estados. Haz la prueba en modo avión.
