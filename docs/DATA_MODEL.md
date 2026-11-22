# Modelo de datos mínimo — SQLite / Drift

El modelo documenta invariantes, no obliga a un nombre exacto de clase Dart. Elegir UUID (TEXT) o identificadores estables; todas las referencias deben tener FK e índices adecuados.

Los instantes de auditoría se almacenan como INTEGER de milisegundos desde Unix epoch. Las fechas de calendario son TEXT `YYYY-MM-DD` locales y se calculan de forma independiente de esos instantes. SQLite v5 permite grupos de 2 a 12 miembros y anulaciones por miembro. La app conserva las rutas de migración desde v1 a v4.

## `clients`
- `id` TEXT PK
- `full_name` TEXT NOT NULL
- `phone` TEXT NULL
- `address` TEXT NULL
- `monthly_fee_minor` INTEGER NOT NULL CHECK >= 0
- `status` TEXT NOT NULL (`active`, `suspended`, `archived`) — estado manual del SERVICIO, distinto del pago
- `notes` TEXT NULL
- `created_at` INTEGER/ISO8601 NOT NULL; `updated_at` idem
- `archived_at` NULL
- `billing_start_period` TEXT NOT NULL (`YYYY-MM`): primer período elegible del último intervalo activo. Se inicializa al alta y se avanza al período vigente al reactivar para no reconstruir cargos del intervalo archivado/suspendido. No sustituye fechas de auditoría; detalle de implementación en `../T02_PERSISTENCE.md`.

## `devices`
- `id` TEXT PK
- `client_id` TEXT NOT NULL FK -> clients
- `type` TEXT NOT NULL, sin CHECK de catálogo desde v3. La entrada de la app exige texto no vacío y recorta espacios exteriores. Se conservan los códigos históricos `antenna`, `ont`, `router`, `other` y se muestran con sus etiquetas españolas; los tipos nuevos se guardan como texto libre.
- `mac_address` TEXT NULL (normalizar a AA:BB:CC:DD:EE:FF)
- `notes` TEXT NULL
- `ip_address` TEXT NULL **añadida en v2**: IPv4/IPv6 numérica opcional, validada localmente con `InternetAddress.tryParse`, recortada y normalizada desde sus bytes mediante `InternetAddress.fromRawAddress(...).address.toLowerCase()`. Vacío se guarda como NULL. No se permiten hostnames, puertos, CIDR, zonas, corchetes ni IPv4 abreviada/con ceros iniciales. No hace DNS ni abre sockets.
- Index `client_id`; advertir sobre MAC duplicada, sin impedir reemplazos válidos.
- IP y MAC son independientes. Sin índice UNIQUE ni valor de IP predeterminado. El servicio conserva la IP al omitir el argumento (`Value.absent()`); `Value(null)` o texto vacío la elimina explícitamente.

## `charges`
- `id` TEXT PK
- `client_id` TEXT NOT NULL FK -> clients
- `period_key` TEXT NOT NULL (`YYYY-MM`; mes que recibe el servicio)
- `collection_date` TEXT NOT NULL (último día o día 30 del mes anterior)
- `suspension_candidate_date` TEXT NOT NULL (día 3 del período)
- `amount_minor` INTEGER NOT NULL CHECK >= 0 (snapshot de tarifa)
- Fase A permite una corrección explícita solo si es del período vigente, no tiene pago activo y sigue coincidiendo con el importe revisado al confirmar. Solo cambia `amount_minor`; se conservan identidad, fechas, tarifa del cliente y pagos anulados. v2 no almacena una bitácora de correcciones.
- `created_at` NOT NULL
- UNIQUE(`client_id`, `period_key`)

## `payments`
- `id` TEXT PK
- `charge_id` TEXT NOT NULL FK -> charges
- `amount_minor` INTEGER NOT NULL CHECK >= 0
- `paid_at` NOT NULL
- `note` TEXT NULL
- `voided_at` NULL; si NO NULL el pago fue anulado, conservar auditoría
- Índice sobre `charge_id`, restringir a un solo pago activo por cargo (índice único parcial o validación transaccional).
- `batch_id` TEXT NULL, FK a `payment_batches`. Los pagos individuales tienen NULL. El índice único `(batch_id, charge_id)` impide duplicar un cargo en un grupo.

## `payment_batches` (v4)
- `id` TEXT PK. La confirmación usa el ID de la previsualización para impedir repetir la misma operación.
- `client_id` TEXT NOT NULL FK a `clients`, con índice por cliente y fecha.
- `paid_at` INTEGER, coincide con la fecha original de todos los hijos. `voided_at` nullable registra una anulación conjunta. El trigger actualiza únicamente miembros todavía vigentes. Un grupo puede quedar totalmente anulado mediante acciones individuales y tener ese campo NULL. Su estado se deriva de cuántos hijos conservan `payments.voided_at` NULL.
- `total_minor` INTEGER NOT NULL, suma original de 2 a 12 pagos de cargos distintos del mismo cliente. El vigente suma hijos activos y el anulado es la diferencia. Los resúmenes por período solo usan pagos vigentes por cargo.

