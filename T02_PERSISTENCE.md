# T02 — Persistencia y motor de cobros

Esta guía está en la raíz porque la configuración Git existente excluye `docs/`; se conserva esa preferencia y la guía nueva queda disponible para versionar.

Solo capa de datos y reglas puras. Las pantallas y los siete tests de T01 permanecen intactos; los formularios/listados se harán en T03 y la integración de cobros con el ciclo de vida en T04.

## Dependencias y generación

Verificadas con Flutter 3.47.8 stable / Dart 3.13.7:

- `drift 2.35.3`, `sqlite3 3.8.0` y `path_provider 2.1.6`.
- `drift_dev 2.35.2` y `build_runner 2.17.1` para generar únicamente Drift.
- `integration_test` del SDK, solo para comprobar el arranque y SQLite en Android.

Se usa `NativeDatabase.createInBackground` y los assets nativos de sqlite3 3.x; no se necesitan `sqlite3_flutter_libs`, `sqflite` ni `drift_flutter`. La carpeta temporal se configura dentro del isolate de SQLite para no depender de `/tmp` en Android. Consultar la [configuración manual oficial de Drift](https://drift.simonbinder.eu/setup/#database-class).

Desde la raíz:

```powershell
flutter pub get
dart run build_runner build
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart format .
flutter analyze
flutter test
flutter test integration_test/database_smoke_test.dart -d emulator-5554
flutter drive --driver=test_driver/integration_test.dart --target=integration_test/database_smoke_test.dart -d emulator-5554 --no-dds
flutter build apk --debug
```

Sustituir el ID de dispositivo por el de `flutter devices`. La compilación requiere descargas iniciales; SQLite y los servicios funcionan localmente. No se añadieron permisos ni clientes remotos.

Conservar en Git `pubspec.lock`, `lib/core/database/app_database.g.dart` y `drift_schemas/drift_schema_v1.json`. No editar los generados a mano. Los paquetes Drift/SQLite/generadores se fijan a las versiones verificadas en esta entrega.

## Archivo y ciclo de vida

`openAppDatabase()` crea `mi_red.sqlite` en `getApplicationSupportDirectory()`: almacenamiento privado de la aplicación, sin permisos de almacenamiento compartido. Se abre de forma diferida y opera en un isolate. Esta BD privada se pierde al borrar los datos o desinstalar: **no es un respaldo externo**; eso corresponde a T07.

Ruta observada en el emulador Android: `/data/user/0/com.mired.offline/files/mi_red.sqlite`; no debe fijarse a mano, siempre se obtiene con `path_provider`.

`databaseProvider` entrega una instancia por `ProviderScope`. Los providers de los cinco servicios comparten esa instancia y su cierre se inicia al destruir el scope. `AppDatabase.close()` es idempotente y puede esperarse para asegurar que la conexión terminó. Las pruebas en memoria y fichero esperan explícitamente el cierre; el smoke Android también espera el cierre después de desmontar la app.

T01 todavía no consume estos servicios. No se ejecuta conciliación automática desde los placeholders. Al integrar los flujos en T03/T04, usar los providers existentes y conciliar al abrir/volver al primer plano y antes de mostrar cobros; ninguna tarea de fondo es fuente de deuda.

## Esquema y migraciones

`schema.drift` define las cinco tablas, sus CHECK, FK con borrado restringido, índices y triggers. `PRAGMA foreign_keys = ON` se ejecuta al abrir cada conexión. El esquema inicial y el singleton se crean en una transacción; el único registro inicial es `app_settings(id=1)`.

`schemaVersion = 1`. No hay tablas previas que migrar desde T01. Las aperturas posteriores preservan datos. Una versión distinta sin una migración implementada produce un error; no se borran/recrean tablas ni se resetea la base.

Para una futura versión: conservar el snapshot v1 sin modificar, cambiar el esquema, incrementar `schemaVersion`, implementar `onUpgrade` con pasos incrementales y transacciones, exportar el nuevo snapshot y probar la migración con datos de la versión anterior. El snapshot contiene también índices y triggers. Ver la [guía de exportación de esquemas](https://drift.simonbinder.eu/migrations/exports/).

## Fechas, dinero e identificadores

- `LocalDate`: fecha local de calendario, sin hora/zona. Serializa `YYYY-MM-DD`; valida el calendario gregoriano sin sumar duraciones ni usar UTC para determinar períodos. `LocalDate.fromDateTime` convierte primero el instante a hora local del equipo.
- `BillingPeriod`: `YYYY-MM`. `currentPeriod(today)` recibe explícitamente la fecha. Día 30 abre el período siguiente; el 31 sigue dentro de ese período. Febrero abre el siguiente período el 28/29. Diciembre 2026: apertura 2026-11-30, candidatura 2026-12-03.
- `created_at`, `updated_at`, `archived_at`, `paid_at`, `voided_at`, `last_backup_at`: **INTEGER de milisegundos desde Unix epoch**, independientes de zona. Se aceptan `DateTime` en los servicios; no se derivan las fechas de facturación de esos instantes. Se puede inyectar `recordedAt` en operaciones con auditoría.
- Importes: `int` en unidades menores, con CHECK SQL que exige valor entero no negativo. No se convierte moneda.
- IDs: texto estable aleatorio de 128 bits para clientes, dispositivos y pagos; los servicios admiten un ID explícito. Los cargos usan el ID determinista `clientId:YYYY-MM`, además del UNIQUE cliente/período.

## Servicios y decisiones conservadoras

`ClientService`, `DeviceService`, `BillingService`, `PaymentService` y `SettingsService` son clases concretas; no hay repositorios genéricos ni otra DI. Los métodos de consulta devuelven filas Drift o resultados pequeños, sin depender de widgets.

1. El alta activa crea el primer cargo del período vigente en la misma transacción. No hay prorrateo ni cargos anteriores al período de alta. Un alta inicialmente suspendida/archivada no genera cargos.
2. Solo `clients.status = active` es elegible para cargos nuevos. Suspender/archivar mantiene todos los cargos y pagos. El estado de cobro es derivado y nunca altera el servicio real.
3. `clients.billing_start_period` guarda el primer período del último intervalo activo. Al reactivar se fija al vigente, sin retroceder a un período anterior al ancla existente si el reloj retrocede. Así se evita facturar el intervalo archivado/suspendido. Repetir `active → active` no mueve el ancla.
4. La conciliación abarca desde esa ancla hasta el vigente, en una transacción para todos los clientes activos. Consulta los períodos existentes e inserta solo los faltantes, sin hacer UPDATE de cargos/pagos ni ignorar errores SQL. Los errores revierten toda la conciliación.
5. Antes de cambiar tarifa o abandonar el estado activo, se concilian los períodos aplicables pendientes con la tarifa anterior, dentro de la misma transacción. Esto cierra el intervalo elegible y evita aplicar una tarifa nueva a meses omitidos. Si ese paso falla, tampoco se cambia la tarifa/estado. No se reconstruyen períodos del intervalo inactivo.
6. La cuota se copia al generar cada cargo. Una tarifa cambiada afecta únicamente cargos generados después del cambio; nunca reescribe los existentes, pagados o no. La edición confirmada de un cargo vigente no pagado corresponde a T04; no se expone todavía. Un cargo con pago activo está protegido también en SQL.
7. `PaymentService.register` exige un cargo existente e importe exacto, incluso para cuota cero. Un índice único parcial impide dos pagos sin anular; un trigger SQL comprueba el importe. `voidPayment` solo escribe `voided_at` y permite luego un pago nuevo. Los campos históricos del pago son inmutables por trigger. No se expone borrado de clientes con historial ni de registros financieros.
8. `chargesForPeriod`, `historyForClient`, historiales de pagos y `clientHasOverdueDebt` permiten consultas sin UI. La deuda vencida considera cualquier período, incluso si el actual está pagado o el cliente archivado. Los estados usan la fecha local inyectada.
9. `PeriodSummary.activeClients` cuenta el servicio activo actual. Los cargos, pagos y recaudación del período incluyen historial de clientes archivados/suspendidos y excluyen pagos anulados. `pendingCharges` cuenta solo el estado pendiente previo al día 3; `suspensionCandidateCharges` cuenta los vencidos y `unpaidCharges` suma ambos.
10. Ajustes iniciales: negocio `Mi Red`, moneda vacía (sin asumir país/moneda), prefijo telefónico nulo, avisos desactivados, último respaldo nulo. Guardar una etiqueta es solo formato, sin conversiones ni modificación de importes.

Los dispositivos aceptan MAC vacía o normalizada a `AA:BB:CC:DD:EE:FF`. Se permiten dispositivos ilimitados y MAC repetidas: `DeviceWriteResult.hasDuplicateMac` informa la advertencia que podrá presentar T03. Todos los fixtures son sintéticos.

## Pruebas

`flutter test` incluye las siete pruebas T01, quince de calendario/estado y veinticuatro de BD/servicios. Cubre cortes 30/3, 31/12, febrero normal/bisiesto, cuotas distintas/cero, altas tardías, meses sin uso, reloj hacia atrás, duplicados y concurrencia, tarifas, archivo/reactivación, deuda anterior, pagos/anulaciones/reemplazo, resumen, MAC, restricciones SQL, FK inválidas y rollback de operaciones anidadas. El trigger de importe exacto se aplica a pagos activos: los anulados conservan sus importes históricos aunque un cargo impagado se corrija explícitamente en el futuro.

Las pruebas de negocio usan SQLite real en memoria. La prueba de fichero crea un directorio temporal exclusivo, cierra y reabre la conexión, comprueba clientes/dispositivos/cargos/pagos/ajustes y el ancla de reactivación, repite conciliación y verifica `foreign_key_check` e `integrity_check` antes de limpiar su propio directorio. El smoke Android abre la BD privada nativa y recorre las cuatro pantallas, sin introducir clientes en el emulador.

## Resultados de esta iteración (27-10-2026)

- Generación Drift y export del snapshot v1: correctos, sin warnings finales del generador.
- `dart format .`: correcto, 28 archivos Dart; `flutter analyze`: sin incidencias.
- `flutter test`: **46 pruebas aprobadas** (7 T01 + 15 calendario + 24 BD/servicios).
- `flutter build apk --debug`: correcto para `lib/main.dart`; SQLite nativo incluido para ARM, ARM64 y x86_64. No se configuró firma de distribución.
- APK normal instalado y arrancado en frío en el emulador Android 15/API 35: actividad activa, proceso vivo y sin errores Flutter/AndroidRuntime observados.
- Los runners `flutter test integration_test/...` y `flutter drive` no completaron el test: `Failed to start Dart Development Service`, `VmServiceDisappearedException` / `Service connection disposed` y desconexiones ADB `device offline`, incluso con `--no-dds`. No se registra esa prueba automatizada como aprobada. Reintentar tras un cold boot del AVD y revisar la conexión ADB; alinear Android Studio/Command-line Tools si persiste el aviso SDK XML 3/4 observado durante la primera compilación.
- Para comprobar SQLite nativo se ejecutó `tool/database_smoke.dart` como entrada de diagnóstico: abrió/cerró/reabrió la BD privada, comprobó ajustes, versión, FK e integridad y emitió **`MI_RED_SQLITE_SMOKE_OK`** en Android. No inserta ni registra datos de clientes. El diagnóstico tuvo un timeout del comando `am start -W` al esperar el dibujo inicial, pero completó las verificaciones SQLite y emitió el marcador; el arranque del APK normal se comprobó aparte.

Reproducir el diagnóstico en un emulador de pruebas:

```powershell
flutter build apk --debug --target=tool/database_smoke.dart --target-platform=android-x64
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -n com.mired.offline/.MainActivity
adb -s emulator-5554 logcat -d -s flutter
```

Esperar el marcador fijo `MI_RED_SQLITE_SMOKE_OK`. Después generar de nuevo `flutter build apk --debug` para entregar el APK normal; la entrada de diagnóstico y el APK de integración no son la aplicación de entrega. Los runners de integración pueden desinstalar su app al finalizar: ejecutarlos solo en un dispositivo/emulador de pruebas.

Pendientes: completar el runner Android automatizado en un entorno ADB/VM estable y validar en teléfono real. La integración visual y formularios corresponden a T03; no se implementaron T03–T08.
