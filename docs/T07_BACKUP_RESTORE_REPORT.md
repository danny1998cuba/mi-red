# T07 — Respaldos cifrados y restauración segura

29–30-10-2026. Solo T07. No se modifica el esquema SQLite v2, el motor de fechas/cobros/pagos ni la firma de distribución.

## Estado de partida y dependencias

Checkpoint real: `450dce6` (`feat: communications`), árbol limpio. Baseline repetida antes de editar: análisis limpio (38,2 s), **180 pruebas** (2 min 41 s), Debug normal correcto (50,2 s). Flutter 3.47.8 stable / Dart 3.13.7, Java 21.0.11 con target 17, AGP 9.1.0, Gradle 9.3.1, Kotlin 2.4.0, compile/targetSdk 36, minSdk 24 y `com.mired.offline` conservados.

Dependencias exactas añadidas tras consultar pub.dev y las fuentes descargadas:

| Paquete | Decisión |
|---|---|
| [cryptography 2.9.0](https://pub.dev/packages/cryptography/versions/2.9.0) | AES-256-GCM, PBKDF2-HMAC-SHA256 y generador seguro de la plataforma. |
| [cryptography_flutter 2.3.4](https://pub.dev/packages/cryptography_flutter/versions/2.3.4) | APIs nativas Android y fallback en isolate; Java 17/compileSdk 36/minSdk 24 compatibles con el proyecto. |
| [flutter_file_dialog 3.3.3](https://pub.dev/packages/flutter_file_dialog/versions/3.3.3) | SAF explícito con `saveFile` / `pickFile`, API 24+, Flutter >=3.44/Dart >=3.12; su Gradle contempla AGP 9 con built-in Kotlin desactivado. |

El lockfile añade únicamente estas tres entradas (24 líneas), sin cambiar versiones existentes. `flutter pub get` completó; conserva el aviso de 13 versiones más recientes incompatibles, sin ampliar restricciones. Build inicial de compatibilidad Android correcto (66,8 s). No se añaden permisos de almacenamiento, nube ni servicios remotos.

Android documenta [PBKDF2withHmacSHA256 desde API 26](https://developer.android.com/reference/javax/crypto/SecretKeyFactory). Si el proveedor nativo no lo soporta, se usa `BackgroundPbkdf2` con exactamente SHA256, 256 bits y 250000 iteraciones, sin reducir coste ni cambiar formato. La prueba simula ese error y verifica interoperabilidad con el mismo archivo. API 24/25 físico no se da por probado solo por ese test.

## Formato y límites

`.miredbk` es binario. Formato 1 tiene algoritmo fijo AES-256-GCM, clave de 256 bits, PBKDF2-HMAC-SHA256 de **250000 iteraciones**, sal de **16 bytes** y nonce de **12 bytes**, nuevos mediante `Random.secure()` en cada exportación. No se reutilizan sal/nonce deliberadamente.

| Bytes | Contenido |
|---|---|
| 0–7 | Magic ASCII `MIREDBK` + byte 0 |
| 8–11 | Versión 1, uint32 big-endian |
| 12–15 | Iteraciones 250000, uint32 big-endian |
| 16–31 | Sal |
| 32–43 | Nonce |
| 44… | Ciphertext y tag GCM final de 16 bytes |

Los **44 bytes del encabezado son AAD**. Una versión/coste desconocidos se rechazan antes de derivar, evitando trabajo arbitrario solicitado por un encabezado hostil. Contraseña incorrecta o alteraciones de sal/nonce/ciphertext/tag no autentican; nunca se inicia SQL de reemplazo. No se usa un checksum sin clave como autenticación.

Dentro del cifrado hay JSON UTF-8 con `format`, `backupFormatVersion`, `sourceSchemaVersion`, `createdAtUtc`, `appIdentifier`, `counts` y `records`. Tablas/columnas son una allowlist fija de las cinco tablas reales. Filas ordenadas por ID, columnas y claves en orden estable. Dinero, flags, IDs de ajustes y auditoría mantienen tipos SQL exactos (instantes INTEGER de milisegundos, sin conversiones local/UTC); solo `createdAtUtc` del archivo es ISO UTC. Se prueban enteros monetarios hasta `9223372036854775807`.

Límites: **16 MiB de payload**, **16 MiB + 60 bytes de archivo**, **100000 filas totales**, texto por campo hasta 65536 caracteres, IDs hasta 1024 y contraseña hasta 1024 caracteres (nuevas: mínimo 12 caracteres Unicode). La exportación estima volumen en SQLite antes de leer filas y usa codificación JSON acotada por bloques; importación comprueba longitud antes de cargar el archivo y durante la lectura. No hay compresión ni snapshots descifrados en documentos públicos. El proveedor SAF puede copiar un archivo grande a caché antes de que Dart compruebe su longitud; no se carga íntegro en memoria y se limpia la copia privada al salir.

Compatibilidad: formato 1 solo acepta **schema 2**, appIdentifier exacto y todas las columnas, incluido `ip_address: null`. No existió un formato implementado antes de T07; archivos sin IP, JSON público o formatos/esquemas futuros se rechazan. No se inventan columnas ni se normaliza/recalcula historia al importar.

## Exportación y SAF

`BackupService.capture` lee dentro de una transacción consistente y comprueba FK/integridad. Incluye clientes activos/suspendidos/archivados, ancla de reactivación, equipos/MAC/IP, cargos y tarifas históricas, pagos vigentes/anulados con notas/auditoría y todos los ajustes. No incluye permisos, alarmas, cachés, logs ni claves de firma.

El administrador introduce y confirma la contraseña, puede mostrar/ocultar campos y pulsa **Cifrar y elegir destino**. Se escribe únicamente el artefacto cifrado en un subdirectorio privado `mi_red_backup-*`; `saveFile(sourceFilePath: …)` crea el documento mediante el selector del sistema. El adaptador elimina sus temporales en `finally`, también al cancelar/fallar. El valor devuelto identifica el destino SAF: nunca se pasa a `File` como si fuera una ruta local. Cancelación no registra fecha ni éxito. Errores de espacio/permiso mantienen la base y permiten reintentar.

Solo después de guardado confirmado se actualiza `last_backup_at`. La copia contiene el **valor original previo a exportar** de ese campo; restaurarla lo conserva, no inventa una fecha de respaldo/importación nueva. El éxito muestra nombre sugerido, fecha y destino SAF realmente devuelto. Un destino del mismo teléfono no acredita protección ante pérdida del dispositivo: se recomienda otra copia en un lugar distinto.

Al importar, `pickFile(copyFileToCacheDir: true)` devuelve una copia privada que se comprueba contra el directorio de caché antes de leer. `cleanBackupCache` elimina solo los directorios propios `file_dialog-*` / `mi_red_backup-*` y el patrón estricto de temporales cifrados del primer ensayo del plugin, siempre dentro de la caché canónica y sin seguir enlaces. Se ejecuta antes/después de guardar/seleccionar; jamás borra el documento elegido ni archivos ajenos. Al reanudar se encontró un temporal cifrado dejado por la interrupción del proceso; se añadió esta limpieza y una prueba real de sistema de archivos que conserva entradas ajenas. La siguiente operación elimina huérfanos de una terminación abrupta. Exportar solo escribe bytes cifrados; importar copia el documento seleccionado, todavía sin autenticar, y nunca escribe el snapshot descifrado. Los controladores de contraseña se vacían al ejecutar, fallar o salir, y no usan autofill/IME personalizado. Strings y buffers internos de Dart/Android están sujetos al runtime: no se promete borrado forense de memoria.

## Validación, atomicidad y actualización

Antes de mostrar el resumen: autenticar, descifrar y validar formato/versiones, columnas exactas, recuentos, tipos, enteros, fechas válidas, períodos, unicidad de PK/cliente-período, referencias, estados, MAC/IP y un solo pago vigente por cargo con importe exacto. Los pagos anulados pueden conservar un importe distinto del cargo actual; no se imponen reglas nuevas de orden temporal que impedirían recuperar auditoría tras un cambio de reloj.

La previsualización enseña fecha, formato/esquema, recuentos de clientes/dispositivos/cargos/pagos (incluidos anulados), comparación con los actuales y advertencia inequívoca. Deben marcar **Entiendo que se reemplazarán mis datos actuales** y pulsar **Reemplazar datos**. Elegir otro archivo descarta la previsualización y aceptación anteriores incluso si el selector falla.

`DatabaseMaintenance` pausa refresh por lifecycle, conciliación explícita y recordatorios durante todo el modal/SAF. Al entrar espera la conciliación y operaciones de avisos ya iniciadas. El modal impide nuevas escrituras desde la UI y bloquea salida/doble toque durante operaciones. Las transacciones de la conexión Drift/SQLite serializan SQL; no se sustituye ni se cierra un archivo en uso.

`BackupService.restore` revalida el snapshot inmutable, toma una copia consistente previa en memoria y ejecuta **una sola transacción**: borrar pagos/dispositivos/cargos/clientes/ajustes, insertar padres y luego hijos con PK explícitas, comprobar integridad/FK y comparar todas las filas importadas con el snapshot. No desactiva foreign_keys, triggers ni índices. No hay AUTOINCREMENT/secuencias en este esquema. Se notifican watchers al commit, sin estados vacíos intermedios; cualquier excepción revierte también los borrados. SQLite conserva las páginas anteriores mediante su mecanismo transaccional ante cierre del proceso. No se copia un `.db` activo ni se implementa un intercambio de archivos.

La especificación anterior sugería una copia local previa persistente. La petición T07 concreta restauración mediante snapshot y transacción; se actualiza producto a copia previa **en memoria + rollback SQLite**, evitando crear otro archivo descifrado o una segunda contraseña. Esta protección no se presenta como respaldo externo ni como reemplazo de la exportación SAF.

Después del commit, los recordatorios se reconstruyen con `notifications_enabled` restaurado, permiso real y zona actual; no se solicita permiso ni se importan alarmas antiguas. Con permiso denegado se aplica opt-out T06. Si falla el SO, se informa **datos restaurados, recordatorios por revisar**, sin fingir rollback contable. Se invalidan las proyecciones y al cerrar el resultado se vuelve a Inicio. La conciliación T02 posterior puede añadir mensualidades desde el ancla activa hasta el período actual si la copia es antigua; se prueba separada de la importación, sin reescribir pagos ni reconstruir intervalos archivados.

## Archivos

- Nuevos `lib/features/backups/`: `backup_snapshot.dart`, `backup_cipher.dart`, `backup_documents.dart`, `backup_service.dart`, `backup_providers.dart`, `backup_section.dart`.
- Nuevo `lib/core/database/database_maintenance.dart`; integración mínima en `billing_providers.dart`, `billing_lifecycle.dart`, `reminder_providers.dart` y `settings_screen.dart`.
- Nuevos `test/features/backups/`: `backup_fixture.dart`, `backup_data_test.dart`, `fake_backup_adapters.dart`, `backup_widgets_test.dart`.
- `tool/t07_backup_fixture.dart`: diagnóstico opt-in para un AVD vacío nuevo; nunca importado desde `main.dart`. Rechaza BD con clientes/dispositivos/cargos/pagos. Fixture totalmente sintética, benchmark e interoperabilidad nativa/Dart; solo registra marcadores/coste/recuentos, no contenidos/contraseñas.
- `pubspec.yaml`/lock, README, PRODUCT_SPEC, DATA_MODEL, IMPLEMENTATION_PLAN y este informe.
- Sin cambios en esquema/generados/migraciones, `BillingService`, `PaymentService`, calendario, servicios/validadores MAC/IP, packageId, minSdk, Gradle, manifiesto ni firma.

## Verificación automática

**230 pruebas aprobadas: 180 existentes + 50 nuevas (31 de datos y 19 widgets)**, sin omitir ni desactivar pruebas anteriores o checks de hit-test. Cubren round trip de cinco tablas, precisión int64, copia vacía, reemplazo, pagos/anulados, FK/tipos/duplicados/versiones/límites, aleatoriedad/autenticidad, fallo real a mitad de importación con reapertura, emisiones reactivas, cancelación/fallos/reintento/doble toque, privacidad, limpieza real de caché, buffers nativos inmutables, fallback API24/25, coordinación con lifecycle y avisos tras commit. Matriz: 320/400 dp, claro/oscuro, texto 100/200 % y teclado.

| Comando | Resultado final |
|---|---|
| `dart format .` | 83 archivos formateados; pasada de cierre sin cambios. |
| `flutter analyze` / pasada final `flutter analyze --no-pub` | Sin incidencias; última pasada 73,4 s. |
| `flutter test --concurrency=1 --reporter expanded` | 230/230, 9 min 28 s. |
| `flutter test test/features/backups/backup_data_test.dart` | 31/31, 16 s. |
| `flutter build apk --debug` | Correcto, 94,4 s; APK normal, sin fixture de diagnóstico. |
| `flutter build apk --release` | Correcto, 169,8 s, 63,5 MB; **sin firma de distribución**. |
| `apksigner verify` | Debug válido; Release código 1, `DOES NOT VERIFY / Missing META-INF/MANIFEST.MF`, coherente con firma pendiente de T08. |
| Auditoría de permisos con `aapt` | Solo POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED y permiso interno signature de AndroidX; sin almacenamiento global/red/contactos/SMS/alarmas exactas. |
| `git diff --check` | Correcto; Git avisa únicamente de normalización LF/CRLF en Windows. |

Logs locales ignorados: `build/t07-final-analyze.log`, `build/t07-tests.log`, `build/t07-data-final.log`, `build/t07-debug.log`, `build/t07-release.log`. Se conservan los avisos de compatibilidad futura de Kotlin del plugin y del renderer Flutter; no se cambia el stack para ocultarlos. La auditoría confirma que esquema/generados/migraciones, servicios financieros/calendario, datos de clientes/dispositivos y toda la carpeta Android mantienen el contenido previo.

Pasadas preliminares detectaron un tipo común `Table` incompatible en el bucle de borrado (se sustituyó por cinco borrados tipados), una construcción `const` de JsonUtf8Encoder no disponible y dos imports redundantes; se corrigieron. El primer test de doble toque apuntaba al botón de Ajustes ya cubierto por el modal: se cambió a dos eventos reales sobre el mismo punto observado, sin desactivar checks. Se corrigió también descarte de la vista previa al fallar una selección nueva. Un comando `dart fix` con varias rutas no es válido; se repitió con una sola raíz y código de lint específico, sin cambiar reglas.

La primera aceptación criptográfica nativa encontró `UnsupportedError` durante el descifrado/limpieza. Los buffers devueltos por la plataforma pueden ser de solo lectura: ahora se copia el resultado a un `Uint8List` propio antes de limpiarlo y se prueba ese caso con un adaptador de salida inmutable. Además, el modo Dart usa constructores `DartAesGcm`/`DartPbkdf2` explícitos: el plugin se autorregistra globalmente y las factories genéricas no sirven para demostrar una comparación independiente en Android. El diagnóstico final confirmó clave nativa = clave Dart, descifrado Dart del archivo nativo y descifrado nativo del mismo archivo, con frase Unicode. No se cambió algoritmo ni se debilitó la autenticación para resolverlo.

## Aceptación Android

AVD nuevo **MiRed_T07_API35 / emulator-5558**, disco `build/t07-avd`, API35, 320×640/160 dpi, dos núcleos/2 GiB. No se usa, instala ni borra MiRed_API35/emulator-5554 ni MiRed_T05_API35/emulator-5556. `avdmanager` terminó con código 0 aunque repitió el aviso del SDK sobre `devices.xml`; el boot completó. Zona IANA America/New_York, reloj del equipo sin cambios y modo avión para el recorrido.

Se exportó por el diálogo nativo a **Descargas**, documento real `/sdcard/Download/MiRed-20261030T144238645464Z.miredbk`, 3633 bytes. El plugin devolvió `/document/11`, mostrado como referencia SAF; no se trató como ruta de `File`. Se seleccionó ese mismo documento en una restauración y autenticó correctamente sin red. Contraseña y archivos de copia no se publican ni se incorporan a Git.

Al cambiar naturalmente la fecha del 29 al 30 de octubre, el motor existente abrió noviembre y añadió un cargo, antes de la exportación. El snapshot utilizado contiene **3 clientes, 4 dispositivos, 5 mensualidades, 4 pagos y 1 ajuste**; la fixture inicial del día 29 tenía 4 mensualidades. Las huellas se capturaron después de esa conciliación, evitando atribuir al importador el cargo nuevo.

Se creó desde la UI un cuarto cliente sintético con tarifa 7,77 XTS, quedando 4 clientes/6 mensualidades. Cancelar el selector y la previsualización autenticada, contraseña incorrecta y una copia alterada en un byte conservaron exactamente la huella de las cinco tablas de esa base modificada. Cancelar exportación tampoco cambió `last_backup_at` ni dejó temporales propios. Los errores de almacenamiento/espacio y archivos incompatibles se verifican con adaptadores/tests; no se llenó el disco del emulador.

Tras marcar la aceptación y pulsar **Reemplazar datos**, la huella de todas las filas/columnas de las cinco tablas coincidió con el snapshot previo a exportar (incluido `last_backup_at` original). El cliente posterior desapareció, sin fusión ni duplicados. `integrity_check=ok`, `foreign_key_check` sin filas, `user_version=2`. Los providers mostraron Inicio actualizado y se reconstruyeron **10 alarmas activas** con opt-in restaurado y permiso real de QA. Tras detener/abrir la app, la huella siguió idéntica.

Se desinstaló **solo `com.mired.offline` de emulator-5558**, y se instaló el APK Debug normal final. La nueva instalación mostró 0 clientes/dispositivos/cargos/pagos, mientras el documento externo mantuvo sus 3633 bytes. Se concedió explícitamente el permiso de avisos en el entorno de QA —no se restauró desde el archivo— y se repitió selección SAF, contraseña, previsualización (3/0 clientes, 4/0 dispositivos, 5/0 mensualidades, 4/0 pagos) y confirmación. Resultado: **huella exacta de las cinco tablas**, integridad/FK correctas, esquema 2 y 10 alarmas activas. Volver a Inicio conservó la huella. No quedaron directorios temporales propios de exportación/importación. Se restauraron tema claro/conectividad y se detuvo únicamente el AVD T07; los otros AVD no se tocaron.

Limitación del entorno: el arranque normal inicial del 29-10 funcionó (4675 ms). Al reanudar el AVD el 30-10 apareció un ANR de System UI y el renderizado predeterminado quedó en splash. Para continuar únicamente la QA se lanzó el mismo APK normal con `adb -s emulator-5558 shell am start -W -n com.mired.offline/.MainActivity --ez enable-impeller false`. No se cambió manifiesto ni código del renderer. Hubo `Status: timeout` y, tras reinstalar, logcat registró `Displayed … +23s570ms`; se esperó a la pantalla y a las tablas antes de operar. El flag de opt-out está deprecado y **no es una solución de distribución ni acredita el arranque predeterminado en teléfono**. La causa del problema de renderer/AVD queda pendiente de diagnóstico en T08.

Benchmark nativo observado: PBKDF2-SHA256/250000, **1551 ms** primera ejecución y **979 ms** en la comprobación final (AVD API35, dos núcleos). No representa una garantía para teléfonos físicos. El diagnóstico terminó con `MI_RED_T07_CRYPTO_INTEROP_OK` y `MI_RED_T07_FIXTURE_OK clients=3 devices=4 charges=4 payments=4 settings=1`. Las dos pasadas fallidas previas no se presentan como aceptación aprobada.

Capturas ADB reales revisadas, exclusivamente sintéticas, en `docs/screenshots/t07/` (carpeta ignorada por Git, disponibles localmente):

| Evidencia | Captura |
|---|---|
| Selector de guardado SAF en Descargas | [saf-save-dialog.png](screenshots/t07/saf-save-dialog.png) |
| Guardado externo confirmado | [export-success-light.png](screenshots/t07/export-success-light.png) |
| Contraseña incorrecta / archivo alterado | [wrong-password-light.png](screenshots/t07/wrong-password-light.png), [corrupt-error-dark.png](screenshots/t07/corrupt-error-dark.png) |
| Aceptación explícita del reemplazo | [replacement-confirmed-dark.png](screenshots/t07/replacement-confirmed-dark.png) |
| Restauración sobre datos modificados | [restore-success-dark.png](screenshots/t07/restore-success-dark.png) |
| Instalación nueva vacía | [fresh-launch-state.png](screenshots/t07/fresh-launch-state.png) |
| Restauración tras reinstalar e Inicio actualizado | [fresh-restore-success-dark.png](screenshots/t07/fresh-restore-success-dark.png), [fresh-home-light.png](screenshots/t07/fresh-home-light.png) |

Algunas capturas de diagnóstico tomadas durante transiciones muestran un frame anterior; no se utilizan como evidencia de la previsualización final. Los conteos autenticados de la instalación nueva se comprobaron además en la jerarquía real y luego contra SQLite.

## Qué falta para terminar la aplicación

Inventario contrastado el **30-10-2026** con PRODUCT_SPEC, DATA_MODEL, IMPLEMENTATION_PLAN y el código actual. Una tarea histórica marcada como entregada no acredita por sí sola todos los puntos de la especificación ni la aceptación en teléfono. Esta sección documenta el trabajo restante; no lo implementa ni inicia T08.

### Funcionalidad pendiente del MVP

| Requisito y fuente | Estado comprobado | Trabajo y criterio de cierre |
|---|---|---|
| Configurar nombre del negocio, etiqueta de moneda y prefijo opcional — PRODUCT_SPEC «Ajustes y respaldo», DATA_MODEL `app_settings` | Las columnas y `SettingsService.update` existen; `settings_screen.dart` mantiene «La configuración del negocio aún no está disponible». Recordatorios y copias sí tienen UI. | Añadir formulario de lectura/edición con validación, persistencia y feedback. Verificar moneda vacía/personalizada y preservación de importes e historial. El prefijo configurado no debe convertir silenciosamente un teléfono local ambiguo en destinatario WhatsApp. No requiere asumir otra moneda ni convertir cantidades. |
| Corregir expresamente un cargo vigente todavía impagado — PRODUCT_SPEC «Mensualidades y pagos» | Se pueden cambiar tarifas de clientes y registrar/anular pagos. No hay método ni acción de UI para editar el importe de un cargo ya generado en `BillingService`/Cobros. Cambiar la tarifa conserva correctamente los cargos anteriores. | Implementar una operación concreta con validación y confirmación para el cargo vigente sin pago activo; proteger cargos pagados y períodos anteriores, conservar pagos anulados/auditoría y actualizar vistas. Esta brecha no autoriza cambiar fórmulas ni reescribir historia durante T07. |
| Mostrar recaudación del período en Inicio — PRODUCT_SPEC «Inicio y cobros» | `PeriodSummary.collectedMinor` ya calcula pagos vigentes. `_DashboardMetrics` muestra clientes activos, cantidad pagada, cantidad pendiente y monto por cobrar; no presenta el importe recaudado. | Acordar el ajuste de UI respecto a las cuatro métricas entregadas en T05 y mostrar la suma existente con la moneda configurada. Probar coincidencia con Cobros y exclusión de pagos anulados, sin sumar deuda anterior. No es un motor financiero nuevo. |
| Borrado definitivo de clientes sin historial, solo si se solicita — PRODUCT_SPEC «Clientes y equipos» | Existe archivo/reactivación y se conserva historia. `ClientService` no expone borrado definitivo. | Es **condicional**, no un bloqueo automático del MVP: si se solicita, definir y probar doble confirmación y rechazo ante cualquier cargo/pago, además de FK/dispositivos. Mantener archivo para clientes con historia. |

El modelo v2 ya contiene los campos necesarios para las tres primeras brechas; no se identifica una necesidad de migración solo para cerrarlas. No se propone mezclar este trabajo con el respaldo ni implementarlo sin una iteración autorizada.

### Aceptación y entrega pendientes

| Área | Cierre necesario |
|---|---|
| T07 en Android | **Recorrido API35 completado**, incluido documento externo real, rechazos/cancelaciones sin cambios, reemplazo, reinstalación, cinco tablas exactas e integridad/FK. Falta repetir exportación/recuperación en el teléfono objetivo para satisfacer literalmente la aceptación de Android real del plan, y verificar arranque predeterminado sin el flag temporal usado en el AVD. Los resultados y límites están en «Aceptación Android». |
| Teléfono objetivo | Instalar el APK normal y confirmar arranque independiente de DevFS, operaciones offline, clientes/dispositivos, cobros/pagos/anulaciones y recuperación de un documento externo. El problema histórico de arranque en teléfono no tiene causa confirmada; requiere logcat/resultado de lanzamiento del dispositivo disponible, sin borrar sus datos. |
| Compatibilidad y UX final — T08 | Recorrido en el teléfono de gama media, permisos, reanudación, rotación, teclado/texto grande, cambios de fecha/zona y actualización conservando SQLite. La matriz de widgets y API35 no acredita un dispositivo API24/25 real; allí falta smoke nativo de los plugins y del fallback criptográfico. Revisar estados vacíos y guía inicial existentes; no se presupone un asistente nuevo. |
| Integraciones en dispositivo | WhatsApp instalado: revisar destinatario/mensaje y retorno desde la app externa bajo acción del usuario; panel compartir sin atribuir entrega. Recordatorios: revisar permisos, reboot y restricciones de batería/fabricante en hardware objetivo. No garantizar exactitud al minuto ni confirmaciones de envío que WhatsApp no proporciona. |
| Firma y paquete de distribución — T08 | Generar/custodiar una clave autorizada fuera de Git, configurar firma sin contraseñas en el repositorio, producir APK Release firmado y verificarlo con `apksigner`. Probar instalación/actualización con el mismo applicationId y clave. Un Release compilado sin firma todavía no es una entrega distribuible. |
| Documentación y revisión con usuario — T08 | Completar guía de instalación/origen desconocido, actualización sin perder datos, contraseña/segunda copia y recuperación, custodia del keystore, versiones reproducibles y limitaciones finales. Revisar los escenarios de aceptación y la Definition of Done de AGENTS con el usuario. Los informes históricos T03.1 y DDS/DevFS no deben cerrarse retrospectivamente sin evidencia; el depurador no es requisito de ejecución del APK independiente. |

Orden propuesto: autorizar una iteración de brechas funcionales; después autorizar T08 para QA en hardware —incluida repetición del respaldo y diagnóstico de arranque—, documentación y firma. La implementación T07 y su recorrido en el AVD concluyen aquí. La aplicación estará terminada cuando la aceptación en teléfono y la Definition of Done global tengan evidencia, no solo por alcanzar un número de pruebas.

Se conservan las exclusiones del MVP: backend/nube/sincronización/login, conexiones al router, cortes automáticos, envío masivo o automático de WhatsApp, pagos parciales/en línea, conversiones de moneda, PDF y publicación en tiendas. No forman parte del trabajo necesario para cerrar este alcance.

## Procedimiento para el administrador y límites

1. Ajustes → Copias de seguridad → Crear copia. Introducir/confirmar una contraseña que puedas custodiar; elegir documento y esperar confirmación de guardado.
2. Conservar la contraseña separada y una segunda copia fuera del teléfono. **Olvidar la contraseña impide recuperar ese archivo**; no existe servidor ni recuperación.
3. Para recuperar: instalar la misma versión compatible → Ajustes → Restaurar copia → seleccionar `.miredbk` → contraseña → Comprobar copia → revisar cantidades/fecha → aceptar reemplazo → Reemplazar datos.
4. Esperar el resultado, volver a Inicio y revisar Cobros/Clientes y los recordatorios. Una copia antigua puede requerir conciliación posterior; no se alteran pagos históricos. Si el aviso posterior dice que los recordatorios fallaron, los datos ya fueron restaurados y hay que revisar Ajustes.

No se publican contraseñas ni archivos de respaldo del recorrido. Release continúa sin firma; teléfono físico, Android API24/25 físico y DDS/DevFS permanecen sin validación nativa. No se afirma resistencia de SQLite privado a un teléfono rooteado ni borrado forense del runtime. No se inicia T08.
