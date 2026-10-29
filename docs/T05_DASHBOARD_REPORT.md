# T05 — Inicio operativo

29-10-2026. Solo dashboard y accesos a funciones existentes; T06–T08 no se implementan.

## Estado y arquitectura

Baseline real: árbol limpio en `c8f1e28` (`feat: billing`), Flutter **3.47.8 stable**, Dart **3.13.7**, **119 pruebas aprobadas** antes de editar (2 min 15 s). Se leyeron producto, modelo, plan, normas y los informes T02–T04. No se descartaron cambios ni se hicieron commits.

`features/dashboard/dashboard_screen.dart` sustituye el placeholder dentro del shell Forui, conservando una única cabecera «Inicio» y cuatro pestañas. Usa tokens T03.3, Inter local, Lucide, tarjetas Forui y los controles Material ya tematizados. Lista única desplazable, margen 16 dp, métricas en dos columnas al tamaño normal y una al aumentar la fuente desde 150 %. Nombres, moneda y motivos permiten wrap. Los accesos al historial son botones explícitos con área táctil propia; no dependen del centro de una fila larga.

`dashboard_providers.dart` añade un solo `StreamProvider.autoDispose`, que espera `billingSessionProvider.future` y observa `BillingQueries.watchDashboard(today)`. El reloj y la conciliación son los existentes de T04. Inicio espera la misma barrera al entrar/volver de una vista abierta, actualizar o reanudar mediante `BillingLifecycle`. Los watchers solo leen; ninguna escritura ocurre en `build()` de widgets. No hay timers ni trabajo background.

`features/billing/data/billing_queries.dart` añade `DashboardData`, `ReviewClient`, `watchDashboard` y `dashboardData`. La proyección transaccional reutiliza `periodData` para las cifras del período y `summary.activeClients` para el estado manual. Un recuento de clientes permite distinguir instalación vacía de período sin cargos. La cola usa **una consulta agrupada**, sin N+1: clientes activos con cargo sin pago vigente y fecha de candidatura persistida ya cumplida, `MIN(period_key)` por cliente, total de grupos mediante ventana antes de `LIMIT 5`. Orden: mensualidad más antigua, nombre e ID. Observa las mismas tablas que T04 (clientes, cargos, pagos y ajustes).

No se cambian `BillingService`, `PaymentService`, el calendario ni APIs públicas financieras. La única adaptación de la pantalla T04 es `BillingScreen.initialFilter` y su lectura en `/billing?filter=unpaid`. Inicializa el filtro existente a Pendientes; no lo resetea en cada build y conserva búsqueda/período/filtros al regresar del historial. La navegación inferior sigue abriendo Cobros sin ese parámetro.

## Cifras y acciones

| Dato | Definición |
|---|---|
| Período | `currentPeriod(today)` de T02: el siguiente se abre el día 30 o último válido. |
| Clientes activos | Clientes cuyo servicio manual es `active`; no indica si han pagado. |
| Pagados del período | Cargos del período con pago vigente. |
| Pendientes del período | Todos sus cargos sin pago vigente, también candidatos. |
| Por cobrar del período | Suma entera de importes históricos impagados; etiqueta de moneda existente y `formatMoneyMinor`. |
| Requieren revisión | Clientes **distintos**, actualmente activos, con al menos un cargo candidato impagado de cualquier período. Excluye archivados y suspendidos manualmente. |

Los indicadores financieros incluyen los cargos históricos archivados/suspendidos igual que T04; no hay filtros invisibles. La cola no suma deuda anterior al monto por cobrar actual. Un período completamente pagado puede seguir mostrando clientes con deuda anterior. Un pago anulado deja de ser vigente y el cargo vuelve al estado derivado; no cambia el servicio.

«Añadir cliente» abre `/clients/new`; «Ver cobros» abre el período actual de T04; «Ver pendientes» aplica Pendientes. Cada cliente en revisión enlaza a `/billing/clients/:clientId?period=YYYY-MM`, priorizando su mensualidad impagada más antigua. Si hay más de cinco, se muestra «Mostrando 5 de N» y un enlace adicional a Cobros. No se registra ni anula un pago desde Inicio ni se suspende automáticamente.

Carga accesible sin ceros provisionales; error genérico en español con reintento real. La base vacía muestra «Añade tu primer cliente»; con clientes pero sin cargos, «Sin cargos en este período»; si todos sus cargos tienen pago vigente, «Período pagado», sin afirmar que no existe deuda anterior.

