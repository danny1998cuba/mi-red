# Fase A — Cierre funcional del MVP

30-10-2026. Desarrollado por **CoreX4Dev** · [https://corex4dev.com](https://corex4dev.com).

## Alcance y estado de partida

Checkpoint comprobado: `4ae2be0 feat: backup`, `git status --short` sin cambios. Se conservó T07 completo. Baseline ejecutada antes de editar: `flutter analyze --no-pub` limpio (128,1 s) y `flutter test --concurrency=1`: **230/230** (5 min 36 s). Logs locales ignorados: `build/phase-a-baseline-analyze.log`, `build/phase-a-baseline-tests.log`.

Solo Fase A: Mi negocio, corrección de cargo vigente impagado y recaudación en Inicio. Sin dependencias nuevas, migraciones, generados Drift, configuración Android, firma ni cambios en la criptografía/restauración T07. No se realizan commits automáticos.

Versiones efectivas comprobadas al cierre: Flutter **3.47.8 stable**, revisión `737ba8f885`; Dart **3.13.7**, DevTools 2.60.0. Se conserva el stack de T07.

## Decisiones e implementación

**Mi negocio:** ruta reutilizable `/settings/business`, enlazada provisionalmente desde Ajustes. Carga real, reintento de lectura, formulario desplazable, errores de validación, bloqueo durante guardado y resultado visible sin perder los campos ante fallo. Se reutilizan `SettingsService` y `app_settings`: nombre obligatorio tras trim (máximo 120 caracteres Unicode), etiqueta de moneda opcional (máximo 48), ambos sin controles internos y de una sola línea. Los espacios exteriores se recortan. Moneda vacía conserva el comportamiento previo: solo el número, sin símbolo. Son límites de entrada, no cambios SQL; T07 sigue restaurando valores históricos completos.

`SettingsService.update` admite omitir `notificationsEnabled`: la escritura de negocio modifica solo nombre, moneda y prefijo; no lee un opt-in antiguo para reescribirlo. Conserva `last_backup_at`. El prefijo opcional usa `+` y 1–3 dígitos sin cero inicial; vacío se almacena NULL. Es una preferencia **informativa**, sin inferir país ni modificar teléfonos. WhatsApp mantiene la exigencia de destinatario internacional explícito y no envía automáticamente.

La moneda fluye por los providers/consultas existentes a Inicio, Clientes, Cobros, historial, confirmaciones y mensajes/reportes T06. No cambia cantidades SQL, precisión, tarifas ni fechas. Las cinco tablas y todas sus columnas ya estaban cubiertas por el respaldo T07; no se reimplementa su formato.

**Corrección de cargo:** `BillingService.correctChargeAmount` es una operación concreta dentro de una transacción. Relee cargo, período `currentPeriod(today)` y pago activo; valida importe entero no negativo dentro de int64, importe original esperado y que exista un cambio. La comparación contra el importe revisado rechaza confirmaciones obsoletas y repeticiones. Las transacciones serializan carrera con pago; los triggers existentes siguen protegiendo cargos pagados. No se modifica `PaymentService`, el calendario ni la generación de cargos. La conciliación ya conserva los cargos existentes.

La acción aparece en la mensualidad vigente impagada del historial, accesible desde Cobros. Flujo: importe actual → nuevo importe con coma/punto → Revisar cambio → importes original/nuevo → Confirmar corrección. Cancelar no escribe; se bloquean toques durante el guardado. Se verifica nuevamente la fecha al confirmar. No modifica tarifa, identidad/fechas del cargo, servicio manual ni deuda anterior. Pagos anulados conservan todos sus campos, incluso si su importe difiere del cargo corregido.

**Límite de auditoría:** schema v2 no almacena fecha/autor/antes-después de correcciones. Solo queda el importe actual del cargo; no se afirma una bitácora completa. La auditoría de pagos existente permanece intacta. Añadir esa bitácora requeriría otro alcance/migración.

**Recaudación:** bloque Forui «Recaudado este período», debajo de las métricas existentes. Usa directamente `billing.summary.collectedMinor`, junto con la moneda de la misma proyección T04. Cuenta pagos vigentes del período abierto, incluidos clientes archivados/suspendidos, sin sumar otros períodos ni tarifas actuales. Estados de carga/error no inventan cifras; vacío muestra cero con contexto. Cambia con pagos/anulaciones, moneda y restauración mediante las consultas reactivas existentes.

**Atribución:** README, producto y roadmap incluyen «Desarrollado por CoreX4Dev» y su URL. `pubspec.yaml` conserva `name: mi_red`, actualiza descripción y añade `homepage: https://corex4dev.com`, comprobado como sitio de CoreX4Dev. No se añade `author` ni metadatos Android ficticios. «Acerca de» y recursos de marca siguen en Fase B.

## Archivos de la fase

- Nuevos: `lib/features/settings/business_values.dart`, `lib/features/settings/business_settings_screen.dart`, `lib/features/billing/widgets/charge_correction_action.dart`.
- Modificados: `lib/features/settings/data/settings_service.dart`, `lib/features/settings/settings_screen.dart`, `lib/core/navigation/app_router.dart`, `lib/features/billing/data/billing_service.dart`, `lib/features/billing/widgets/billing_widgets.dart`, `lib/features/dashboard/dashboard_screen.dart`.
- Pruebas nuevas: `test/features/settings/business_settings_test.dart`, `test/features/billing/charge_correction_test.dart`, `test/features/phase_a/phase_a_widgets_test.dart`.
- Atribución/documentación: `pubspec.yaml`, `README.md`, `docs/PRODUCT_SPEC.md`, `docs/DATA_MODEL.md`, `docs/IMPLEMENTATION_PLAN.md` y este informe.

## QA automática

**271/271 pruebas aprobadas: 230 existentes + 41 nuevas (26 de datos y 15 widgets)**. Cubren persistencia/reapertura y restauración T07 de negocio, preservación de avisos/última copia, inputs inválidos, moneda personalizada/vacía y destinatario ambiguo, corrección/replay/carreras/pagos anulados/int64/rollback SQL real, concordancia de recaudación y actualización reactiva. Matriz nueva de widgets: 320/400 dp, claro/oscuro, texto 100/200 %, teclado, nombres y moneda largos, con hit-tests estrictos.

| Comando de cierre | Resultado |
|---|---|
| `dart format .` | 89 archivos, 0 cambios en pasada final. |
| `flutter analyze --no-pub` | Sin incidencias, 5,7 s. |
| `flutter test --concurrency=1 --reporter expanded` | 271/271, 10 min 16 s. |
| `flutter build apk --debug` | Correcto, 59,7 s; APK normal en `build/app/outputs/flutter-apk/app-debug.apk`. |
| `flutter build apk --release` | Correcto, 147,9 s, 63,8 MB; `build/app/outputs/flutter-apk/app-release.apk`, **sin firma de distribución**. |
| `apksigner verify` Debug / Release | Debug código 0. Release código 1: `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`; no se configura firma en A. |
| `aapt dump permissions` Release | POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED y permiso interno AndroidX `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`; sin permisos nuevos de red/almacenamiento/contactos/SMS/alarmas exactas. |
| `git diff --check` | Correcto al cierre; solo avisos de normalización LF/CRLF en Windows. |

Logs locales: `build/phase-a-final-analyze.log`, `build/phase-a-final-tests.log`, `build/phase-a-debug.log`, `build/phase-a-release.log`; diagnóstico de pruebas nuevas en `build/phase-a-new-tests.log` y `build/phase-a-widgets-recheck.log`. El tiempo de la suite no es un benchmark de rendimiento de la app.

Los builds conservan el aviso de migración futura a Built-in Kotlin del plugin y el aviso sobre la familia opcional CupertinoIcons; no se añaden dependencias ni se cambia el stack para ocultarlos. La auditoría `git diff --exit-code` confirma contenido intacto en `pubspec.lock`, Android, `core/database`, respaldos T07, calendario, `PaymentService`, snapshots y generados de migraciones.

Primera pasada de análisis detectó un único lint en una prueba nueva (`curly_braces_in_flow_control_structures`); se corrigió añadiendo el bloque, sin cambiar reglas.

La primera pasada de pruebas nuevas aprobó las **26 pruebas de datos**, pero detectó un overflow de 68 px en el diálogo de confirmación a 320 dp/200 % con teclado. Se trasladaron las acciones al contenido desplazable; la matriz completa conserva hit-tests estrictos. Una expectativa de cambio de fecha navegaba a la misma ruta sin reanudar/actualizar el período; se corrigió para simular pause/resume real, manteniendo la comprobación del servicio con la fecha nueva al confirmar. La nueva pasada de widgets aprobó **15/15** (1 min 29 s), incluidos los ocho escenarios de tamaño/tema/escala. No se redujeron asserts ni casos.

## QA Android

AVD sintético dedicado **MiRed_T07_API35 / emulator-5558** reutilizado, preservando el disco y la instalación de T07. Tras completar el boot, se comprobó esquema 2 y **3 clientes, 4 equipos, 5 mensualidades, 4 pagos**; se guardó huella de las cinco tablas y del archivo SQLite cerrado antes de actualizar. El documento externo T07 de Descargas sigue presente (3633 bytes). Las lecturas iniciales durante el boot dieron `device offline`/usuario aún no disponible; se esperó `sys.boot_completed=1` y se repitieron correctamente. No se desinstala, borra SQLite ni eliminan respaldos. AVD, APK normal, pruebas de widgets y teléfono físico se documentan por separado.

`adb -s emulator-5558 install -r build/app/outputs/flutter-apk/app-debug.apk`: **Success**; antes de abrir la app coincidieron tanto la huella lógica de las cinco tablas como el SHA256 del archivo SQLite cerrado. El arranque posterior también conservó las cinco tablas exactas. Pantalla de 320×640 dp, texto 100 %, permiso de notificaciones ya concedido, modo avión y zona del AVD conservada.

**Bloqueo de entorno que sigue abierto:** el arranque predeterminado (Impeller/OpenGLES) devolvió `Status: timeout`, WaitTime 12250 ms, y apareció «System UI isn't responding». Logcat registró la Activity mostrada a +17s986ms, sin acreditar una pantalla operativa bajo ese renderer. Se eligió Wait y se lanzó el mismo APK normal con `--ez enable-impeller false`: `Status: ok`, COLD, TotalTime 11868 ms, y la UI quedó operativa. Este es un recurso temporal para QA, deprecado por Flutter; no una corrección del arranque ni un cambio de manifiesto/código. Fase A no cierra ese problema, el teléfono físico ni DDS/DevFS.

Recorrido real del **APK normal**, en modo avión:

1. Ajustes → Mi negocio: cargó valores T07; guardó «Negocio sintetico A», moneda XTA y prefijo +53. La huella de clientes/equipos/cargos/pagos y los valores de avisos/última copia permanecieron idénticos. Reabrir mostró los tres valores persistidos.
2. Cobros → historial → noviembre 2026 vigente (abierto el 30 de octubre): revisión de 999,99 → 888,88 XTA con coma decimal. Antes de confirmar y tras cancelar, la huella de las cinco tablas seguía idéntica. Repetir con punto decimal produjo la misma previsualización.
3. Confirmar corrección: `charges.amount_minor=88888`, tarifa del cliente `99999`, servicio `active`; la huella de **los cuatro pagos previos completos** permaneció idéntica. Integridad correcta y FK sin incidencias. La acción final se desplazó dentro del diálogo para quedar completamente visible; la previsualización y las acciones son desplazables, sin reducir texto ni desactivar hit-tests.
4. Registrar pago completo desde la UI: se registraron 88888 unidades menores; Inicio mostró **888,88 XTA** y Cobros un cargo pagado. `SUM` de pagos vigentes de noviembre en SQLite coincidió. El cliente conservó una deuda impagada de un período anterior, sin sumarla a la recaudación actual ni cambiar el servicio.
5. Anular ese pago con confirmación: Inicio volvió a **0,00 XTA**, la mensualidad quedó pendiente por 888,88 XTA y el nuevo pago se conservó como anulado. Los cuatro pagos anteriores conservaron exactamente IDs, importes, notas y auditoría. Estado final de QA: 3 clientes, 4 equipos, 5 cargos, 5 pagos (incluido el nuevo anulado), schema 2 e integridad/FK correctas.
6. Tras force-stop y nuevo lanzamiento con Skia, la huella de las cinco tablas, preferencias e integridad siguió idéntica. Ese último `am start -W` devolvió `Status: timeout`, WaitTime 11961 ms; la [captura del reinicio](screenshots/phase-a/restart-home-light.png) muestra la app todavía cargando, no Inicio operativo. Se acredita persistencia de SQLite, **no un arranque frío fiable**. No se atribuye una causa nueva ni se presenta el fallback como solución estable. Se conservó el documento externo y se restauró conectividad/tema claro antes de detener únicamente emulator-5558. Los AVD originales no se tocaron.

Capturas PNG reales por ADB, revisadas visualmente y sin edición, con datos exclusivamente ficticios. Disponibles localmente en `docs/screenshots/phase-a/` (carpeta ignorada por Git):

| Evidencia | Claro | Oscuro |
|---|---|---|
| Mi negocio reabierto con preferencias persistidas | [business-light.png](screenshots/phase-a/business-light.png) | [business-dark.png](screenshots/phase-a/business-dark.png) |
| Cargo con importe corregido | [correction-saved-light.png](screenshots/phase-a/correction-saved-light.png) | [correction-saved-dark.png](screenshots/phase-a/correction-saved-dark.png) |
| Inicio con recaudación pagada | [collected-paid-light.png](screenshots/phase-a/collected-paid-light.png) | [collected-paid-dark.png](screenshots/phase-a/collected-paid-dark.png) |
| Inicio después de anular | [collected-void-light.png](screenshots/phase-a/collected-void-light.png) | [collected-void-dark.png](screenshots/phase-a/collected-void-dark.png) |

Otros pasos: [entrada del nuevo importe](screenshots/phase-a/correction-form-light.png), [previsualización original/nuevo](screenshots/phase-a/correction-preview-light.png), [botón de confirmación totalmente visible](screenshots/phase-a/correction-actions-dark.png). Las capturas iniciales de previsualización muestran parte del botón inferior antes de desplazar; no se presentan como evidencia de un objetivo táctil completo. La captura [default-launch.png](screenshots/phase-a/default-launch.png) conserva el ANR del sistema y distingue ese fallo de la QA funcional con Skia. El cambio de tema puede actualizar las barras del sistema después del contenido; revisar esa transición en Fase B/QA final.

## Qué falta después de Fase A

- **Fase B (sin iniciar):** reorganizar Ajustes; apariencia; recursos de identidad/icono/splash; subpantalla «Acerca de Mi Red» con CoreX4Dev y su URL. El enlace provisional «Mi negocio» se puede reutilizar sin rehacer el formulario.
- QA final posterior: teléfono objetivo y API24/25, offline/reanudación/reboot, permisos/batería/WhatsApp real, rotación/texto grande y actualización conservando datos. Repetir copia/recuperación en teléfono físico. El problema previo de arranque/renderer necesita evidencia; instalar un APK no cierra DDS/DevFS ni Impeller/Skia.
- Firma y distribución posteriores: clave autorizada fuera de Git, Release firmado/verificado, instalación/actualización y guías finales de instalación, recuperación y custodia. Release compilado sin firma no es distribuible.
- Borrado definitivo de clientes sin historia sigue siendo condicional a una solicitud explícita; archivo/reactivación conservan historial. No se añade en esta fase.

No se implementan fases B/C/D ni T08 en este encargo.
