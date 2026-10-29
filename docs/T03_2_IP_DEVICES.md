# T03.2 — IP por dispositivo

Fecha: 28-10-2026. Alcance exclusivo: dirección IP opcional por dispositivo y migración SQLite v1 → v2. No se implementan T04–T08, conexiones de red ni cambios de reglas financieras.

## Funcionalidad y decisiones

- Formulario de dispositivo: IP opcional junto a MAC, precargada al editar, validación en español y teclado de texto que admite `.` y `:`; sin autocorrección/sugerencias. El borrador participa en la confirmación de salida.
- IP y MAC son independientes. Se puede crear un dispositivo solo con IP, solo con MAC o sin ambas. Se conserva la validación y advertencia de MAC duplicada. No hay unicidad de IP ni asignación automática.
- `normalizeIpAddress` recorta espacios, acepta IPv4/IPv6 numérica mediante `InternetAddress.tryParse` y reconstruye su representación desde los bytes con `InternetAddress.fromRawAddress(...).address.toLowerCase()`. No hace DNS ni abre sockets. IPv6 se conserva como IPv6 y se comprime/canoniza; no se convierte a un entero.
- Se rechazan hostnames, puertos, CIDR, corchetes, identificadores de zona e IPv4 abreviada/con ceros iniciales. Una cadena como `fe80::1:8080` es una IPv6 válida, no se interpreta como dirección más puerto.
- `DeviceService.save(ipAddress: Value(...))` valida también fuera de la UI. `Value.absent()` conserva la IP existente; `Value(null)`, `Value('')` o espacios la borran explícitamente. El formulario siempre envía el valor del controlador. No hay un segundo estado ni una segunda BD.
- La ficha solo muestra IP si existe; `SelectableText` permite copiar con el menú nativo tras mantener pulsado. No se agregan dependencias ni permisos.
- Se conserva la interfaz compacta de T03.1: cabecera única en Clientes, filtros contraíbles, búsqueda y navegación. Inicio, Cobros y Ajustes siguen siendo provisionales.

