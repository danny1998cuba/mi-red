# T04 — Cobros, pagos e historial

Fecha: 29-10-2026. Alcance: T04 exclusivamente. Inicio y Ajustes continúan provisionales; T05–T08 no se implementan.

## Implementación y arquitectura

`features/billing/billing_screen.dart` sustituye el placeholder dentro del shell Forui existente, con una sola cabecera. Presenta mes/año explícitos, anterior/siguiente (sin avanzar más allá del período abierto por T02), acceso al período actual, actualización, búsqueda por nombre y filtros contraídos inicialmente. Mantiene período, búsqueda, filtro y desplazamiento al volver del historial contextual. Orden: sin pagar primero, después pagados; nombre y ID estabilizan los empates.

El resumen muestra clientes con cargo, cargos pagados, cargos sin pagar y monto por cobrar del período completo. No cambia al buscar/filtrar. La unicidad cliente/período permite equiparar clientes con cargo y número de cargos. «Sin pagar» incluye candidatos a suspensión. Los importes son sumas de enteros menores de los cargos históricos, con `formatMoneyMinor` y la etiqueta de moneda existente; no se aplica conversión ni tarifa actual al pagar.

`client_billing_screen.dart` presenta todas las mensualidades del cliente, priorizando la seleccionada cuando se entra desde Cobros. Ruta raíz `/billing/clients/:clientId?period=YYYY-MM`, fuera del shell, con retorno al origen. La ficha de Cliente añade únicamente el acceso «Cobros e historial»; el CRUD de clientes/dispositivos permanece intacto. El historial muestra último pago vigente, fechas de cobro y posible suspensión persistidas, pagos vigentes/anulados, sus fechas y nota opcional.

`data/billing_queries.dart` añade proyecciones exclusivamente de lectura (`BillingQueries`, `BillingPeriodData`, `ClientBillingData`). Sus watchers observan clientes, cargos, pagos y ajustes, y leen una instantánea transaccional. Reutilizan `BillingService.chargesForPeriod`, `summary`, `historyForClient` y `PaymentService.historyForClient`; la consulta adicional detecta cargos anteriores sin pago vigente. No se añade otro repositorio ni motor financiero.

`billing_providers.dart` conecta estas proyecciones a los providers existentes. `billingSessionProvider` concilia mediante `BillingService.reconcile` y comparte el reloj `clientClockProvider`; agrupa solicitudes simultáneas y expone errores con reintento explícito. `BillingLifecycle` lo inicia al arrancar y actualiza al reanudar. Las pantallas esperan esta barrera al entrar, cambiar período o actualizar. Las escrituras no se hacen en `build()` de widgets. No hay temporizadores ni trabajo en segundo plano: volver a abrir/reanudar/actualizar obtiene la fecha vigente.

`widgets/payment_action.dart` llama únicamente a `PaymentService.register` o `voidPayment`. Confirma cliente, mes e importe exacto; admite nota opcional al registrar y confirma explícitamente la anulación. Bloquea apertura repetida, confirmación repetida y salida durante la escritura; conserva la nota al fallar y desplaza el error al área visible. La BD sigue imponiendo pago completo y un solo pago vigente por cargo. El feedback y la actualización reactiva no requieren reiniciar.

`widgets/billing_widgets.dart` reutiliza tarjetas Forui, badges y tokens compartidos teal/gris, Inter local, Lucide y controles Material ya tematizados. Los textos hacen wrap y las listas/diálogos permiten desplazamiento; los estados incluyen texto e icono.

## Semántica financiera expuesta

- **Pagado:** existe un pago vigente para ese cargo; se muestra su fecha real.
- **Pendiente:** cargo sin pago vigente antes de su fecha de candidatura según T02.
- **Candidato a suspensión:** cargo sin pago vigente desde su fecha persistida; no cambia el servicio.
- **Deuda anterior:** otro cargo de un período anterior sin pago vigente. Pagar el mes seleccionado no lo liquida.
- **Servicio activo/suspendido/archivado:** estado manual del cliente, mostrado por separado. Un servicio suspendido puede tener mensualidades pagadas; un candidato puede conservar servicio activo.
- **Pago anulado:** conserva ID, importe, fecha original, nota y `voided_at`. Deja de contar como vigente; el cargo vuelve a su estado derivado de T02, que puede ser candidato en lugar del texto «Pendiente».

El período es la mensualidad facturada por T02, no el mes calendario en que se pulsa «pagar». Se abre el siguiente en el día 30 o último válido del mes; la candidatura comienza el día 3 de la mensualidad. Se presentan las fechas persistidas; no se replica el calendario en widgets. La selección de mes es solo consulta; las únicas generaciones se delegan al servicio idempotente existente. Los períodos omitidos al archivar/reactivar conservan el ancla de T02.

## Archivos y restricciones

Nuevos en `lib/features/billing/`: `billing_lifecycle.dart`, `billing_providers.dart`, `billing_values.dart`, `client_billing_screen.dart`, `data/billing_queries.dart` y `widgets/billing_widgets.dart` / `payment_action.dart`. También se añaden `test/features/billing/billing_queries_test.dart`, `billing_widgets_test.dart`, la fixture explícita `tool/t04_billing_fixture.dart` y este informe.

