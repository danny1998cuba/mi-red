# Mi Red

App Flutter para Android y un único administrador de una red local. Están implementadas T01, T02 y **T03 — Clientes y dispositivos**, con interfaz compacta T03.1 e **IP opcional por dispositivo T03.2**. Clientes permite buscar, filtrar, crear, editar, archivar/reactivar y gestionar dispositivos con MAC e IPv4/IPv6 independientes. Inicio, Cobros y Ajustes siguen siendo provisionales; T04 no está implementada. Ver [persistencia T02](docs/T02_PERSISTENCE.md) y [migración/IP T03.2](docs/T03_2_IP_DEVICES.md).

**T03.3 — Sistema visual:** Forui 0.27.7, Inter local, iconos Lucide y paleta slate/teal compartida con los controles Material existentes. Navegación y tarjetas Forui, campos compactos, filtros contraíbles y copia explícita de IP. Tema según el sistema, sin bloquear el tamaño de texto. Se mantiene la edición Material para preservar foco/controladores; no ejecutar `forui init` sobre la app. Ver [decisiones, pruebas y capturas reales](T03_3_DESIGN_SYSTEM_REPORT.md).

## Entorno

- Flutter **3.47.8 stable**, Dart **3.13.7** (versiones verificadas el 27-10-2026).
- Android Studio con Android SDK Platform **36**, Build-Tools **36.0.0**, Android SDK Command-line Tools y Platform-Tools. El proyecto conserva Gradle **9.3.1**, AGP **9.1.0** y configuración Kotlin **2.4.0** de la plantilla instalada.
- JDK **17 o compatible con Gradle/AGP**; comprobar el Java efectivo con `flutter doctor -v`.
- Android **7.0 / API 24** como mínimo. `minSdk`, `compileSdk`, `targetSdk` y NDK siguen los valores de Flutter: 24, 36, 36 y 28.2.13676358 en esta versión.
- Un teléfono con depuración USB autorizada o un emulador Android creado desde Device Manager.

Si faltan herramientas, instalar **Android SDK Command-line Tools (latest)** en Android Studio → SDK Manager → SDK Tools. Después ejecutar:

```powershell
flutter doctor --android-licenses
flutter doctor -v
flutter devices
```

Revisar y aceptar personalmente las licencias correspondientes. Si no hay dispositivos, conectar el teléfono o crear y arrancar un AVD desde Device Manager. `android/local.properties` contiene rutas locales; no se comparte en Git.

## Ejecutar

Desde la raíz:

```powershell
flutter pub get
flutter devices
flutter run -d <android-device-id>
```

Para obtener un APK de desarrollo, firmado automáticamente con la clave de depuración local:

```powershell
flutter build apk --debug
```

Salida: `build/app/outputs/flutter-apk/app-debug.apk`, firmado con la clave debug local. Funciona como APK independiente; no necesita `flutter run` ni DevFS para abrirse. Se necesita conexión para descargar SDK/dependencias durante la preparación; la gestión de Clientes y SQLite funcionan offline. El manifiesto principal no solicita permisos. Los manifiestos debug/profile conservan INTERNET para las herramientas de desarrollo de Flutter.

Para actualizar una instalación de pruebas conservando su BD y firma:

```powershell
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
```

No desinstalar ni borrar datos para aplicar una migración. Sustituir el ID por el dispositivo correspondiente. El fallo de arranque reportado en teléfono sigue sin diagnóstico: no hay teléfono físico conectado. Capturar `adb -s <id> logcat -d -b crash` y el resultado de `am start -W` para distinguir fallo de instalación, cierre del proceso y fallo de conexión del depurador.

## Verificación

```powershell
dart format .
flutter analyze
flutter test
```

Las pruebas cubren calendario y finanzas de T02, arranque, rutas, Clientes/dispositivos, filtros contraíbles, errores, formularios, temas claro/oscuro y pantallas de 320–400 dp con texto al 100/200 % y teclado simulado. T03.2 incorpora pruebas de migración real de un archivo v1 con datos e historial, reaperturas, integridad y validación/persistencia IPv4/IPv6. Los datos de prueba son sintéticos.

La aceptación manual completa de T03.1 y el arranque en teléfono físico siguen pendientes. Los resultados actuales y el smoke de actualización Android se distinguen en el [informe T03.2](docs/T03_2_IP_DEVICES.md).