Referencia de la API numérica: [Dart InternetAddress.tryParse](https://api.dart.dev/dart-io/InternetAddress/tryParse.html).

## Migración y preservación

`schemaVersion = 2`. El único cambio SQL es `devices.ip_address TEXT NULL`, añadido al final de la tabla. Una base nueva crea directamente v2 y los mismos ajustes iniciales seguros de T02. Para una base v1, `Migrator.addColumn` se ejecuta en una transacción seguida de `PRAGMA foreign_key_check`. Un fallo revierte la columna; no se borran ni recrean tablas. La versión se actualiza mediante Drift. Reabrir una BD v2 no repite el ALTER.

No se cambian clientes, cargos, pagos, anulaciones, fechas, importes, elegibilidad, reconciliación, FK, índices ni triggers existentes. No se modifica el servicio de facturación. La columna nueva queda NULL en todos los dispositivos previos.

Se conservan ambos snapshots. SHA-256 del v1, idéntico antes/después:

```text
B7315057014E889F8B5D7356A0769E07DAC0758697B875E70EA6241D6A7E103A
```

Las utilidades de `test/generated_migrations/` se generan con Drift. Las pruebas verifican el esquema migrado contra el snapshot v2, incluyendo restricciones, índices y triggers. [Guía oficial de pruebas de migración Drift](https://drift.simonbinder.eu/migrations/tests/).

## Archivos de esta iteración

- `lib/core/database/schema.drift`, `app_database.dart`, `app_database.g.dart`: columna, versión y migración; generado regenerado.
- `drift_schemas/drift_schema_v2.json`, `test/generated_migrations/`: snapshot nuevo y helpers de v1/v2. El snapshot v1 no se modifica.
- `lib/features/clients/data/device_service.dart`: normalización y escritura opcional con semántica ausente/NULL.
- `lib/features/clients/device_form_screen.dart`, `client_detail_screen.dart`: formulario y lectura/copia de IP.
- `test/core/database/ip_migration_test.dart`, `test/features/clients/device_ip_test.dart`, `client_widgets_test.dart`: pruebas nuevas y matriz de teclado ampliada. En `business_database_test.dart` solo cambia la expectativa de versión actual de 1 a 2 y su descripción.
- `tool/database_smoke.dart`: comparar versión con la actual; `tool/device_ip_smoke.dart`: diagnóstico Android optativo.
- `README.md`, documentos de producto/modelo/plan y este informe. `.gitignore` permite versionar únicamente los tres documentos fuente solicitados; otros contenidos de `docs/` siguen excluidos.

El árbol recibido contenía cambios T03/T03.1 sin commit en rutas, shell, tema, servicios de clientes/ajustes y pruebas. Se conservaron; no deben atribuirse todos los cambios frente al commit T02 a T03.2. No se hicieron commits ni se modificaron `pubspec.yaml`, lockfile, applicationId, minSdk o firma.

## Pruebas y comandos

Validación previa a migrar: `flutter analyze` limpio, `flutter test` **82 aprobadas**, `flutter build apk --debug` correcto. Esto confirma el estado real de T03.1, cuya última entrega había quedado interrumpida.

```powershell
dart run build_runner build
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
dart format .
flutter analyze
flutter test
flutter build apk --debug
flutter build apk --release
```

Pruebas actuales: **90 aprobadas** (82 existentes + 3 migración + 3 IP/servicio/persistencia + 2 widget). La matriz existente de 320/400 dp, 100/200 %, temas y teclado ahora también escribe IP y comprueba que el controlador no se sustituye al reconstruir.

Resultados finales: generación Drift y export/helper correctos; `dart format .` procesa 43 archivos; `flutter analyze --no-pub` sin incidencias; suite completa de 90 pruebas repetida y aprobada después del último ajuste de fixtures. Build debug normal correcto; build release correcto con la limitación de firma descrita a continuación.

Evidencia de preservación de archivo v1: se crea con el helper del snapshot histórico, sin columna IP; contiene un cliente con todos sus datos, dos dispositivos con MAC/notas, dos cargos con importes distintos, un pago vigente, otro anulado y ajustes no predeterminados. La prueba migra el archivo y lo reabre tres veces, comparando todos los valores antiguos, las definiciones de los otros elementos SQL, versión, columna nullable, `foreign_key_check` e `integrity_check`. Otra prueba provoca una FK huérfana y verifica rollback a v1 sin columna nueva.

Se cubren IPv4/IPv6, formatos inválidos, duplicados entre clientes distintos, IP sin MAC, edición de MAC/tipo/notas conservando IP, edición/eliminación explícita de IP y persistencia en archivo tras cierre/reapertura. Los errores UI son españoles y no guardan el dispositivo inválido.

Un primer intento de suite no cargó el archivo widget por consultar `keyboardType` en `TextFormField`; se corrigió para inspeccionar su `TextField` interno y se repitió la suite completa satisfactoriamente. Un comando auxiliar `dart fix` y un análisis adicional dejaron de responder y se cancelaron; no constituyen verificaciones aprobadas.

Release compilado, pero **sin firma**: `apksigner verify --verbose .../app-release.apk` devuelve `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`. Gradle no configura firma release. No es un APK de distribución instalable; no se generó ni guardó keystore ni se cambió la firma. Para una prueba release instalable se requiere configurar una clave autorizada, fuera de Git, como parte de la preparación de firma. Debug sigue firmado con la clave local existente y puede abrirse independientemente de DevFS.

Warnings observados: SDK XML 3/4 en build previo; release avisa de fuente Cupertino no incluida, aunque esta app utiliza iconos Material y la compilación termina. No se añadieron fuentes/dependencias ni se modificó SDK/AVD para ocultarlos.

## Smoke Android API 35

Estado inicial comprobado con ADB sobre `MiRed_API35`: BD preexistente `user_version = 1`, un cliente y un dispositivo; sin violaciones FK. Se arrancó el AVD existente conservando su disco/configuración. No se desinstala ni borra la BD.

**EJECUTADO y aprobado sobre la instalación preexistente**, mediante ADB y diagnóstico nativo (no prueba visual manual ni fresh install):

- `adb install -r` conservó package ID, firma y datos. Arranque en frío: `Status: ok`.
- `MI_RED_IP_V1_PRESERVED clients=1 devices=1 charges=1 payments=0 settings=1`: todos los valores de las cinco tablas previas se compararon en memoria antes/después del ALTER. La IP del dispositivo anterior quedó NULL.
- `MI_RED_IP_WRITE_REOPEN_OK`: dispositivo sintético creado mediante los servicios existentes; IP/MAC persistidas tras cerrar/reabrir SQLite.
- Segunda instalación conservando datos, `force-stop` y nuevo arranque en frío: `MI_RED_IP_COLD_RESTART_OK`, con otro PID de proceso. La IP y MAC sintéticas persistieron.
- Verificación externa SQLite: `user_version = 2`, `foreign_key_check` sin filas e `integrity_check = ok`.
- Se vuelve a generar e instalar el APK normal (`lib/main.dart`) al terminar. La fixture sintética queda identificada en el emulador como «Prueba sintética T03.2», suspendida y sin cargos; no forma parte del APK ni se carga en instalaciones normales. Los registros anteriores no se editaron.

La instalación Android previa no tenía pagos, por lo que la preservación de pagos/anulaciones se acredita en la prueba de archivo v1, no en ese AVD. No se guardaron capturas ni valores reales en logs/fixtures. Este smoke evita VM Service/DevFS; no demuestra que la conexión del depurador se haya corregido.

El diagnóstico es optativo y nunca se ejecuta desde `lib/main.dart`. Modo `write` exige un archivo v1 ya existente con clientes/dispositivos; compara todos los datos previos en memoria y verifica IP NULL antes de escribir. Después crea solo un cliente sintético suspendido (sin nuevos cargos) y su dispositivo de prueba con IP de documentación `192.0.2.32`. No toca dispositivos reales ni registra sus valores. Modo `check` exige v2 y comprueba la IP/MAC sintéticas persistidas.

Solo en un emulador de pruebas con v1 preexistente:

```powershell
flutter build apk --debug --target=tool/device_ip_smoke.dart --target-platform=android-x64 --dart-define=MI_RED_IP_SMOKE=write
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
adb -s emulator-5554 logcat -d -s flutter | Select-String 'MI_RED_IP_'
# Después de observar MI_RED_IP_V1_PRESERVED y MI_RED_IP_WRITE_REOPEN_OK:
flutter build apk --debug --target=tool/device_ip_smoke.dart --target-platform=android-x64 --dart-define=MI_RED_IP_SMOKE=check
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
adb -s emulator-5554 logcat -d -s flutter | Select-String 'MI_RED_IP_'
# Observar MI_RED_IP_COLD_RESTART_OK. Restituir siempre la app normal:
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

No ejecutar `write` sobre una BD ya migrada para intentar repetir el caso; falla deliberadamente. Usar `check` para nuevas reaperturas. Los APK de diagnóstico no son entregables.

## Pendientes y límite de alcance

- Teléfono físico: **NO EJECUTADO**, no está disponible. El fallo de arranque reportado por el propietario sigue sin causa confirmada; no se atribuye a Drift ni al APK debug sin logcat.
- Aceptación visual manual completa/teclado físico de T03.1–T03.2: pendiente; las pruebas widget y el smoke nativo no equivalen a esa aceptación.
- Los fallos previos de VM Service/DevFS/DDS no se declaran resueltos; el smoke evita esa infraestructura. Si persisten, recopilar logs específicos del runner sin borrar datos ni cambiar configuración sin consentimiento.
- T07 deberá incluir `ip_address` y NULL en exportación/restauración y definir compatibilidad con archivos anteriores sin IP. Backup no implementado.
- Detenerse en T03.2. T04 requiere nueva instrucción; no se modifica la lógica financiera ni se implementan pantallas de Cobros, Dashboard o integraciones.
