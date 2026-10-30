# Mi Red

Desarrollado por **CoreX4Dev** · [https://corex4dev.com](https://corex4dev.com).

App Flutter para Android y un único administrador de una red local. Están implementadas T01–T07: persistencia, clientes/dispositivos, **Cobros, pagos e historial**, **Inicio operativo**, WhatsApp/reportes, recordatorios locales y **copias cifradas con restauración completa**. La Fase A incorpora Mi negocio, corrección de cargo vigente impagado y recaudación en Inicio. Ajustes permite editar negocio, activar/probar avisos y crear/restaurar copias mediante el selector Android. Ver [persistencia T02](docs/T02_PERSISTENCE.md), [migración/IP T03.2](docs/T03_2_IP_DEVICES.md), [informe T04](docs/T04_BILLING_UI_REPORT.md), [informe T05](docs/T05_DASHBOARD_REPORT.md), [informe T06](docs/T06_COMMUNICATIONS_REPORT.md), [informe T07](docs/T07_BACKUP_RESTORE_REPORT.md) e [informe Fase A](docs/FINAL_PHASE_A_REPORT.md).

**T03.3 — Sistema visual:** Forui 0.27.7, Inter local, iconos Lucide y paleta slate/teal compartida con los controles Material existentes. Navegación y tarjetas Forui, campos compactos, filtros contraíbles y copia explícita de IP. Tema según el sistema, sin bloquear el tamaño de texto. Se mantiene la edición Material para preservar foco/controladores; no ejecutar `forui init` sobre la app. Ver [decisiones, pruebas y capturas reales](docs/T03_3_DESIGN_SYSTEM_REPORT.md).

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

Salida: `build/app/outputs/flutter-apk/app-debug.apk`, firmado con la clave debug local. Funciona como APK independiente; no necesita `flutter run` ni DevFS para abrirse. Se necesita conexión para descargar SDK/dependencias durante la preparación; la gestión de Clientes y SQLite funcionan offline. T06 declara notificaciones y recepción del reinicio para los recordatorios opcionales; solicita permiso de notificaciones solo al activarlos en Android 13+. Los manifiestos debug/profile conservan INTERNET para las herramientas de desarrollo de Flutter.

Cobros también funciona offline. Elige el mes con las flechas o vuelve al período actual con el icono de calendario. El resumen corresponde al período completo; búsqueda y filtros afectan al listado. Toca un cargo para abrir el historial, o entra por «Cobros e historial» en la ficha de Cliente. «Registrar pago» confirma el importe histórico completo y permite nota opcional. «Anular pago» requiere confirmación y conserva el registro original. El estado del servicio se edita manualmente en Clientes: un cargo candidato a suspensión no corta el servicio. Pagar una mensualidad no liquida otras deudas anteriores.

Inicio funciona offline y usa el período abierto por T02, que puede ser el mes siguiente desde el día 30 o el último día válido. «Clientes activos» cuenta el estado manual; «Pagados», «Pendientes» y «Por cobrar» corresponden solo al período mostrado y coinciden con Cobros, incluido historial archivado/suspendido. «Requieren revisión» cuenta clientes distintos actualmente activos con algún cargo candidato impagado, incluso antiguo; muestra los cinco con deuda más antigua y el total real. Abre su historial para revisarlos: no se suspende ni paga automáticamente. «Ver pendientes» abre el período actual de Cobros con Pendientes aplicado. «Actualizar Inicio» vuelve a conciliar mediante T02; también se actualiza al arrancar, reanudar y volver a Inicio.

En «Cobros e historial» de un cliente, un cargo sin pagar ofrece «Recordar por WhatsApp». Revisa el mensaje y el importe histórico, introduce un número internacional explícito (por ejemplo, `+12025550123`, sintético) y pulsa abrir, copiar o compartir. El número editado es temporal. Abrir una aplicación o elegirla en el panel de compartir no confirma envío ni entrega; WhatsApp requiere conectividad para enviar. La app no envía mensajes automáticamente.

En Cobros, «Compartir listado» permite elegir explícitamente entre todo el período y la vista filtrada. Revisa la previsualización antes de copiar o abrir el panel del sistema. Incluye nombre, período, importe, estado y totales; no incluye números, direcciones, MAC, IP ni notas.

En Ajustes, Recordatorios empieza desactivado. Activarlo pide permiso cuando corresponde y prepara avisos locales genéricos para los días 2 y 3, aproximadamente a las 09:00 de la zona horaria del dispositivo, durante seis meses calendario. No requieren internet ni alarmas exactas; Android puede retrasarlos. Se renuevan al abrir/reanudar y se restauran tras reiniciar. «Probar notificación» genera un aviso inmediato únicamente al pulsarlo; tocarlo abre Cobros actuales con Pendientes. Desactivar cancela los avisos de Mi Red. No alteran deudas ni suspenden servicios. Si Android revoca el permiso, la app lo refleja al reanudar y habrá que activarlos otra vez.

Para actualizar una instalación de pruebas conservando su BD y firma:

```powershell
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
```

No desinstalar ni borrar datos para aplicar una migración. Sustituir el ID por el dispositivo correspondiente. El fallo de arranque reportado en teléfono sigue sin diagnóstico: no hay teléfono físico conectado. Capturar `adb -s <id> logcat -d -b crash` y el resultado de `am start -W` para distinguir fallo de instalación, cierre del proceso y fallo de conexión del depurador.

## Mi negocio, corrección de importes y recaudación (Fase A)

En Ajustes → **Mi negocio** se editan nombre (1–120 caracteres), etiqueta de moneda (0–48) y prefijo opcional (`+` y 1–3 dígitos, sin cero inicial). Se recortan espacios exteriores; nombre/moneda deben ocupar una sola línea. La etiqueta vacía muestra solo el número, igual que antes. Cambiarla actualiza los rótulos en las vistas, confirmaciones y textos T06 sin convertir ni modificar cantidades. El prefijo es informativo: nunca se añade automáticamente a números locales para WhatsApp. Guardar estos campos conserva los avisos y la fecha de última copia. T07 ya los incluye y restaura.

Desde Cobros → historial del cliente → mensualidad vigente sin pago activo → **Corregir importe**, introduce el nuevo importe con coma o punto decimal, revisa importe actual/nuevo y confirma. La operación verifica de nuevo período, ausencia de pago activo e importe original dentro de una transacción; una confirmación obsoleta se rechaza. No cambia la tarifa del cliente, fechas, estado del servicio ni pagos anulados. El esquema v2 no guarda una bitácora de correcciones; los pagos sí mantienen su auditoría. La conciliación conserva el importe corregido.

Inicio muestra **Recaudado este período**: suma de pagos vigentes del período abierto que ya calcula Cobros. Excluye anulados y otros períodos, aunque el cliente tenga deuda anterior, esté archivado o haya cambiado su tarifa.

La Fase A no incluye la reorganización de Ajustes, apariencia, identidad visual, splash o «Acerca de» de la Fase B. El alcance y la validación se detallan en [FINAL_PHASE_A_REPORT.md](docs/FINAL_PHASE_A_REPORT.md).

## Crear y recuperar copias

En Ajustes → **Copias de seguridad** → Crear copia, define y confirma una contraseña de al menos 12 caracteres. Pulsa **Cifrar y elegir destino**, elige un documento (por ejemplo Descargas, Documentos o SD) y espera la confirmación con nombre, fecha y destino. Cancelar o fallar el guardado no registra éxito. El archivo `.miredbk` está cifrado con AES-256-GCM y contraseña derivada con PBKDF2-SHA256 (250000 iteraciones); contiene todos los clientes, equipos/IP/MAC, mensualidades, pagos/anulados/auditoría y ajustes. No incluye permisos ni alarmas del sistema.

**Olvidar la contraseña impide recuperar esa copia.** Mi Red no guarda la contraseña ni dispone de servidor de recuperación. Guarda la contraseña separada y conserva otra copia del archivo fuera del teléfono: una única copia en el mismo equipo no protege contra pérdida o avería.

Para recuperar, incluso después de reinstalar: Ajustes → Restaurar copia → seleccionar `.miredbk` → contraseña → **Comprobar copia**. Revisa fecha, versión y cantidades frente a la base actual; marca la aceptación y pulsa **Reemplazar datos**. Esto sustituye TODOS los datos, sin fusionarlos. El archivo se autentica/valida antes de permitir el reemplazo; un error durante la transacción conserva la base anterior. El documento original no se borra. Al finalizar, vuelve a Inicio y revisa Clientes/Cobros.

Una copia antigua recupera su historial exacto; la conciliación posterior puede generar mensualidades aún no existentes según las reglas habituales, sin reescribir pagos. Los recordatorios se reconstruyen según el permiso real y la zona del dispositivo; si Android falla después del commit, se informa que los datos se restauraron y que hay que revisar los avisos en Ajustes. No se importa ningún permiso.

Formato 1 compatible con SQLite v2: todas las columnas son obligatorias, incluida IP nullable. No se admiten JSON sin cifrar, archivos antiguos sin IP ni versiones futuras; no hubo un formato de backup anterior implementado. Límite: 16 MiB de payload y 100000 registros totales. La fecha de última copia se actualiza después del guardado externo; el snapshot conserva el valor previo de ese ajuste y restaurarlo recupera ese valor. [Formato, seguridad, pruebas y límites](docs/T07_BACKUP_RESTORE_REPORT.md).

## Verificación

```powershell
dart format .
flutter analyze --no-pub
flutter test --concurrency=1 --reporter expanded
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

Versionar los dos snapshots y los helpers generados; nunca sustituir el v1 por el actual. T07 incluye IP/NULL en las copias cifradas y no modifica esta migración.

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
    communications/
    reminders/
    backups/
test/
  widget_test.dart
```

Nombre Dart: `mi_red`. Nombre visible: **Mi Red**. Application ID y namespace Android: **`com.mired.offline`**. Mantener este ID en futuras actualizaciones.

Riverpod administra el ciclo de vida de `GoRouter` mediante un provider manual y `ProviderScope`; no hay codegen. `ShellRoute` comparte una única barra inferior. Los placeholders son desplazables y usan iconos/fuentes locales. Las rutas desconocidas muestran un mensaje en español y permiten volver a Inicio, sin exponer detalles técnicos.

Dependencias directas añadidas: [`flutter_riverpod 3.4.3`](https://pub.dev/packages/flutter_riverpod/versions/3.4.3), [`go_router 18.1.1`](https://pub.dev/packages/go_router/versions/18.1.1) y `flutter_localizations` del SDK para los textos Material en español. Se elimina `cupertino_icons` por no utilizarse. Conservar `pubspec.lock` en control de versiones para reproducir la resolución.

`core/database` contiene Drift/SQLite, conexión nativa, esquema y providers; los servicios concretos residen en las carpetas `data/` de cada feature. `features/communications` prepara mensajes/reportes y adapta abrir/copiar/compartir; `features/reminders` planifica los avisos y adapta las notificaciones Android. T06 añade `url_launcher 6.3.3`, `share_plus 13.3.1`, `flutter_local_notifications 22.3.3`, `flutter_timezone 5.1.1` y `timezone 0.11.2`; versiones y requisitos comprobados en el [informe T06](docs/T06_COMMUNICATIONS_REPORT.md). `features/backups` separa snapshot/validación, cifrado, transacción y adaptador SAF de la UI; añade `cryptography 2.9.0`, `cryptography_flutter 2.3.4` y `flutter_file_dialog 3.3.3`, sin upgrades del stack ni permisos globales de almacenamiento. No hay servicios remotos.

## Firma y custodia (T08)

La firma de distribución se configurará en T08; release no reutiliza la clave debug. No se ha generado ni incluido un keystore de distribución. Al preparar la entrega final, generar la clave **fuera del repositorio** siguiendo la [guía oficial de firma Android de Flutter](https://docs.flutter.dev/deployment/android#sign-the-app). Ejemplo PowerShell, usando una ruta externa dedicada y dejando que `keytool` solicite las contraseñas:

```powershell
keytool -genkeypair -v -keystore C:\MiRedSigning\mi-red-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias mi-red
```

Crear primero esa carpeta fuera del proyecto. Guardar la clave y sus contraseñas en ubicaciones seguras separadas y mantener una copia recuperable: la misma clave y application ID permiten actualizar la instalación. No añadir contraseñas a comandos, documentación ni Git. `.gitignore` excluye `*.jks`, `*.keystore` y `key.properties`. No distribuir el APK debug como entrega final.

## Alcance siguiente

Fuente de verdad: [producto](docs/PRODUCT_SPEC.md), [modelo](docs/DATA_MODEL.md), [plan](docs/IMPLEMENTATION_PLAN.md) y [normas](AGENTS.md).

La Fase A cierra Mi negocio, corrección de cargo vigente impagado y recaudación en Inicio. La siguiente fase prevista es **B — Ajustes, apariencia, identidad, splash y Acerca de**, que requiere nueva instrucción. QA final/firma de distribución y validación en el teléfono objetivo siguen pendientes; no se inicia T08 en esta entrega. La guía [T02_PERSISTENCE.md](docs/T02_PERSISTENCE.md) conserva el contexto histórico de v1; la migración actual se describe en [T03_2_IP_DEVICES.md](docs/T03_2_IP_DEVICES.md).

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

**95 pruebas aprobadas**, conservando las 90 anteriores. Formato y análisis limpios; builds debug/release correctos, release todavía sin firma. Debug instalado con `adb install -r` y arrancado en frío, sin borrar la BD v2. Datos/servicios/migraciones siguen intactos. Se comprobó la UI real a 320 dp, ambos temas y teclado completo; 320/400 dp y texto al 200 % se verifican además por widget tests. [Informe y siete capturas](docs/T03_3_DESIGN_SYSTEM_REPORT.md).

T03.1 sigue sin informe independiente ni cierre retrospectivo de su aceptación; el teléfono físico y DevFS/DDS no se declaran verificados. No se implementó T04.

## Resultado de validación T04 (29-10-2026)

**119 pruebas aprobadas** (95 anteriores + 24 nuevas); `dart format .` y `flutter analyze --no-pub` correctos. Builds Debug y Release correctos; `apksigner verify` aprueba Debug y rechaza Release sin firma. SQLite permanece en v2, sin migraciones ni dependencias nuevas. El [informe T04](docs/T04_BILLING_UI_REPORT.md) detalla el recorrido API 35, fixture sintética, capturas, auditoría y límites de aceptación. T05 no se inicia.

## Resultado de validación T05 (29-10-2026)

**145 pruebas aprobadas** (119 anteriores + 26 nuevas), formato y análisis limpios, builds Debug/Release correctos. Inicio reutiliza las cifras T04 y una cola de revisión transaccional de lectura. Actualización, pago y navegación offline comprobados con el APK normal en un **AVD API 35 dedicado**, con datos exclusivamente sintéticos; SQLite y el pago se conservan mediante `adb install -r`. El AVD poblado original queda intacto. [Arquitectura, comandos y cuatro capturas](docs/T05_DASHBOARD_REPORT.md). Release continúa sin firma de distribución; teléfono físico y DDS/DevFS siguen pendientes. No se implementa T06.

## Resultado de validación T06 (29-10-2026)

**180 pruebas aprobadas** (145 anteriores + 35 nuevas), `dart format .` correcto (71 archivos, 0 cambios), `flutter analyze` sin incidencias y `git diff --check` correcto. Builds Debug (15,1 s) y Release (173,1 s) completos; Release conserva su estado sin firma de distribución. No cambia el esquema v2 ni el motor financiero.

En el AVD API 35 dedicado: actualización sin perder SQLite, permisos denegado/concedido, mensaje editable, reporte completo/filtrado, panel nativo cancelado sin afirmar envío, aviso visible y apertura fría/con app activa hacia Cobros/Pendientes. Reiniciar recuperó 10 alarmas y desactivar dejó 0 pendientes/0 alarmas activas. Huella contable y demás ajustes preservados; integridad/FK correctas. El AVD original no se modificó. WhatsApp real, teléfono físico y DDS/DevFS quedan pendientes. [Versiones, archivos, comandos, capturas y límites](docs/T06_COMMUNICATIONS_REPORT.md). T06 termina aquí; no se inicia T07/T08.

## Resultado de validación T07 (30-10-2026)

**230 pruebas aprobadas** (180 anteriores + 50 nuevas), formato de 83 archivos sin cambios, análisis limpio y `git diff --check` correcto. Debug (94,4 s) y Release (169,8 s, 63,5 MB) compilados; Debug tiene firma válida, Release sigue sin firma de distribución. SQLite permanece en v2 y no cambian los servicios financieros ni la configuración Android.

En un AVD API35 exclusivo y con datos sintéticos, el archivo cifrado se guardó mediante SAF en Descargas y se abrió desde el selector para autenticar/restaurar. Cancelaciones, contraseña incorrecta y corrupción conservaron las cinco tablas. Reemplazar datos modificados y recuperar tras desinstalar/reinstalar restauró exactamente todas sus filas y campos, con integridad/FK correctas y 10 avisos reconstruidos usando permiso real. El documento externo sobrevivió a la desinstalación; no se publica su contraseña ni el archivo.

El AVD mostró problemas de System UI/renderizado al reanudarse; la QA final usó temporalmente Skia mediante un extra de lanzamiento, sin cambiar el APK. Eso no acredita el arranque predeterminado ni el teléfono físico. El [informe T07](docs/T07_BACKUP_RESTORE_REPORT.md) incluye resultados, capturas y una sección **«Qué falta para terminar la aplicación»**: configuración del negocio, edición confirmada de cargo vigente impagado, recaudación en Inicio y validación/firma/guías finales de T08. Esos pendientes no se implementaron en T07.

## Resultado de validación Fase A (30-10-2026)

**271 pruebas aprobadas** (230 anteriores + 41 nuevas), formato de 89 archivos sin cambios y análisis limpio. Debug compiló en 59,7 s; Release en 147,9 s (63,8 MB), todavía sin firma de distribución. No cambia schema v2, dependencias, criptografía T07 ni configuración Android.

El APK normal se instaló mediante `adb install -r` en el AVD sintético dedicado: SQLite conservó exactamente las cinco tablas y su archivo cerrado. Mi negocio persistió solo sus preferencias. La corrección explícita cambió un cargo vigente sin tocar tarifa/servicio/pagos previos; Inicio mostró la recaudación correcta al pagar y volvió a cero al anular. Hay capturas reales en ambos temas en el [informe de Fase A](docs/FINAL_PHASE_A_REPORT.md), junto con archivos, comandos y los pasos restantes de Fase B.

El arranque predeterminado del AVD volvió a mostrar un ANR de System UI; la QA funcional utilizó el extra temporal de Skia sobre el mismo APK. El último reinicio con Skia conservó SQLite pero seguía en carga al capturar, con timeout de lanzamiento. Arranque fiable, teléfono físico y DDS/DevFS no se declaran solucionados. Fase B, QA final y firma quedan para nuevas instrucciones.