## Archivos y límites

- `lib/features/dashboard/dashboard_screen.dart`: interfaz y navegación de Inicio.
- `lib/features/dashboard/dashboard_providers.dart`: provider de la proyección.
- `lib/features/billing/data/billing_queries.dart`: nueva lectura transaccional.
- `lib/features/billing/billing_screen.dart`, `core/navigation/app_router.dart`: parámetro mínimo del filtro.
- `test/features/dashboard/dashboard_queries_test.dart`, `dashboard_widgets_test.dart`: cobertura nueva.
- `test/widget_test.dart`, `test/core/design_system_test.dart`, `integration_test/database_smoke_test.dart`: actualizan la expectativa del placeholder de Inicio y añaden comprobación de dashboard cargado; los demás asserts de navegación, contraste y fuentes se conservan.
- README y este informe.

Sin cambios de dependencias, `pubspec.yaml`/lock, schemaVersion **v2**, esquema/generados, migraciones/snapshots, servicios financieros, CRUD/validadores MAC/IP, permisos, applicationId, minSdk ni firma. No hay datos falsos en `lib/main.dart` ni una librería visual nueva.

## Pruebas y comandos

Se añaden ocho pruebas de la proyección y dieciocho de widgets: vacío/sin cargos, igualdad de cifras con T04, tarifa histórica, pago/anulación reactivos, deuda anterior con actual pagado, archivo/suspensión manual, clientes distintos y límite/orden de la cola, cortes 30/febrero/bisiesto y día 3, alta real por formulario, regreso de Clientes/Cobros/Historial, errores de consulta/conciliación, reintento sin duplicados y carga sin cifras ficticias.

La matriz UI cruza 320/400 dp, claro/oscuro, texto 100/200 %, teclado simulado, nombre/moneda/importes largos y estados vacío/sin cargos/pagado. Los hit tests siguen siendo fatales. Una primera pasada encontró una clave duplicada en la nueva acción y selectores de retorno del formulario; se corrigieron. La matriz detectó el centro inaccesible de una fila larga al 200 %: se cambió por el botón explícito de historial, sin desactivar avisos ni relajar tests.

El ajuste final observado en Android usa padding de 12 dp en «Añadir cliente» para permitir dos acciones en la primera fila a 320 dp, manteniendo objetivos de 48 dp. La suite y los dos builds se repitieron con ese código.

| Comando | Resultado final |
|---|---|
| `dart format .` | 59 archivos, 0 cambios pendientes de formato. |
| `flutter analyze --no-pub` | Sin incidencias, 5,4 s. |
| `flutter test --concurrency=1 --reporter expanded` | **145 aprobadas**, 119 anteriores + 26 nuevas; 2 min 43 s. |
| `flutter build apk --debug` | Correcto, 23,7 s; `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build apk --release` | Correcto, 77,2 s; `build/app/outputs/flutter-apk/app-release.apk`, 60,6 MB. |
| `apksigner verify …app-debug.apk` | Código 0, firma debug válida. |
| `apksigner verify …app-release.apk` | Código 1, `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`: sin firma de distribución. |
| `git diff --check` | Correcto. |

Las 119 pruebas anteriores siguen en la suite. Se actualizó únicamente su expectativa de que Inicio fuera provisional, comprobando ahora el dashboard real; permanecen las comprobaciones de negocio, navegación, contraste y fuentes. Una pasada completa preliminar permitió localizar las dos expectativas antiguas en los tests de diseño; la suite final anterior ya las incluye corregidas. Los logs locales están en `build/t05-baseline-tests.log`, `t05-analyze.log`, `t05-tests.log`, `t05-build-debug.log` y `t05-build-release.log`, ignorados por Git.

Release conserva el aviso de una referencia a `CupertinoIcons` sin esa fuente durante tree shaking; no impide compilar y la UI usa Lucide/Material. No se añade una dependencia para ocultarlo ni se acredita aceptación visual de ese Release sin firma.

## Android y capturas

Se creó **`MiRed_T05_API35`**, con datos nuevos en `build/t05-avd`, puerto/ID **emulator-5556**, pantalla **320×640 / 160 dpi**. El AVD poblado preexistente `MiRed_API35` / emulator-5554 no se actualiza ni se modifica. No se ejecutan fixtures contra una BD poblada; los datos sintéticos se introducen desde la app normal en el AVD dedicado.