La revisión T03.3 añade un recorrido guiado por ADB sobre API 35 poblado (alta/edición, dispositivos MAC/IPv4/IPv6, copia, filtros, archivo/reactivación y reinicio) y capturas claras/oscuras. No sustituye un informe independiente de T03.1 ni prueba el teléfono físico.

## SQLite v1 → v2 e IP

La BD privada existente `mi_red.sqlite` se migra al abrirla: se añade únicamente `devices.ip_address TEXT NULL`, en transacción y comprobando claves foráneas. No se recrean tablas. Las IP antiguas quedan NULL; cargos, pagos, anulaciones, IDs, MAC y ajustes se conservan. Las nuevas instalaciones crean v2 directamente. El snapshot v1 se mantiene junto al nuevo v2.

La IP es opcional: IPv4 o IPv6 numérica, sin hostname, puerto, CIDR, zona ni corchetes. Se normaliza localmente, sin DNS o conexiones; vaciar el campo borra la IP. La MAC sigue siendo opcional e independiente y conserva su advertencia de duplicados. Se permiten IP repetidas. En la ficha, mantener pulsada la IP para seleccionar/copiar con el menú del sistema. El resto de ediciones conserva el valor precargado.

Regenerar solo después de cambiar el esquema:

```powershell
dart run build_runner build
dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/
dart run drift_dev schema generate drift_schemas/ test/generated_migrations/
```

Versionar los dos snapshots y los helpers generados; nunca sustituir el v1 por el actual. T07 deberá incluir IP en exportación/restauración; todavía no existe backup externo.

## Estructura y decisiones

```text
lib/
  main.dart
  app.dart
  core/
    navigation/       # go_router, contenedor inferior y error de ruta
    theme/            # Material 3 claro/oscuro según el sistema
    design_system/    # Tokens compartidos Forui/Material y componentes visuales
    widgets/          # Placeholder compartido
  features/
    dashboard/
    clients/
    billing/
    settings/
test/
  widget_test.dart
```

Nombre Dart: `mi_red`. Nombre visible: **Mi Red**. Application ID y namespace Android: **`com.mired.offline`**. Mantener este ID en futuras actualizaciones.

Riverpod administra el ciclo de vida de `GoRouter` mediante un provider manual y `ProviderScope`; no hay codegen. `ShellRoute` comparte una única barra inferior. Los placeholders son desplazables y usan iconos/fuentes locales. Las rutas desconocidas muestran un mensaje en español y permiten volver a Inicio, sin exponer detalles técnicos.