Modificados: `lib/app.dart` (observer), `core/navigation/app_router.dart` (ruta), `features/billing/billing_screen.dart`, `features/clients/client_detail_screen.dart` (enlace), `test/widget_test.dart`, `test/core/design_system_test.dart`, `integration_test/database_smoke_test.dart`, README y este informe. Los tests existentes usan SQLite real en memoria al arrancar; solo se actualiza la expectativa de que Cobros ya no es provisional.

Sin dependencias nuevas; `pubspec.yaml`/lock, esquema v2, código generado, snapshots/migraciones, calendario, servicios financieros, APIs y validadores de dispositivos, configuración Android, permisos, applicationId, minSdk y firma permanecen sin cambios. No se incluyen keystores ni servicios remotos.

## Pruebas automáticas

Baseline comprobado: 95 pruebas. Se añaden 7 pruebas de consultas/providers y 17 de widgets. Cubren períodos y vacíos, filtros/búsqueda y regreso, pago único bajo doble toque, anulación cancelada/confirmada, deuda anterior, tarifa histórica, servicio manual independiente, archivo/reactivación sin períodos omitidos, reapertura con pagos/anulaciones, conciliación idempotente, errores de lectura/escritura y reintento. La matriz visual prueba 320/400 dp, ambos temas, texto 100/200 %, teclado simulado, nombre/moneda largos y error desplazado fuera del viewport. Conserva las comprobaciones anteriores.

| Comando | Resultado |
|---|---|
| `dart format .` | Correcto; 56 archivos Dart, incluida la fixture. |
| `flutter analyze --no-pub` | Sin incidencias (38,1 s). |
| `flutter test --concurrency=1 --reporter expanded` | **119 aprobadas** (95 anteriores + 24 nuevas), 1 min 23 s. |
| `flutter build apk --debug` | Correcto, 63,6 s; `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build apk --release` | Correcto, 80,0 s; `build/app/outputs/flutter-apk/app-release.apk`, 60,5 MB. |
| `apksigner verify …app-debug.apk` | Código 0; firma debug válida. |
| `apksigner verify …app-release.apk` | Código 1: `DOES NOT VERIFY`, `ERROR: Missing META-INF/MANIFEST.MF`; release sin firma. |
| `git diff --check` | Correcto. |

Logs locales ignorados por Git: `build/t04-analyze.log`, `t04-tests.log`, `t04-build-debug.log`, `t04-build-release.log`. El formato/análisis inicial se reintentó tras interrumpir un proceso de análisis sin respuesta; el resultado final anterior es una ejecución completa, sin exenciones. Una pasada preliminar detectó la necesidad de inyectar la BD en los tests de arranque; se corrigió el harness, sin eliminar pruebas. La suite final no informa fallos ni avisos de múltiples instancias de Drift.

Gradle advierte de versiones XML 3/4 distintas entre herramientas Android; no impide compilar. Release también advierte de una referencia a `CupertinoIcons` sin esa fuente, durante el tree shaking de dependencias; la UI implementada usa Lucide/Material, comprobados en Debug, y no se añadió otra dependencia para ocultar el aviso. No se acredita aceptación visual de Release sin firma.

## Android y datos de prueba

AVD `emulator-5554`, API **35**, tamaño **320×640 / 160 dpi**, texto 100 %, temas claro y oscuro. Se actualizó con `adb install -r`, sin desinstalar ni borrar datos. Antes de abrir el APK nuevo se comparó SHA-256 del archivo SQLite: **idéntico antes/después de instalar**. El arranque normal respondió `Status: ok`, `LaunchState: COLD`. El recorrido de finanzas se hizo en **modo avión**; al terminar se restauraron conectividad y tema claro originales.

1. Preparación explícita: `MI_RED_T04_PREPARE_OK period=2026-09`. Se comprobó en memoria que preparar la fixture no cambia ninguna fila ajena. Se volvió inmediatamente al APK normal para toda la interacción.
2. Cobros → septiembre 2026: consulta de lectura confirmó **cero cargos ajenos a la fixture** en ese período antes de capturar. Resumen: 1 cargo, 0 pagados, 1 sin pagar, 123,45 por cobrar. El cliente muestra servicio suspendido, cargo candidato y deuda anterior.
3. Registrar pago → confirmar septiembre por **12345** unidades menores, con nota «Prueba T04». SQLite confirmó exactamente un pago vigente, importe 12345 y nota conservada; agosto continuó impagado. La tarifa actual permaneció **99999**, servicio **suspended**. La UI cambió a pagado y el monto por cobrar a 0,00 sin reiniciar, conservando la advertencia de deuda antigua.
4. Historial → anular → cancelar: siguió un pago vigente. Volver a anular → confirmar: quedó un único registro, `voided_at` presente, `paid_at` y nota conservados, cero pagos vigentes. Septiembre volvió a candidato y por cobrar 123,45; no se cambió el servicio ni la tarifa.
5. Se detuvo el proceso y arrancó otra vez en frío: `Status: ok`, `LaunchState: COLD` (2,66 s). Clientes → búsqueda exclusiva de la fixture → ficha → **Cobros e historial**: mostró «Sin pagos vigentes» y el cargo candidato; la anulación persistía. Se revisó su fecha/nota en la auditoría.
6. Limpieza mediante **Archivar cliente → Archivar** en la ficha normal. Estado final `archived`, tarifa 99999, dos cargos por un total de 24690, un pago anulado con nota. El historial se conserva deliberadamente. La huella SHA-256 de todas las filas ajenas a la fixture (clientes, dispositivos, cargos, pagos y ajustes, ordenados) fue idéntica antes del pago y después de la anulación/archivo. Solo se guardó la huella; los valores reales quedaron en memoria.
7. `PRAGMA user_version`: **2**; `integrity_check`: **ok**; `foreign_key_check`: sin filas. El APK instalado y el artefacto final Debug corresponden al entry point normal, no al diagnóstico.

