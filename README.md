# Mi Red

App Flutter para Android y un único administrador de una red local. Están implementadas **T01 — Bootstrap** y **T02 — Persistencia y motor de cobros**. Inicio, Clientes, Cobros y Ajustes conservan sus pantallas provisionales; la BD y los servicios de negocio se prueban sin interfaz funcional. Ver [guía de persistencia T02](T02_PERSISTENCE.md).

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

Salida: `build/app/outputs/flutter-apk/app-debug.apk`. Se necesita conexión para descargar SDK/dependencias durante la preparación; las cuatro pantallas de T01 funcionan sin internet. El manifiesto principal no solicita permisos. Los manifiestos debug/profile conservan INTERNET para las herramientas de desarrollo de Flutter.

## Verificación

```powershell
dart format .
flutter analyze
flutter test
```

Las pruebas cubren arranque real desde `main`, idioma español, las cuatro rutas y selección inferior, acceso directo a Cobros, recuperación de ruta inválida, temas del sistema claro/oscuro y una pantalla de 320 × 568 con texto al 200 %.

Comprobación manual Android pendiente: arrancar, recorrer las cuatro pestañas, cambiar tema del sistema y repetir en modo avión. No se usan datos de clientes en las pruebas.

## Estructura y decisiones

```text
lib/
  main.dart
  app.dart
  core/
    navigation/       # go_router, contenedor inferior y error de ruta
    theme/            # Material 3 claro/oscuro según el sistema
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

La siguiente iteración propuesta es **T03 — Clientes y dispositivos**: conectar los servicios existentes con formularios/listados y flujos validados. No está implementada. Backup/restauración se probará al implementar T07. La generación Drift, ubicación de la BD, migraciones, reglas y pruebas de T02 se documentan en [T02_PERSISTENCE.md](T02_PERSISTENCE.md).

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

El runner de integración Android no completó sus pruebas por desconexiones DDS/VM/ADB; se documentan resultados reales, comandos de diagnóstico y pendientes en [T02_PERSISTENCE.md](T02_PERSISTENCE.md). El repositorio Git ya existe en esta iteración. No se modificaron las pantallas, navegación, tests T01, permisos Android ni archivos de firma.
