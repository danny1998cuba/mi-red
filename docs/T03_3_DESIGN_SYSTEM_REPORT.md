# T03.3 — Sistema visual

28-10-2026. Solo presentación. Sin T04, cambios de esquema, migraciones, servicios, validadores MAC/IP ni ciclo financiero.

## Estado de partida

- Checkpoint existente: `8990e82` (`feat: client screens`), árbol limpio antes de editar. No fue necesario pedir un nuevo commit; no se hicieron commits ni descartes.
- Flutter 3.47.8 stable / Dart 3.13.7, `flutter analyze` limpio, **90 pruebas aprobadas** antes de cambiar UI.
- Los informes históricos se encuentran en `docs/T02_PERSISTENCE.md` y `docs/T03_2_IP_DEVICES.md`; se corrigieron los enlaces del README que todavía apuntaban a la raíz.
- T03.1 no tiene informe independiente y su aceptación visual completa quedó pendiente. Las verificaciones nuevas no se presentan como aceptación retroactiva de aquella versión.

## Biblioteca y migración visual

Se fija **Forui 0.27.7**, compatible con el SDK instalado: el paquete exige Flutter >=3.47 y Dart >=3.13. Solo se añadieron `forui`, `forui_lucide 0.27.0` y `sugar 4.0.0`. El diff del lockfile conserva las versiones anteriores de todos los demás paquetes. Sin actualización de Flutter, upgrades masivos, generadores o `forui init`.