No hubo fallo de instalación/ADB en este recorrido ni cierre observado de Mi Red. El buffer de crash contenía cierres previos de Bluetooth del emulador (28/29-10), separados del proceso de la app. No se ejecutó el runner Android de integración ni se revalidó DDS/DevFS; sus problemas históricos siguen abiertos. La matriz 200 % y 400 dp es evidencia de widget tests, no una afirmación de pruebas en otro teléfono o AVD.

### Capturas locales revisadas

Las capturas contienen únicamente la fixture. `docs/screenshots/` conserva la exclusión de Git del repositorio; estos archivos están disponibles localmente y enlazados para revisión.

| Vista | Claro | Oscuro |
|---|---|---|
| Cobros, mes y resumen | [Cobros](screenshots/t04/billing-light.png) | [Cobros](screenshots/t04/billing-dark.png) |
| Acciones / deuda anterior | [Registrar pago](screenshots/t04/billing-actions-light.png), [pagado con deuda](screenshots/t04/paid-debt-light.png) | [Auditoría anulada y agosto impagado](screenshots/t04/voided-history-dark.png) |
| Historial | [Pago vigente](screenshots/t04/history-light.png) | [Auditoría vigente](screenshots/t04/history-dark.png), [tras reinicio](screenshots/t04/history-after-restart-dark.png) |
| Confirmación | [Pago completo](screenshots/t04/confirm-light.png) | [Anulación](screenshots/t04/void-confirm-dark.png) |

`tool/t04_billing_fixture.dart` es un entry point de diagnóstico opt-in, nunca importado por `lib/main.dart`. Requiere BD existente y `--dart-define=MI_RED_T04_FIXTURE=prepare|paid|voided|archive`. `prepare` crea exclusivamente `t04-synthetic-ui-client`, nombre «Prueba sintetica T04», dos cargos anteriores de 12345 unidades menores y tarifa actual 99999; deja el servicio manualmente suspendido para evitar nuevos períodos. Rechaza repetir la preparación. Los modos de comprobación reabren la BD, comprueban pagos/auditoría, esquema v2, integridad y FK. Las operaciones propias comparan en memoria todas las filas ajenas a la fixture; no registran datos reales ni excepciones con SQL.

La limpieza segura es **archivo lógico**, desde la ficha o con el modo `archive`, reteniendo cargos y anulación. En este recorrido se usó la ficha; los modos de diagnóstico `paid`/`voided`/`archive` no se ejecutaron, pues las comprobaciones equivalentes se hicieron por SQLite en modo lectura y la limpieza por UI. No se eliminan pagos históricos ni se borra/desinstala la BD para limpiar la prueba. Esta fixture es solo para el AVD de desarrollo; nunca se instala en el teléfono de un usuario. Después se debe reinstalar el APK normal de `lib/main.dart` con `adb install -r`.

Ejemplo de preparación en un AVD de desarrollo poblado, **solo una vez**:

```powershell
flutter build apk --debug -t tool/t04_billing_fixture.dart --dart-define=MI_RED_T04_FIXTURE=prepare
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
# Esperar MI_RED_T04_PREPARE_OK en logcat antes de volver al APK normal.
flutter build apk --debug -t lib/main.dart
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am force-stop com.mired.offline
adb -s emulator-5554 shell am start -W -n com.mired.offline/.MainActivity
```

Para repetir la prueba no se sobrescribe esa fixture ni se destruye su historial. Usar otro AVD de pruebas o adaptar explícitamente el ID sintético en una nueva revisión. El APK normal no genera datos falsos.

## Limitaciones y parada

No hay teléfono físico validado. DDS/DevFS es una incidencia histórica separada de SQLite; la aceptación Android se basa en APK independiente/ADB y no presupone que el depurador esté resuelto. Release sigue sin firma de distribución; compilarlo no acredita que se pueda instalar. No se generan claves ni se cambia la configuración de firma en T04.

Fin de T04: esperar revisión. La siguiente tarea propuesta es T05 (dashboard y pulido de flujo), reutilizando estas proyecciones y resúmenes, sin ampliar las reglas financieras. Requiere nueva instrucción.
