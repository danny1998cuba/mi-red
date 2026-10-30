# Mi Red 1.0 — Informe Fase B

Fecha: 30-10-2026. Alcance exclusivo: Ajustes, apariencia, identidad y splash. Autor visible: **CoreX4Dev** · [corex4dev.com](https://corex4dev.com).

**Estado:** implementación B terminada, 295 pruebas aprobadas y recorrido real verificado en el AVD API35. Debug firmado; Release compilado sin firma. Teléfono físico, aceptación final y distribución permanecen pendientes de C/D.

## Alcance y salvaguardas

Fase A estaba confirmada en `cd57688`; el único material inicial no seguido por Git era `assets/branding/`, suministrado por el usuario y preservado. Se leyeron AGENTS, README, especificación, modelo, plan e informes T07/A. No se hacen commits ni se inician C/D/T08. No se cambian schema v2, tablas, migraciones, motor financiero, MAC/IP, criptografía/restauración ni planificador. No cambian ID de paquete, permisos, firma ni versiones de SDK/Gradle/Kotlin. No hay red al abrir ni fuentes remotas.

## Implementación y archivos

- `lib/features/settings/settings_screen.dart`: menú Forui de tres grupos y cinco categorías, con objetivos táctiles mínimos de 48 dp y texto flexible.
- `settings_page.dart`, `appearance_screen.dart`, `reminders_screen.dart`, `backups_screen.dart`, `about_screen.dart`: subpantallas con Atrás; rutas fuera del shell en `core/navigation/app_router.dart`, sin barra inferior duplicada. Deep links regresan a Ajustes si no hay una ruta anterior. Mi negocio reutiliza íntegramente el formulario A.
- Recordatorios conserva el widget, inicialización y controlador T06. Copias envuelve `BackupSection`; su único cambio es el parámetro visual `showHeading`. SAF, contraseñas, exclusión de operaciones simultáneas y protección de salida siguen siendo T07.
- `appearance.dart`, `main.dart`, `app.dart`, `core/theme/app_theme.dart`: repositorio inyectable SharedPreferencesAsync, carga inicial acotada, selección inmediata, Material/FTheme y barras del sistema coherentes. Reintento y avisos en español ante fallos.
- `android/.../MainActivity.kt`: pequeño canal exclusivamente visual para aplicar el modo de recursos de Android API31+ al splash siguiente. Es la adaptación nativa necesaria para la selección local; no cambia configuración de compilación, permisos, manifest ni renderer. API24–30 no tiene esa API: splash según sistema, preferencia Flutter conservada.
- `assets/branding/`, `android/app/src/main/res/`, `tool/generate_branding.ps1`: fuentes originales intactas y recursos Android reproducibles. Ningún recurso iOS nuevo. Preview excluida de los assets de producción.
- `pubspec.yaml/lock`, pruebas de ajustes/branding y actualización de rutas de entrada en dos suites previas. README, PRODUCT_SPEC, DATA_MODEL e IMPLEMENTATION_PLAN reflejan el resultado y sus límites.

### Dependencias y decisiones

Flutter **3.47.8 stable**, Dart **3.13.7**, Forui **0.27.7**; Android mínimo 24 / compile 36 / target 36, AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, Java efectivo 21 / bytecode 17. Se verificaron versiones y documentación oficial antes de agregar:

| Dependencia directa | Versión | Uso |
|---|---|---|
| shared_preferences | 2.5.6 | SharedPreferencesAsync, DataStore Android; apariencia local |
| package_info_plus | 10.2.2 | Versión/build auténticos del paquete instalado |
| shared_preferences_platform_interface (solo dev) | 2.4.2 | Adaptador oficial en memoria para probar el repositorio real |

Se añaden nueve entradas al lockfile sin actualizar versiones previas; la dependencia dev ya formaba parte de esas transitivas. Android resuelve shared_preferences_android 2.5.4. [SharedPreferences: API async y requisitos](https://pub.dev/packages/shared_preferences), [PackageInfo: requisitos Android](https://pub.dev/packages/package_info_plus). No se añade generador Flutter ni codegen.

Clave local `mi_red.appearance_mode`: light/dark; Automático elimina la clave. Lectura: máximo 500 ms; sincronización visual Android: máximo 300 ms. No se añade `Future.delayed` de presentación. Una escritura fallida vuelve a Automático **en la sesión**, advierte y permite reintentar; si el disco falla no puede garantizarse reemplazar un valor anterior persistido. Un fallo del puente visual después de guardar mantiene el tema guardado y advierte de la falta de confirmación de Android.

La preferencia no pertenece a las cinco tablas ni al archivo `.miredbk`: restaurar conserva el tema receptor; dispositivo nuevo usa Automático. API31+ usa `UiModeManager.setApplicationNightMode`. Para Automático, el código de [Android15](https://android.googlesource.com/platform/frameworks/base/+/refs/heads/android15-release/services/core/java/com/android/server/UiModeManagerService.java) permite inferir que MODE_NIGHT_AUTO elimina la sobreescritura local (UI_MODE_NIGHT_UNDEFINED); no se llama al cambio global de modo ni se solicita ubicación. [API oficial](https://developer.android.com/reference/android/app/UiModeManager).

### Recursos y reproducción

Se verificaron dimensiones y alfa de los seis PNG antes de editar Android: maestro 1254² transparente, foreground/monochrome 1024² transparentes, legacy 1024² opaco, splash 1152² transparente y preview 1200×500. Sus seis SHA256 se fijan en `test/core/branding_test.dart` y permanecen iguales. El script registra también SHA256 de Inter y verifica que ninguna fuente se modifique.

```powershell
flutter pub get
pwsh -NoProfile -File tool/generate_branding.ps1
```

Windows/PowerShell/System.Drawing, Inter local de Forui; `-FontPath` permite otra caché. Legacy 48/72/96/144/192 px; adaptive 108 dp y máscara monochrome desde las fuentes entregadas. Escala 0.8553518553 para encajar la parte no transparente dentro de un círculo seguro de 65 dp de diámetro. El test verifica radios, neutralidad monocromática, alfa y tamaños en cinco densidades. La interpolación evita introducir esquinas transparentes en el legacy.

Splash nativo sólido #F8FAFC / #0B1220, marca central desde PNG y branding 200×80 dp con «Mi Red» / «Gestión de clientes y cobros». API31 usa los atributos de icono, fondo y branding del sistema, sin imagen vertical ni retraso artificial. [Splash oficial](https://developer.android.com/develop/ui/views/launch/splash-screen), [iconos adaptativos y monocromos](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive). `ic_notification.xml`, `raw/keep.xml`, receivers y manifest se conservan.

## Validación automatizada

Línea base previa a cambios: análisis limpio (258,1s), **271/271 pruebas** (3min50s), Debug correcto (51,6s). Logs locales `build/phase-b-baseline-*`.

Las nuevas pruebas comprueban los tres modos y cambios Android simulados/reanudación, lectura bloqueada, fallos/reintentos, repositorio nuevo y scope nuevo, restauración T07 sin importar tema, cinco rutas y deep links, tabs sin duplicados, metadatos reales simulados y enlace Semantics explícito, ausencia de aperturas automáticas y prevención de doble pulsación. Ocho combinaciones de 320/400 dp  × 100/200 %  × claro/oscuro recorren las cinco subpantallas con teclado y acciones desplazables. No se relajan hit-tests ni aserciones previas. Las suites previas solo adaptan las rutas antiguas de Ajustes a Copias/Recordatorios.

| Comando final | Resultado |
|---|---|
| `dart format .` | 99 archivos, 0 cambios; 0,73s |
| `flutter analyze --no-pub` | Sin incidencias; 5,1s |
| `flutter test --concurrency=1 --reporter expanded` | **295/295**, 8min47s; 271 previas +24 nuevas |
| `flutter build apk --debug` | Correcto; 47,2s |
| `flutter build apk --release` | Correcto; 191,6s; 67,0MB |
| `git diff --check` | Código 0, sin incidencias |
| `apksigner verify --verbose` Debug | Código 0, firma v2 válida, un firmante |
| `apksigner verify --verbose` Release | Código 1 esperado: `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`; sin firma |
| `apkanalyzer manifest permissions` Release | POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED y permiso interno AndroidX DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION; sin INTERNET |
| Repetición del generador | **42 recursos idénticos byte a byte**; fuentes intactas |

El primer ciclo completo de B también aprobó 295 pruebas (4min08s), Debug 127,3 s y Release 307,6 s. Después del ajuste de texto detectado en Android se repitieron suite y ambos builds: los resultados finales son los de la tabla. No se suprimen pruebas ni se añaden flags de renderer. Logs locales `build/phase-b-final-*`, `phase-b-*-signature.log`, `phase-b-release-permissions.log`, `phase-b-branding-repro.log` y `phase-b-native-validation.log`.

Advertencias no bloqueantes: Flutter señala KGP en cryptography_flutter/flutter_file_dialog y una referencia a CupertinoIcons sin esa fuente empaquetada; los iconos usados en estas pantallas son Lucide/Material y se comprobaron visualmente. Se conserva el stack solicitado; revisar esas compatibilidades en mantenimiento posterior, sin upgrades masivos ni dependencias añadidas para silenciar advertencias.

Artefactos finales:

- [APK Debug firmado](../build/app/outputs/flutter-apk/app-debug.apk), SHA256 `271FFEE5E427FEFB1D3B22254412062DB0B59241347881873284040519C4AC5D`.
- [APK Release compilado SIN firma](../build/app/outputs/flutter-apk/app-release.apk), SHA256 `7E06146413597FC38F6F061A90D11F05E5FFA7F3AAA83B4E2608D103B8993061`.

**Release no es instalable/distribuible todavía**. El remedio corresponde a D: configurar una clave de distribución autorizada fuera de Git, firmar y verificar. No se crean keystores ni archivos de firma en B. La auditoría de diff confirma que las rutas protegidas, permisos/receivers y los dos recursos de notificación no cambian.

## Android: evidencia real y límites

AVD dedicado **MiRed_T07_API35 / emulator-5558**, API35, 320×640dp/160dpi; datos exclusivamente sintéticos, modo avión y permiso de avisos ya concedido. No se arrancan ni modifican los AVD originales 5554/5556. Se conserva el disco y las claves de prueba; no se desinstala ni borra la app. Documentos original/corrupto T07 de Descargas conservados.

Antes de instalar se verificaron schema 2, integridad OK, FK vacías y **3 clientes, 4 dispositivos, 5 cargos, 5 pagos**. `adb install -r` terminó en Success. Tanto la huella lógica de las cinco tablas (`C91E3415459876C241FEA5921C780E4E7C629ACA0B065DF8138999827C719C9B`) como SHA256 de SQLite cerrado (`ab02dfa67a24400273b1a83bf3eb914eeb845b92ff24c376daefa48266edcd7e`) coincidieron antes/después de instalar. El documento original sigue teniendo3633bytes. No se publica contraseña ni archivo cifrado.

Recorrido real con el APK normal:

1. Mi negocio conserva «Negocio sintetico A», XTA y +53; no se guardan ni modifican campos en esta fase. Las cinco categorías, Atrás y pestañas se comprueban sin cabeceras/barras duplicadas.
2. Claro/Oscuro cambian Material, Forui y barras del sistema. Automático pasa a oscuro/claro al alternar la configuración Android con la app abierta. Oscuro sobrevive a force-stop; el splash del siguiente arranque también es oscuro con Android global en claro. La preferencia se encuentra fuera de SQLite.
3. Recordatorios conserva permiso concedido y 10 avisos preparados. La notificación de prueba usa la campana monocromática independiente y se ve en el panel nativo claro/oscuro. No se cambia opt-in ni aparecen duplicados por navegar/seleccionar tema.
4. Copias conserva su fecha anterior, abre SAF mostrando los dos documentos de T07 y al cancelar mantiene la huella exacta de las cinco tablas. No se reemplaza la base ni se crea otra copia nativa en B; exportación/restauración y fallos se vuelven a comprobar con las pruebas T07 completas, usando sus adaptadores de SO falsos y SQLite real en memoria.
5. Acerca muestra el maestro suministrado, versión instalada **1.0.0(1)**, CoreX4Dev, URL y consejos offline/contraseña. La apertura explícita del enlace, sus errores y doble pulsación se verifican mediante adaptador falso, sin abrir conexiones durante QA offline.
6. El launcher Nexus del AVD ofrece «Themed icons»: se activa, se coloca Mi Red en Inicio y se comprueba su máscara monocromática completa. Se vuelve a desactivar esa opción original y se captura también el icono normal. El recorte circular real y la zona segura por píxel se verifican; no se atribuye una prueba nativa a cada máscara de otros fabricantes.

**Arranque predeterminado:** dos aperturas frías reales mediante pulsación del icono, sin extras ni flags temporales, registraron Impeller/OpenGLES y Activity Displayed a **4,518s** (claro) y **3,186s** (oscuro). La UI quedó operativa en ambos recorridos; capturas de Inicio a unos 12 s/9 s y navegación posterior lo acreditan. No hubo ANR/FATAL observado en esos logs. No se usó Skia de respaldo en B, no hay flags permanentes, DevFS ni DDS en estas pruebas. Son resultados de este AVD/estas aperturas; **no demuestran haber corregido** los ANR/SystemUI de T07/A ni acreditan teléfono físico. El cambio visual no se presenta como solución del renderer.

La actualización final con `adb install -r` volvió a conservar la huella contable y el SHA256 de DataStore `b13fdc084e9b83aa7ed029e214a59bf50f1297c151e0522f8da9e3568964416c`. [Oscuro sigue seleccionado tras actualizar](screenshots/phase-b/appearance-dark-after-update.png). Una tercera apertura fría desde el icono con el APK definitivo registró Impeller/OpenGLES y Activity Displayed a **3,741s**, con [splash oscuro](screenshots/phase-b/final-splash-dark.png) e [Inicio operativo](screenshots/phase-b/final-restart-dark-home.png); tampoco se observa ANR/FATAL en ese log.

Se comprobó además el menú real a 200 %: [parte superior](screenshots/phase-b/settings-large-light-final.png), [zona intermedia](screenshots/phase-b/settings-large-light-middle.png) y [Copias con texto completo](screenshots/phase-b/settings-large-light-final-lower.png). Las pestañas envuelven etiquetas al ampliar texto; no se reduce la escala. El alcance completo320/400dp y ambas luminosidades se cubre por la matriz de widgets.

Estado final: las cinco tablas y el archivo SQLite cerrado siguen con sus hashes originales, schema 2, integridad OK/FK vacías y conteos 3/4/5/5. El documento externo sigue con 3633 bytes y fecha original. Se restablecen Automático, Android claro, texto 100 % y la opción original de iconos temáticos desactivada; el modo avión inicial se conserva. Se detiene únicamente emulator-5558, manteniendo disco, documentos y claves. C/D no se inician.

Capturas PNG reales por ADB, revisadas visualmente y sin edición; carpeta local ignorada por Git `docs/screenshots/phase-b/`:

| Evidencia | Archivo |
|---|---|
| Ajustes final (ambos temas y categorías completas) | [Claro](screenshots/phase-b/settings-light-final.png), [grupos inferiores](screenshots/phase-b/settings-light-final-lower.png), [Oscuro](screenshots/phase-b/settings-dark-final.png), [grupos inferiores oscuros](screenshots/phase-b/settings-dark-final-lower.png) |
| Mi negocio preservado | [business-light.png](screenshots/phase-b/business-light.png) |
| Tres modos | [Automático](screenshots/phase-b/appearance-system.png), [Claro](screenshots/phase-b/appearance-light.png), [Oscuro](screenshots/phase-b/appearance-dark.png) |
| Automático siguiendo Android en vivo | [Claro](screenshots/phase-b/appearance-auto-system-light.png), [Oscuro](screenshots/phase-b/appearance-auto-system-dark.png) |
| Tema tras cierre completo | [appearance-dark-restart.png](screenshots/phase-b/appearance-dark-restart.png) |
| Recordatorios y panel nativo | [Recordatorios](screenshots/phase-b/reminders-dark.png), [aviso claro](screenshots/phase-b/notification-system-light.png), [aviso oscuro](screenshots/phase-b/notification-system-dark.png) |
| Copias y selector externo | [backups-dark.png](screenshots/phase-b/backups-dark.png), [SAF](screenshots/phase-b/backup-system-picker.png) |
| Marca, versión y atribución | [Acerca](screenshots/phase-b/about-dark-top.png), [detalle](screenshots/phase-b/about-dark-details.png) |
| Launcher normal / temático | [normal](screenshots/phase-b/launcher-home-normal.png), [temático](screenshots/phase-b/launcher-themed.png) |
| Splash nativo | [claro](screenshots/phase-b/splash-light.png), [oscuro](screenshots/phase-b/splash-dark.png) |

La revisión real detectó inicialmente un subtítulo de categoría elidido por DefaultTextStyle heredado de Forui. Se corrigió el estilo para permitir líneas completas y se añadió aserción sobre RenderParagraph (sin límite de líneas ni ellipsis) en la matriz de 320/400 dp y 100/200 %. Las capturas intermedias anteriores a esa corrección no acreditan el menú final. Los originales y los PNG de evidencia se mantienen sin edición.

## Qué falta para terminar la aplicación

- C / QA final: arranque fiable con renderer predeterminado y análisis separado de ANR/SystemUI, teléfono objetivo y API24/25, offline/reanudación/reinicio, permisos/batería, WhatsApp real, actualización conservando datos, copias/recuperación en teléfono físico, rotación/texto grande y pruebas de usuario. El splash de API24–30 sigue el sistema aunque Flutter tenga selección manual.
- D / firma y distribución: clave autorizada fuera de Git, Release firmado/verificado, instalación y actualización, custodia de keystore y guías finales de instalación/recuperación. Un Release compilado sin firma no es una entrega instalable.
- El borrado definitivo condicional del modelo sigue sin implementarse y requiere solicitud explícita; el MVP conserva archivo/reactivación e historia. La corrección de importe A no incorpora bitácora SQL de importes anteriores, fuera del alcance autorizado.

No se implementa ninguno de estos pendientes en Fase B. No se declaran resueltos teléfono físico, DDS/DevFS ni el problema previo de renderer.