Preparación: APK **normal conocido de T04** instalado en el AVD nuevo; dos altas mediante el formulario existente, «Prueba T05 Alfa» por **10025** y «Prueba T05 Beta» por **5075** unidades menores. Se actualiza después al APK normal T05 con `adb install -r`, sin desinstalar/borrar datos. La huella SHA-256 del SQLite cerrado coincide antes/después de instalar, antes de abrir la nueva app. No se usó un entry point de diagnóstico ni se precargaron datos en `lib/main.dart`.

Primer arranque T05: `Status: ok`, `LaunchState: COLD` (11,509 s). Se observó octubre de 2026 según el reloj del AVD, 2 activos, 0 pagados, 2 pendientes, **151,00** por cobrar y 2 clientes para revisión. Se abrió Alfa desde la cola, registró su pago completo mediante T04 y volvió a Inicio: 2 activos, 1 pagado, 1 pendiente, **50,75** por cobrar y solo Beta para revisión. SQLite en modo lectura confirmó un pago vigente de **10025**, un cargo impagado de **5075** y ambos servicios `active`. La app siguió offline en modo avión.

«Ver pendientes» abrió el período actual y `Filtros · Pendientes`, mostrando solo Beta; Alfa no apareció en ese filtro. El recorrido Inicio → Cobros → Inicio y Clientes → Inicio mantuvo las cifras, dos cargos y un pago, sin duplicados. `user_version=2`, `integrity_check=ok`, `foreign_key_check` vacío.

La primera apertura **de T04 en el AVD recién creado**, previa a los datos sintéticos, tuvo timeout de `am start -W`. La jerarquía mostró un ANR de la app **Messages** del sistema; Mi Red tenía proceso vivo. Se cerró ese diálogo y el retorno a Mi Red respondió `Status: ok`. No se atribuye a SQLite ni se presenta ese intento como arranque frío T05 aprobado. `avdmanager` también advirtió de metadatos `devices.xml` y una copia duplicada de platform-tools; creó el AVD con código 0 y este completó el boot. No se reparó ni modificó el SDK en T05.

El **APK Debug final**, después del ajuste de espacio, se reinstaló también con `adb install -r`: el SHA-256 de SQLite siguió idéntico, esta vez incluyendo los dos cargos y el pago de Alfa. Nuevo arranque `Status: ok`, `LaunchState: COLD`, 9,548 s. El contador de revisión quedó totalmente visible en la vista inicial junto a las métricas. Se repitieron el enlace a Pendientes y el recorrido por Clientes en oscuro; proceso final sin líneas de error Flutter/AndroidRuntime observadas. Se restauraron tema claro y conectividad por defecto solo en este AVD dedicado.

### Capturas del APK final

PNG originales del AVD, revisados visualmente, sin recreación ni edición. Solo contienen datos sintéticos. `docs/screenshots/` sigue excluido de Git; los archivos están disponibles localmente.

| Vista | Claro | Oscuro |
|---|---|---|
| Inicio: período, cifras, acciones y contador | [Inicio](screenshots/t05/home-light.png) | [Inicio](screenshots/t05/home-dark.png) |
| Cola: Beta pendiente y enlace al historial | [Revisión](screenshots/t05/review-light.png) | [Revisión](screenshots/t05/review-dark.png) |

Estado conservado en el AVD dedicado: 2 clientes activos, 2 cargos (15100 unidades menores en total), 1 pago vigente (10025), deuda del período 5075, esquema v2/FK/integridad correctos. No se archivan ni eliminan estas altas: son los únicos clientes de este AVD sintético, conservados para revisión. El AVD poblado original no recibió instalaciones, altas ni cambios de datos.

Al terminar se detuvo la app y se apagó únicamente el AVD dedicado; su almacenamiento permanece en `build/t05-avd`. Para reabrirlo con ventana y revisar los datos:

```powershell
& "$env:LOCALAPPDATA\Android\Sdk\emulator\emulator.exe" -avd MiRed_T05_API35 -port 5556
```

Ese directorio es un artefacto local de desarrollo, no un respaldo T07 ni parte del APK. El emulador original permanece disponible por separado.

## Pendientes

El teléfono físico y los problemas históricos DDS/DevFS no se declaran validados/resueltos por este recorrido ADB. Release conserva su configuración sin firma de distribución; no se crean claves. La aceptación de 400 dp/200 % se acredita por widgets y se distingue del AVD real.

Fin de T05. T06 (WhatsApp, compartir y recordatorios) requiere nueva instrucción; respaldo/restauración T07 y firma/QA T08 permanecen pendientes.