Dependencias directas añadidas: [`flutter_riverpod 3.4.3`](https://pub.dev/packages/flutter_riverpod/versions/3.4.3), [`go_router 18.1.1`](https://pub.dev/packages/go_router/versions/18.1.1) y `flutter_localizations` del SDK para los textos Material en español. Se elimina `cupertino_icons` por no utilizarse. Conservar `pubspec.lock` en control de versiones para reproducir la resolución.

`core/database` contiene Drift/SQLite, conexión nativa, esquema y providers; los servicios concretos residen en las carpetas `data/` de cada feature. Las integraciones de WhatsApp, compartir, notificaciones y documentos pertenecen a tareas posteriores. No hay servicios remotos.

## Firma y custodia (T08)

La firma de distribución se configurará en T08; release no reutiliza la clave debug. No se ha generado ni incluido un keystore de distribución. Al preparar la entrega final, generar la clave **fuera del repositorio** siguiendo la [guía oficial de firma Android de Flutter](https://docs.flutter.dev/deployment/android#sign-the-app). Ejemplo PowerShell, usando una ruta externa dedicada y dejando que `keytool` solicite las contraseñas:

```powershell
keytool -genkeypair -v -keystore C:\MiRedSigning\mi-red-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mi-red
```

Crear primero esa carpeta fuera del proyecto. Guardar la clave y sus contraseñas en ubicaciones seguras separadas y mantener una copia recuperable: la misma clave y application ID permiten actualizar la instalación. No añadir contraseñas a comandos, documentación ni Git. `.gitignore` excluye `*.jks`, `*.keystore` y `key.properties`. No distribuir el APK debug como entrega final.

## Alcance siguiente

Fuente de verdad: [producto](docs/PRODUCT_SPEC.md), [modelo](docs/DATA_MODEL.md), [plan](docs/IMPLEMENTATION_PLAN.md) y [normas](AGENTS.md).

T03.2 termina en la gestión de IP y su migración. **No se inicia T04** sin nueva instrucción. Antes de aceptar el uso en producción quedan la revisión manual y el diagnóstico en el teléfono objetivo. La guía [T02_PERSISTENCE.md](docs/T02_PERSISTENCE.md) conserva el contexto histórico de v1; la migración actual se describe en [T03_2_IP_DEVICES.md](docs/T03_2_IP_DEVICES.md).

## Resultado de validación T01 (27-10-2026)

- `flutter --version` / `dart --version`: Flutter 3.47.8 stable / Dart 3.13.7.
- `flutter pub get`: correcto; Riverpod 3.4.3 y go_router 18.1.1 resueltos. Pub avisa de cuatro dependencias transitivas más nuevas fuera de las restricciones actuales; no impide resolver ni probar.
- `dart format .`: correcto, 12 archivos Dart procesados.
- `flutter analyze`: sin incidencias.
- `flutter test`: **7 pruebas aprobadas**.
- `flutter build apk --debug`: correcto, APK generado en `build/app/outputs/flutter-apk/app-debug.apk`. La primera compilación tardó unos 267 segundos, incluyendo la preparación del NDK.
- `flutter doctor -v`: faltan Android SDK Command-line Tools y no puede verificar las licencias. La compilación usa JDK 21.0.11.
- `flutter devices` / `flutter emulators`: no hay dispositivo Android conectado ni emulador disponible. La ejecución en Android y la prueba en modo avión quedan pendientes.
- El SDK contiene Platform 36 y Build-Tools 36.0.0. Gradle instaló **NDK (Side by side) 28.2.13676358** durante la compilación usando una licencia ya aceptada en el equipo. En otro entorno se puede instalar desde SDK Manager; se conserva la versión requerida por Flutter.
- `git status --short`: la carpeta recibida no contiene un repositorio Git (`not a git repository`); no se creó uno ni se hicieron commits.

## Resultado de validación T02 (27-10-2026)

Generación Drift y snapshot v1 correctos; `dart format .` correcto; `flutter analyze` sin incidencias; `flutter test`: **46 pruebas aprobadas**, conservando las 7 de T01. `flutter build apk --debug` generó el APK normal correctamente y se comprobó su arranque en el emulador API 35. Un diagnóstico independiente de SQLite en Android completó apertura/reapertura, versión, FK, integridad y ajustes (`MI_RED_SQLITE_SMOKE_OK`).

El runner de integración Android no completó sus pruebas por desconexiones DDS/VM/ADB; se documentan resultados reales, comandos de diagnóstico y pendientes en [T02_PERSISTENCE.md](docs/T02_PERSISTENCE.md). El repositorio Git ya existe en esta iteración. No se modificaron las pantallas, navegación, tests T01, permisos Android ni archivos de firma.

## Resultado de validación T03.2 (28-10-2026)

Baseline T03.1 confirmado con 82 pruebas. T03.2: **90 pruebas aprobadas**, formato y análisis sin incidencias, APK debug normal compilado. Migración de archivo v1 con clientes, dispositivos, cargos, pago vigente/anulado y ajustes verificada tras tres reaperturas. Smoke API 35 aprobado sobre la BD v1 preexistente, actualizada con `adb install -r`: datos anteriores intactos, IP antiguas NULL e IP sintética persistente tras reinicio en frío. Véase el [informe con archivos y evidencia](docs/T03_2_IP_DEVICES.md).

`flutter build apk --release` compila, pero el APK resultante está **sin firma** y `apksigner verify` falla. Se mantiene la configuración recibida; no instalar/distribuir ese archivo como release válido. Hace falta configurar una clave autorizada fuera de Git para obtener un release instalable. El debug está firmado y no requiere DevFS; el fallo reportado en teléfono y la aceptación visual manual completa siguen pendientes.

## Resultado de validación T03.3 (28-10-2026)

**95 pruebas aprobadas**, conservando las 90 anteriores. Formato y análisis limpios; builds debug/release correctos, release todavía sin firma. Debug instalado con `adb install -r` y arrancado en frío, sin borrar la BD v2. Datos/servicios/migraciones siguen intactos. Se comprobó la UI real a 320 dp, ambos temas y teclado completo; 320/400 dp y texto al 200 % se verifican además por widget tests. [Informe y siete capturas](T03_3_DESIGN_SYSTEM_REPORT.md).

T03.1 sigue sin informe independiente ni cierre retrospectivo de su aceptación; el teléfono físico y DevFS/DDS no se declaran verificados. No se implementó T04.