## `app_settings`
- Registro singleton `id=1`
- `business_name`, `currency_label`, `default_calling_code`, `notifications_enabled`, `last_backup_at`, etc.
- Fase A reutiliza las columnas existentes para «Mi negocio», sin migración: nombre obligatorio, etiqueta vacía permitida y prefijo opcional. Al editar negocio, `SettingsService.update` omite `notifications_enabled` si no recibe un valor; `last_backup_at` nunca forma parte de esa escritura. T07 conserva todas las columnas con sus valores exactos, incluso datos anteriores a los límites de entrada de Fase A.

## Lógica derivada y consultas
- `chargeStatus(charge, today)`:
  - `paid` si existe pago `voided_at IS NULL`.
  - `suspension_candidate` si no pagado y `today >= charge.suspension_candidate_date`.
  - `pending` en el resto.
- `clientHasSuspensionCandidate(client)` si existe cualquier cargo sin pagar cuyo día 3 haya pasado.
- Resumen de período: total cargos, pagados, pendientes, candidatos, suma de pagos efectivos; filtrar correctamente cliente archivado cuando se cuenten 'activos' sin borrar pagos históricos.
- Siempre contabilizar dinero como `int`, sin decimales de punto flotante; mostrar etiqueta de moneda configurada.
- Cualquier reconciliación de períodos y registro/anulación de pagos usa transacciones de BD.

## Notas de migración y backup

- Fase B no cambia SQLite v2 ni sus cinco tablas. `mi_red.appearance_mode` es una preferencia local SharedPreferencesAsync (DataStore en Android): `light`, `dark`, o clave ausente para Automático. Se excluye del snapshot T07; restaurar no importa ni sobrescribe apariencia. Android API31+ conserva además su modo visual de recursos para el splash, separado de los datos del negocio.
- SQLite v1 → v2: `Migrator.addColumn(devices, devices.ipAddress)` dentro de una transacción, seguida de `PRAGMA foreign_key_check`. Solo se añade una columna TEXT nullable al final de `devices`; las filas anteriores quedan con IP NULL. No se recrean tablas ni cambian índices/triggers u otras columnas. Nuevas bases se crean directamente en v2. Reabrir v2 no repite la migración; una versión sin ruta implementada se rechaza. Si falla la integridad, se revierte la columna añadida.
- Conservar `drift_schemas/drift_schema_v1.json` y `drift_schema_v2.json`; utilidades Drift de prueba en `test/generated_migrations/`. Véase `../T03_2_IP_DEVICES.md` para evidencia con registros v1, pagos/anulaciones y reaperturas.
- Schema version incremental usando migraciones Drift, no `drop-and-recreate` en releases.
- El archivo de backup tiene versión propia, separada del schema SQLite; validar antes de importar.
- T07 estableció `.miredbk` formato 1. Las copias históricas de esquemas 2 y 3 contienen cinco tablas con las columnas SQL explícitas y los instantes como INTEGER en milisegundos. Incluyen IP y `notifications_enabled`. El esquema 2 exige los cuatro tipos de dispositivo históricos y el 3 admite texto libre. La autenticidad AES-GCM y la validación completa preceden al reemplazo transaccional. Se rechazan copias sin IP y versiones desconocidas.
- Exportar un snapshot consistente (transacción de lectura o mecanismo equivalente), NO copiar un archivo SQLite abierto ignorando WAL.
- Al restaurar, validar todo el payload antes del reemplazo y aplicar en una sola transacción; no borrar datos actuales al fallar.
- El contexto histórico de T03.2 no incluía respaldos. T07 conserva `devices.ip_address`, incluyendo NULL, sin modificar schemaVersion ni la migración v1→v2. La conciliación y los permisos reales se aplican separadamente después de restaurar.

- Cambio posterior a Fase C: v1/v2 → v3 en una transacción. Desde v1 se añade primero IP; se reconstruye únicamente devices con TableMigration para retirar el CHECK del catálogo, conservando columnas, valores e índices. FK se desactivan fuera de la transacción para la reconstrucción y se reactivan en finally; foreign_key_check se verifica antes del commit. No hay conversión de tipos ni cambios financieros. Las instantáneas v1/v2 se conservan y se añade v3. Las apps antiguas rechazan copias nuevas de esquema 3; no se garantiza downgrade.
- T09 añade `payment_batches`, la columna nullable `payments.batch_id`, dos índices y los triggers de integridad/anulación. La migración v3→v4 es aditiva y los pasos anteriores se ejecutan solo desde v1/v2. El payload de esquema 4 incorpora los grupos al formato cifrado 1. Para restaurar esquema 2/3 se usa una tabla de grupos vacía y vínculos NULL. Las apps anteriores requieren su propio esquema de copia.
- T09.1 reemplaza cuatro triggers en v4→v5, sin alterar tablas, columnas, índices o filas de v4. Mantiene inmutable el pago original y permite anular miembros individualmente. El formato cifrado 1 de esquema 5 verifica cardinalidad, pertenencia, suma y auditoría de anulaciones antes de restaurar. Sigue leyendo esquemas 2 a 4.
