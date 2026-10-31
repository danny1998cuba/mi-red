# Modelo de datos mínimo — SQLite / Drift

El modelo documenta invariantes, no obliga a un nombre exacto de clase Dart. Elegir UUID (TEXT) o identificadores estables; todas las referencias deben tener FK e índices adecuados.

En los esquemas v1, v2 y v3, todos los instantes de auditoría se almacenan como INTEGER de milisegundos desde Unix epoch. Las fechas de calendario son TEXT `YYYY-MM-DD` locales y se calculan de forma independiente de esos instantes. La versión actual es v3 (tipo de dispositivo libre); v1 fue la primera versión persistida y no se descarta.

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
- T07: `.miredbk` formato 1 admite las cinco tablas de esquemas 2 y 3, con columnas SQL explícitas e instantes INTEGER de milisegundos, sin convertirlos a texto o alterar sus valores. Incluye todas las IP y `notifications_enabled`; no incluye permisos ni cachés del SO. Esquema 2 exige los cuatro tipos históricos; esquema 3 admite texto obligatorio libre. Nuevas exportaciones declaran esquema 3; las importaciones conservan exactamente las filas del esquema 2. Formatos/esquemas anteriores sin IP y versiones futuras se rechazan, ya que no hubo respaldos implementados antes de T07. La autenticidad AES-GCM y la validación completa preceden al reemplazo transaccional.
- Exportar un snapshot consistente (transacción de lectura o mecanismo equivalente), NO copiar un archivo SQLite abierto ignorando WAL.
- Al restaurar, validar todo el payload antes del reemplazo y aplicar en una sola transacción; no borrar datos actuales al fallar.
- El contexto histórico de T03.2 no incluía respaldos. T07 conserva `devices.ip_address`, incluyendo NULL, sin modificar schemaVersion ni la migración v1→v2. La conciliación y los permisos reales se aplican separadamente después de restaurar.

- Cambio posterior a Fase C: v1/v2 → v3 en una transacción. Desde v1 se añade primero IP; se reconstruye únicamente devices con TableMigration para retirar el CHECK del catálogo, conservando columnas, valores e índices. FK se desactivan fuera de la transacción para la reconstrucción y se reactivan en finally; foreign_key_check se verifica antes del commit. No hay conversión de tipos ni cambios financieros. Las instantáneas v1/v2 se conservan y se añade v3. Las apps antiguas rechazan copias nuevas de esquema 3; no se garantiza downgrade.