Se consultaron [Getting Started](https://forui.dev/docs/getting-started), [paquete 0.27.7](https://pub.dev/packages/forui/versions/0.27.7) y [temas](https://forui.dev/docs/concepts/themes), y se contrastaron constructores/constraints con el código descargado de esa versión.

`MaterialApp.router`, Riverpod y go_router permanecen. Se añade `FTheme` debajo de MaterialApp, usando bases `.light.touch` / `.dark.touch` y español. Forui aporta navegación inferior, tarjetas, CTA de alta, Lucide y tipografía Inter empaquetada, sin fuentes remotas.

El adaptador `toApproximateMaterialTheme()` de Forui 0.27.7 devuelve tipos del paquete `material_ui`, distintos de los controles `flutter/material.dart` existentes. Se conserva la edición Material estable y se construye su tema desde los mismos tokens de Forui, sin migrar todo el proyecto a otro paquete Material. Campos, dropdowns, confirmaciones, botones y mensajes retenidos comparten paleta, radios, tamaños y bordes. Se prioriza consistencia y estabilidad sobre sustituir cada widget.

## Diseño y componentes

- `lib/core/design_system/app_design.dart`: única fuente de paleta, estados, espaciado y radio; temas Forui/Material derivados. Canvas claro `#F8FAFC`, superficie blanca, texto `#0F172A`, secundario `#64748B`, borde `#E2E8F0`, teal `#0F766E`. Oscuro: `#0B1220`, `#111B2B`, `#F1F5F9`, `#94A3B8`, `#263449`, teal `#2DD4BF`.
- Estados reutilizables: positivo verde, advertencia ámbar, peligro rojo; con icono y texto. No se construyen indicadores financieros de T04 ni se confunde el estado real del servicio con pagos.
- Escala 4/8/12/16/24, margen habitual 16, radio 12, borde fino y sin sombras decorativas. Cuerpo 14–16, cabeceras 22, etiquetas 12–14. Objetivos de botones de 48 dp o mayores; el contenido puede crecer con accesibilidad.
- `app_components.dart`: cabecera medida según texto/ancho, búsqueda limpiable, filtro contraíble con resumen y chevron, badge, sección, vacío, confirmación y valor IP copiable. El tema de inputs es el equivalente compartido a un wrapper de campo: se conservan los `TextFormField` y sus controladores.
- Shell: una sola cabecera por página y barra inferior Forui con cuatro destinos; iconos Lucide consistentes y selección con texto/semántica. Las etiquetas pueden envolver al 200 %, sin reducir el escalado global.
- Clientes: buscador persistente en la vista, filtros inicialmente cerrados, alta rectangular compacta, filas con nombre/estado/tarifa y datos opcionales. Sin FAB superpuesto. Tocar fuera del buscador retira su foco sin borrar la consulta, evitando que Gboard vuelva a cubrir filas al retornar de la ficha.
- Formularios: columnas desplazables de pocos campos, todos montados para conservar foco y validación aun fuera del viewport. El primer error se lleva a la vista al guardar. Se conservan teclados, normalización, dinero entero, guardas de borrador y protección frente a doble toque.
- Ficha: grupos de datos y dispositivos con bordes; MAC y IPv6 completos, seleccionables y sin truncamiento. Botón «Copiar dirección IP» copia solo la dirección; muestra éxito/error en español. La edición/borrado siguen usando servicios existentes y confirmación.
- Inicio/Cobros/Ajustes: tarjetas de «Pantalla provisional», sin métricas o acciones ficticias.

## Archivos

- Nuevos: `lib/core/design_system/app_design.dart`, `app_components.dart`, `test/core/design_system_test.dart` y este informe.
- Tema/shell: `lib/app.dart`, `core/theme/app_theme.dart`, `core/navigation/app_shell.dart`, `route_error_screen.dart`, `core/widgets/feature_placeholder.dart`.
- Vistas: Clientes, formulario de cliente, ficha, formulario de dispositivo, `features/clients/widgets/client_widgets.dart`; las tres pantallas provisionales solo cambian iconos/presentación.
- Dependencias: `pubspec.yaml`, `pubspec.lock`.
- Pruebas: `test/widget_test.dart`, `test/features/clients/client_widgets_test.dart`, `integration_test/database_smoke_test.dart` (solo selector del nuevo componente de navegación).
- Documentación: README y siete capturas reales en `docs/screenshots/t033/`.

**Sin diff** en `core/database`, servicios de clientes/dispositivos/cobros/ajustes, snapshots `drift_schemas/`, helpers de migración o tests financieros. El esquema sigue en v2. No se regenera Drift ni se cambian applicationId, minSdk, firma o permisos.

## Pruebas automáticas

```powershell
flutter --version
dart format .
flutter analyze --no-pub
flutter test --concurrency=1
flutter build apk --debug
flutter build apk --release
```

- Formato: **46 archivos**, sin cambios finales pendientes de formato.
- Análisis: **sin incidencias**.
- Suite completa: **95 aprobadas** (90 previas conservadas + 2 temas/contraste + 2 copia de IPv6 al 200 % + 1 error fuera del viewport).
- Se conservan casos de calendario, importes, histórico, migración v1→v2 y preservación de datos, MAC/IP, filtros, búsqueda, errores y reintentos. Se adaptaron selectores visuales de NavigationBar a FBottomNavigationBar y la expectativa de cabecera única.
- La matriz 320/400 dp, claro/oscuro y 100/200 % continúa pasando con teclado simulado. Contraste verificado para texto, texto secundario, CTA y colores semánticos. IPv6 largo se copia íntegro en ambos temas.
- Durante el trabajo hubo fallos de integración por tipos Material distintos y por avisos de llaves del linter; se corrigieron. Las primeras pruebas visuales detectaron desplazamiento sin frame y campos diferidos; se corrigieron sin desactivar advertencias de hit test ni borrar pruebas. Algunos procesos de análisis/compilación tardaron o quedaron detenidos; se reintentaron por separado. No se atribuye a la BD ni se cambia configuración del equipo.

## Android y APK

**Debug: aprobado.** APK normal `lib/main.dart`, compilado después del ajuste final de foco, firma verificada con `apksigner`, instalado con `adb install -r` y arrancado en frío (`Status: ok`). Se mantuvieron el package ID, la firma debug y la BD v2 poblada; no se desinstaló ni se borraron datos.

**Release: compilado, sin firma.** El build final termina y genera un APK de 60,1 MB; `apksigner verify` devuelve `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`. No se presenta como release instalable, ni se crearon claves o cambiaron opciones de firma. No confundir este resultado con un fallo de ejecución Dart.

**Recorrido Android realizado**, guiado por ADB, jerarquía accesible y capturas del AVD API 35 de 320 × 640 dp, fuente del sistema 1,0:

1. Alta de «Prueba sintetica T03.3» con teléfono/dirección ficticios y tarifa 30,50. Entrada real por los campos, desplazamiento hasta Guardar y conservación del borrador al elegir «Seguir editando».
2. Edición a 35,75, reflejada en ficha. Comprobación SQLite sobre esa fixture: tarifa `3575`, cargo original `3050`; la presentación no reescribió el cargo.
3. Alta de dispositivo con MAC en guiones y IPv6 largo. En ficha quedó `02:00:00:03:03:01` y la IPv6 completa, con wrapping. Acción Copiar IP confirmada por su mensaje; la integridad exacta del texto copiado se comprueba también en los tests widget.
4. Edición confirmada de notas conservando MAC/IP. La ficha muestra «Editado T03.3».
5. Archivado confirmado: desaparece de Activos; búsqueda y filtro Archivados lo recuperan. Colapsar/reabrir conserva selección (`Archivados selected=true`). Reactivación confirmada y servicio activo de nuevo.
6. Instalación del APK final y nuevo arranque en frío: cliente, tarifa, dispositivo, MAC, IP y notas se conservan. Búsqueda/filtros funcionan; después de interactuar fuera del buscador `mInputShown=false`, sin barra flotante sobre las filas.
7. Segundo dispositivo solo con IPv4 `192.0.2.33`, sin MAC. Guardar se alcanzó desplazando con el IME completo abierto. Borrado confirmado de ese dispositivo temporal; el dispositivo IPv6 permanece. Conteo final de dispositivos de la fixture: uno.
8. Cambio claro/oscuro por modo del sistema y capturas. Se restauró el modo original `Night mode: no`; no se modificaron tamaño, densidad, fuente, ajustes de PC ni configuración del AVD.

La última comprobación SQLite devuelve `user_version=2`, `foreign_key_check` vacío e `integrity_check=ok`. No hay diff en esquema/migraciones/servicios. El cliente/dispositivo sintético final queda en el AVD para revisión, no se precarga en la app ni en instalaciones nuevas.

Las interacciones se pausaron mientras el emulador cambiaba entre observaciones; el propietario confirmó que lo dejaría libre. Después se continuó con un punto de partida conocido. Las capturas publicadas contienen únicamente datos sintéticos; no se incluyen volcados de datos previos.

No se ejecutó `flutter run` ni el runner de integración Android en esta iteración: no se afirma corregido DevFS/DDS. El recorrido guiado y los screenshots del APK real se distinguen de las pruebas unitarias/widget y de una prueba en teléfono físico.

### Capturas reales

PNG originales del emulador, sin recreación gráfica ni edición. En claro se muestra el alta y en oscuro la edición del mismo cliente de prueba.

| Vista | Claro | Oscuro |
|---|---|---|
| Clientes | [Listado](docs/screenshots/t033/clients-light.png) | [Listado](docs/screenshots/t033/clients-dark.png) |
| Formulario de cliente | [Alta](docs/screenshots/t033/client-form-light.png) | [Edición](docs/screenshots/t033/client-form-dark.png) |
| Ficha / dispositivos | [MAC e IPv6](docs/screenshots/t033/client-detail-light.png) | [MAC e IPv6](docs/screenshots/t033/client-detail-dark.png) |

[Formulario de dispositivo con teclado completo y Guardar visible](docs/screenshots/t033/device-keyboard-light.png).

## Pendientes

- T03.1: sigue faltando su informe independiente y una aceptación completa atribuible a aquella versión; README y este informe distinguen los resultados actuales.
- No hay teléfono físico disponible; el fallo de arranque reportado en él sigue sin causa confirmada.
- La revisión Android real se hizo a 320 dp / 100 %. La matriz de 400 dp y texto al 200 % está aprobada en widget tests, no se presenta como aceptación manual de esas configuraciones.
- No se declara resuelto el fallo previo de DevFS/DDS por instalar/abrir el APK. Deben separarse pruebas Flutter, instalación, arranque y depuración conectada.
- Release continúa sin firma; no distribuirlo como APK instalable. La firma definitiva pertenece a una fase posterior autorizada.
- T04 no se inicia. Se requiere nueva orden.
