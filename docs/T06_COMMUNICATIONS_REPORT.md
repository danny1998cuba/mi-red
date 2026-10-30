# T06 — WhatsApp, listados y recordatorios locales

29-10-2026. T06 exclusivamente. No se implementan respaldo/restauración T07 ni firma T08.

## Checkpoint y compatibilidad

T05 ya estaba comprometida en **`97c8340` (`feat: dashboard`)**, con árbol limpio. No fue necesario crear otro commit de T05 ni descartar cambios. Baseline ejecutada antes de editar: análisis sin incidencias (76,3 s), **145 pruebas aprobadas** (1 min 22 s) y Debug normal compilado (31,7 s).

Entorno real: Flutter **3.47.8 stable**, Dart **3.13.7**, Java **21.0.11**; compatibilidad Java/Kotlin objetivo **17**, AGP **9.1.0**, Gradle **9.3.1**, Kotlin **2.4.0**, compile/targetSdk **36**, minSdk **24**, `com.mired.offline`. Se conservaron las opciones de la plantilla `android.newDsl=false` / `android.builtInKotlin=false`. No se actualizó el stack ni se cambió minSdk.

| Dependencia fijada | Motivo y contraste |
|---|---|
| [`url_launcher 6.3.3`](https://pub.dev/packages/url_launcher/versions/6.3.3) | Abrir el enlace HTTPS por aplicación externa, con fallo controlado; SDK instalado superior al mínimo. |
| [`share_plus 13.3.1`](https://pub.dev/packages/share_plus/versions/13.3.1) | `SharePlus.instance.share(ShareParams(text: …))`; AGP/Gradle/Kotlin reales superan sus mínimos documentados. |
| [`flutter_local_notifications 22.3.3`](https://pub.dev/packages/flutter_local_notifications/versions/22.3.3) | Avisos locales, permiso, canal, entrega inexacta y tap-to-open; desugaring **2.1.4** según esa versión. |
| [`flutter_timezone 5.1.1`](https://pub.dev/packages/flutter_timezone/versions/5.1.1) | Obtener el identificador IANA real del dispositivo. |
| [`timezone 0.11.2`](https://pub.dev/packages/timezone/versions/0.11.2) | Datos IANA empaquetados y fechas con horario de verano; no se descarga información horaria en ejecución. |

Se consultaron metadatos oficiales de pub.dev y APIs/fuentes de las versiones descargadas. El lockfile añade 25 entradas sin cambiar las versiones previas. La compilación inicial de compatibilidad aprobó los cinco plugins con el Gradle recibido (109,9 s). Las dependencias transitivas de otras plataformas no implican que esta app Android las use. No hay llamadas HTTP/socket desde Dart; el enlace externo requiere que WhatsApp/navegador tenga conectividad.

## Implementación real

### Comunicación individual

`features/communications/communication_text.dart` valida estructura internacional explícita: **+** y 7–15 dígitos, país sin cero inicial; admite espacios, paréntesis y guiones, sin inferir país/prefijo ni comprobar existencia de cuenta. El número del path `wa.me` queda solo en dígitos; `Uri.https` codifica el mensaje. La referencia solicitada, [click to chat de WhatsApp](https://faq.whatsapp.com/5913398998672934), respondió sin contenido legible al navegador de consulta. No se presenta como documentación contrastada: se aplica el formato explícito de la petición T06 y se verifica su codificación/round-trip con pruebas; queda la comprobación en WhatsApp real.

`WhatsAppReminderAction` está en cada mensualidad **impagada del historial**, accesible también desde la ficha existente por «Cobros e historial». Abre un diálogo de pantalla completa con cliente, período, estado, importe histórico, destinatario temporal y mensaje editable. No escribe correcciones en la ficha. Los pagados no presentan la acción; antes de copiar/compartir/abrir se vuelve a leer el cargo, bloqueando un aviso pendiente si entretanto se pagó. La plantilla es respetuosa, incluye el cargo seleccionado y no suma otras mensualidades ni amenaza con cortar el servicio.

`communication_actions.dart` es el adaptador inyectable del SO: enlace externo, copia y compartir texto. No intenta enviar, no consulta contactos y no guarda estados «enviado/entregado». Si el enlace falla, el borrador se conserva y quedan disponibles Copiar/Compartir. Abrir un navegador se informa como enlace abierto, sin inferir que WhatsApp esté instalado ni que haya entrega. Los dobles toques se bloquean.

### Listados

En Cobros, un icono secundario con tooltip **«Compartir listado»**, junto al filtro, abre `ShareBillingReportAction`. El usuario debe elegir **Período completo** o **Vista filtrada**; hasta entonces compartir está deshabilitado. La vista filtrada recibe exactamente las filas ya seleccionadas por búsqueda/filtro de T04, sin duplicar su lógica ni cambiar el resumen global.

`BillingReport` recibe únicamente campos permitidos (`ReportEntry`: nombre, estado, importe y existencia de deuda anterior). Renderiza mes/año, fecha de generación, alcance, cantidad, pagados/sin pagar y sumas enteras de ese alcance. Conserva el orden T04. Las deudas anteriores se señalan por separado sin sumarlas en el importe del período. No incluye teléfono, dirección, notas, MAC, IP, IDs internos ni auditoría de pagos/anulaciones.

La vista previa muestra hasta **20 registros**, indicando el total y que el texto compartido incluye todo el alcance. Nunca se trunca silenciosamente un envío: si supera **60000 caracteres**, se bloquea y pide acotar con filtros. El botón final confirma la revisión y abre el panel nativo; cancelar no produce éxito. El resultado de selección de aplicación tampoco certifica recepción por WhatsApp. No se crean PDF, CSV, archivos de respaldo ni envíos masivos.

### Recordatorios

`reminder_plan.dart` prepara avisos de los días **2 y 3 a las 09:00 locales**, usando la fecha de candidatura de `BillingPeriod` T02. Horizon: mes local actual y cinco siguientes, solo fechas futuras, como máximo 12 avisos. IDs estables por fecha; mensajes genéricos sin cifras/nombres potencialmente obsoletos. No hay pagos, cargos ni suspensión desde un aviso.

`AndroidReminderScheduler` usa zona IANA real, datos empaquetados, canal `mi_red_reminders_v1`, icono monocromo y **`inexactAllowWhileIdle`**. `RemindersController` reutiliza **`app_settings.notifications_enabled`**, inicialmente falso, mediante un setter que modifica solo esa columna. Denegar/revocar permiso deja el flag desactivado y cancela avisos propios. Se conservan todos los demás campos de Ajustes. No se añadió una preferencia externa ni se migró SQLite v2.

El controlador agrupa operaciones idénticas, serializa intenciones distintas (incluido desactivar mientras se pide permiso), elimina IDs expirados, reemplaza planes al cambiar fecha/zona y evita duplicados al reabrir/reanudar. Un fallo de inicialización es reintentable; un fallo al activar limpia el plan parcial y conserva opt-out. El cambio de zona/reloj se aplica al abrir o reanudar; no hay un servicio continuo de vigilancia del reloj.

`BillingLifecycle` conserva su conciliación financiera y añade inicialización/refresh independientes de recordatorios. Al tocar un aviso, se abre `/billing?filter=unpaid&reminder=…&request=…`; la clave de la vista cambia para restablecer período actual/filtro incluso si Cobros estaba mostrando otro mes. La barrera T04 concilia antes de presentar datos. Se contemplan lanzamiento frío y callback con app viva; payloads desconocidos se ignoran.

Ajustes contiene switch, estado del permiso, explicación de días/hora aproximada, acceso a ajustes Android y **«Probar notificación»** solo bajo acción explícita con permiso/opt-in. El permiso se pide al activar, nunca al arrancar. El resto de Ajustes continúa sin implementar. Android/batería pueden retrasar la entrega; las notificaciones no son fuente de verdad financiera.

La petición T06 amplía explícitamente el aviso original del día 2 al día 3. Se actualizan PRODUCT_SPEC y el plan para reflejarlo; ninguna regla del motor se cambia. T07 deberá incluir el booleano existente en sus respaldos y reconstruir el plan según permisos/zona del dispositivo; la caché operacional del plugin y los permisos Android no son un respaldo ni se restauran como autorización.

## Android y permisos

- Desugaring `com.android.tools:desugar_jdk_libs:2.1.4`; Java objetivo 17 existente. No upgrades de Gradle/AGP/Kotlin.
- `POST_NOTIFICATIONS` al activar en Android 13+, `RECEIVE_BOOT_COMPLETED` y los dos receivers oficiales para programación/reinicio/actualización de paquete.
- Sin `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM`, contactos, SMS ni almacenamiento. Se elimina `VIBRATE` del manifiesto fusionado y se configura el canal sin vibración.
- El Debug conserva `INTERNET` de la plantilla para Flutter; no se añade al manifiesto principal. AndroidX aporta su permiso interno de firma para receivers no exportados.
- `ic_notification.xml` y `raw/keep.xml` conservan el icono en recursos Release. Firma de distribución sin cambios.

Referencias: [configuración de notificaciones 22.3.3](https://pub.dev/packages/flutter_local_notifications/versions/22.3.3), [restricciones de alarmas exactas Android](https://developer.android.com/about/versions/14/changes/schedule-exact-alarms), [enlace directo con fallback](https://pub.dev/packages/url_launcher/versions/6.3.3).

## Pruebas y archivos

Las **145 pruebas anteriores** permanecen; solo se sustituye la expectativa de Ajustes provisional por su sección real Recordatorios en navegación/smoke. Se añaden **35 pruebas** (9 de textos/reportes, 11 de planificación/controlador y 15 de widgets). Cubren número ambiguo/internacional, Unicode/URL, tarifa histórica, pago/anulación, privacidad, selección de alcance, vacío/preview limitado, fallos y cancelación, doble toque, opt-in/denegación/revocación, plan idempotente/cancelación, inicialización fallida, plan parcial, zona/DST/febrero/bisiesto, reinicio simulado, payload frío/vivo y preservación contable. Matriz: 320/400 dp, ambos temas, texto 100/200 %, teclado y errores desplazables. Sin MethodChannels directos en widget tests; adaptadores falsos inyectados. Los hit tests y asserts de Flutter no se desactivan.

Las primeras pasadas detectaron el ancestro Material del switch y una cabecera que dejaba poca altura al 200 %; se corrigió el producto y se repitió la matriz. Un test horario se ajustó para comparar zonas dentro del mismo mes local, evitando confundir una diferencia legítima de horizonte al cruzar medianoche UTC.

Archivos nuevos: cuatro en `features/communications`, tres en `features/reminders`, cinco de tests/fakes, icono/keep y este informe. Modificados: `pubspec.yaml`/lock, Gradle y manifiesto de app, `app_router.dart`, `billing_lifecycle.dart`, `billing_screen.dart`, `billing_widgets.dart`, `settings_screen.dart`, `SettingsService`, los dos tests de navegación/smoke, PRODUCT_SPEC/IMPLEMENTATION_PLAN y README. Sin cambios en esquema/generados/migraciones/snapshots, `BillingService`, `PaymentService`, calendario, servicios/validadores de dispositivos, minSdk, applicationId ni firma.

| Carpeta | Archivos nuevos concretos |
|---|---|
| `lib/features/communications/` | `communication_text.dart`, `communication_actions.dart`, `whatsapp_reminder.dart`, `share_billing_report.dart` |
| `lib/features/reminders/` | `reminder_plan.dart`, `reminder_scheduler.dart`, `reminder_providers.dart` |
| `test/features/communications/` | `communication_text_test.dart`, `communication_widgets_test.dart`, `fake_communication_actions.dart` |
| `test/features/reminders/` | `reminders_test.dart`, `fake_reminder_scheduler.dart` |
| `android/app/src/main/res/` | `drawable/ic_notification.xml`, `raw/keep.xml` |

### Comandos y resultados

| Comando | Resultado efectivo |
|---|---|
| `flutter pub get` | Correcto; cinco dependencias directas nuevas, sin actualizar versiones anteriores. Avisa de 13 versiones más recientes incompatibles con las restricciones actuales; no se amplían. |
| `dart format .` | Correcto al cierre: 71 archivos, 0 cambios, 1,53 s. |
| `flutter analyze --no-pub` / `flutter analyze` | Ambos sin incidencias: 4,5 s y 64,8 s, respectivamente. Análisis sin opciones repetido al cierre en `build/t06-final-analyze.log`. |
| Pruebas seleccionadas de integración de widgets/diseño/arranque | **44 aprobadas**, 41 s. |
| `flutter test --concurrency=1 --reporter expanded` | **180 aprobadas**, 2 min 03 s: 145 anteriores + 35 nuevas. |
| `flutter build apk --debug` | Correcto, APK normal, compilación final 15,1 s. |
| `flutter build apk --release` | Correcto, 173,1 s, 62,5 MB. APK sin firma de distribución, como antes de T06. |
| `apksigner verify` | Debug correcto; Release falla con `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`: falta la firma de distribución prevista para T08; no se intenta firmarlo ni instalarlo. |
| `aapt dump permissions/resources` | Release: notificaciones, reinicio y permiso interno AndroidX de firma; sin INTERNET/exact alarms/VIBRATE/contactos/almacenamiento. `drawable/ic_notification` está conservado. |
| `git diff --check` | Correcto. Git avisa de conversión LF/CRLF según la configuración del equipo; sin errores de whitespace. |

Logs locales en `build/t06-{baseline-analyze,baseline-tests,baseline-debug,analyze,feature-tests,tests,debug,release}.log` y `build/t06-final-analyze.log`. Release emite un aviso de tree-shaking sobre la familia opcional `CupertinoIcons`, aunque la app utiliza Material/Lucide y los recursos efectivos se generan. No se agrega `cupertino_icons` sin uso para ocultarlo; ambos APK compilan y las vistas verificadas muestran sus iconos.

## Aceptación Android

AVD **MiRed_T05_API35 / emulator-5556**, dedicado y confirmado con solo las dos altas sintéticas T05 y su pago existente. No se instala ni se cambia el AVD original emulator-5554. APK normal `lib/main.dart`, actualizaciones `adb install -r`, sin desinstalar/borrar datos. Las dos actualizaciones conservaron el SHA-256 de SQLite antes de abrir la app; se guarda además solo una huella lógica de clientes/dispositivos/cargos/pagos y campos de ajustes distintos al opt-in.

Comprobaciones ya observadas: arranque frío `Status: ok` (4,797 s y 3,353 s); sin prompt automático. Denegar permiso mantuvo switch/flag en falso; conceder desde el switch persistió verdadero y creó **10 alarmas/10 IDs únicos**, zona **America/New_York**, modo `inexactAllowWhileIdle`, fechas futuras de noviembre a marzo porque los días 2/3 de octubre ya pasaron. «Probar notificación» produjo un aviso genérico visible en el panel Android.

- **Toque con app activa:** abre Octubre 2026/Pendientes. **Toque frío:** se termina el proceso con `run-as … kill -9` sin force-stop, se comprueba que no existe PID y se toca el aviso pendiente; aparece nuevo proceso y Cobros actuales con Pendientes. No se usa un lanzamiento manual para simular este resultado.
- **Reinicio real:** `adb -s emulator-5556 reboot`; después de `sys.boot_completed=1`, antes de abrir la Activity, AlarmManager ya contiene las **10 alarmas activas** del receiver oficial, con próximas fechas locales a las 09:00. El receiver puede crear un proceso sin que se haya abierto la interfaz.
- **Reporte nativo:** alcance completo: 2 clientes, 1 pagado, pagado 10025 y pendiente 5075 unidades menores; alcance filtrado Pendientes: 1 cliente, pagado 0 y pendiente 5075. El panel Android abre aunque no exista WhatsApp; se cancela con Atrás sin seleccionar app ni destinatario y Mi Red muestra **«Compartir cancelado»**. No se transmite nada.
- **Mensaje nativo:** previsualización clara/oscura con cargo histórico; número vacío bloquea abrir con explicación internacional y conserva el borrador. «Copiar mensaje» funciona mediante acción explícita. No se prueba entrega ni apertura de WhatsApp instalado.
- **Desactivación real:** opt-in SQLite vuelve a 0, caché del plugin vacía y **0 alarmas activas**. La primera lectura amplia de `dumpsys alarm` incluía el historial de cancelaciones; se repite distinguiendo las entradas activas `RTC_WAKEUP #…`, comprobando 10 al activar y 0 al desactivar. No fue un fallo de cancelación.
- **Preservación final:** huella lógica idéntica a la inicial, SQLite `user_version=2`, `integrity_check=ok`, `foreign_key_check` sin filas. Los datos contables, dispositivos y demás ajustes no cambiaron. El opt-in, único campo modificado intencionalmente, queda desactivado al cerrar la revisión. Cero cierres fatales del paquete en el crash buffer desde el último reinicio.
- Un `am start -W` inmediatamente después del segundo arranque del AVD informó `Status: timeout`, aunque la UI quedó accesible y completó el recorrido. Se repitió un arranque normal tras `am force-stop` en este AVD sintético: **`Status: ok`, 2676 ms**. No se atribuye a resolución del problema histórico de teléfono/DDS.
- AVD real: 320 × 640 dp, texto 100 %, ambos temas, modo avión durante el recorrido. La matriz 400 dp/200 %/teclado pertenece a widgets, no se atribuye al dispositivo. Se restaura tema claro/conectividad, se apaga solo emulator-5556 y se confirma que emulator-5554 continúa disponible. El almacenamiento sintético se conserva en `build/t05-avd`.

### Capturas reales

PNG originales de ese AVD, revisados visualmente, sin recreación ni edición; contienen exclusivamente datos sintéticos. Como en T05, `docs/screenshots/` está excluido de Git y las capturas están disponibles localmente.

| Vista | Evidencia |
|---|---|
| Ajustes, desactivado inicialmente | [Claro](screenshots/t06/settings-off-light.png) |
| Permiso Android / denegación | [Solicitud](screenshots/t06/notification-permission.png) · [Denegado](screenshots/t06/settings-denied-light.png) |
| Ajustes, permiso concedido y 10 avisos | [Claro](screenshots/t06/settings-enabled-light.png) · [Oscuro](screenshots/t06/settings-enabled-dark.png) |
| Borrador individual | [Claro](screenshots/t06/message-light.png) · [Oscuro](screenshots/t06/message-dark.png) |
| Validación y copia explícita | [Error](screenshots/t06/message-error-dark.png) · [Copiado](screenshots/t06/message-copied-dark.png) |
| Listado completo / filtrado | [Completo oscuro](screenshots/t06/report-dark.png) · [Filtrado claro](screenshots/t06/report-filtered-light.png) |
| Panel Android / cancelación | [Panel nativo](screenshots/t06/native-share-sheet.png) · [Cancelado](screenshots/t06/report-light-cancelled.png) |
| Aviso genérico / apertura fría | [Notificación](screenshots/t06/notification-drawer.png) · [Cobros/Pendientes](screenshots/t06/notification-cold-opened-billing.png) |
| Ajustes desactivados al terminar | [Estado final](screenshots/t06/settings-disabled-after-review.png) |

## Límites y parada

WhatsApp no está instalado en este AVD: no se afirmará entrega ni envío real. La validación de URL/errores usa adaptadores y queda la prueba posterior en teléfono con WhatsApp. Los avisos son aproximados, con horizonte limitado que se renueva al abrir/reanudar; no se garantiza entrega bajo restricciones del fabricante o force-stop. No se revalida DDS/DevFS ni se dispone de teléfono físico. Release compila sin firma de distribución; no se crean claves.

Finalizar T06 y esperar revisión. No iniciar T07/T08.
