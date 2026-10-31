# Tipo de dispositivo como texto libre

Fecha: 2026-10-30. Cambio puntual posterior a Fase C, considerada terminada por instrucción del usuario.

El selector se sustituye por un campo de texto obligatorio en alta y edición. Permite tipos propios, recorta espacios exteriores y conserva el valor predeterminado «Antena». La ficha muestra el tipo registrado. Los códigos históricos conservan sus etiquetas españolas; editar otros campos sin cambiar el tipo no reescribe esos códigos.

## Persistencia y compatibilidad

- SQLite sube de 2 a 3: se retira únicamente el CHECK de catálogo de `devices.type`; sigue siendo TEXT NOT NULL. La app y el importador exigen texto no vacío.
- Migración desde v1/v2 transaccional: desde v1 se añade IP y después se reconstruye únicamente `devices`, copiando todas sus columnas y recuperando sus índices. Se verifica integridad referencial antes del commit y se reactivan FK incluso ante fallo. No se convierten tipos ni se alteran clientes, cobros, pagos o ajustes.
- Se conservan los snapshots y helpers históricos v1/v2; se añade v3. Se utiliza [TableMigration de Drift](https://drift.simonbinder.eu/migrations/api/#changing-column-constraints) para modificar la restricción.
- `.miredbk` conserva formato cifrado 1, AES-GCM y los parámetros PBKDF2 existentes. La versión del esquema de datos es independiente del formato criptográfico.

| Copia | Importación en esta versión |
|---|---|
| Formato 1, esquema 2 completo | Sí, sin transformar valores históricos |
| Formato 1, esquema 3 | Sí, incluidos tipos propios |
| Sin IP, esquema desconocido o futuro | Rechazo explícito sin reemplazo |
| Copia dañada o contraseña incorrecta | Rechazo sin reemplazo |

Las exportaciones nuevas declaran esquema 3 y la vista previa muestra el esquema real de la copia seleccionada. Las versiones anteriores de Mi Red rechazan estas copias nuevas; no se ofrece downgrade. Las copias actuales de esquema 2 siguen siendo importables en la app actualizada.

## Archivos

- Formulario, ficha, etiquetas y servicio: `lib/features/clients/{device_form_screen.dart,client_detail_screen.dart,client_values.dart,data/device_service.dart}`.
- Esquema y migración: `lib/core/database/{schema.drift,app_database.dart,app_database.g.dart}`, nuevo `drift_schemas/drift_schema_v3.json` y helpers de migración.
- Copias: `lib/features/backups/{backup_snapshot.dart,backup_section.dart}`. No cambia el cifrado ni el reemplazo transaccional.
- Pruebas: nuevo `test/core/database/device_type_migration_test.dart`; ampliaciones en pruebas de clientes y respaldos. Los consumidores de DeviceService en otras pruebas y herramientas pasan String en lugar del enum cerrado; las herramientas de comprobación reconocen v3.
- Documentación: PRODUCT_SPEC, DATA_MODEL, IMPLEMENTATION_PLAN y README actualizados.

## Verificación

- `dart run build_runner build`: generado Drift. La opción obsoleta `--delete-conflicting-outputs` se ignoró; no es necesaria.
- `dart run drift_dev schema dump lib/core/database/app_database.dart drift_schemas/drift_schema_v3.json` y `dart run drift_dev schema generate drift_schemas/ test/generated_migrations/`: correctos. Snapshots y helpers históricos sin cambios.
- `dart format .`: correcto, 103 archivos.
- `flutter analyze --no-pub`: sin incidencias.
- Pruebas focalizadas de migración, dispositivos y copias: 72 aprobadas.
- `flutter test --no-pub`: **308/308 aprobadas**, incluidas las reglas de ciclos, febrero, duplicados, tarifa individual, archivado, pagos y restauración.
- Regresiones nuevas: v2→v3 conserva todas las filas y objetos ajenos a la tabla en reaperturas; relaciones inválidas revierten la reconstrucción; copia sintética cifrada de esquema 2 se importa íntegra; esquema 3 conserva tipos personalizados al cifrar/restaurar/exportar; entradas vacías, no textuales y versiones incompatibles se rechazan.
- Pruebas de interfaz ampliadas: alta con tipo propio y trim, edición de un tipo anterior, reapertura de un tipo nuevo y rechazo de vacío sin escritura.
- `flutter build apk --debug --no-pub`: correcto, 41,3 s; APK en `build/app/outputs/flutter-apk/app-debug.apk`.
- `git diff --check`: correcto.

## Límites y siguiente paso

Sin dependencias nuevas, servicios remotos ni cambios financieros. Se usan exclusivamente fixtures sintéticos. Esta iteración no instala ni restaura datos en el teléfono del usuario; la compatibilidad se comprueba con SQLite real y copias cifradas en pruebas automatizadas. El APK Debug no constituye una entrega Release firmada.

La compilación terminó con avisos del entorno: `cryptography_flutter` y `flutter_file_dialog` todavía aplican Kotlin Gradle Plugin, y las herramientas Android emiten una advertencia de versiones XML de SDK 3/4. No bloquearon el build. Su mantenimiento futuro requiere versiones de esos plugins compatibles con Built-in Kotlin y alinear las herramientas del SDK; no se cambió el toolchain en esta tarea. Sin bloqueos pendientes para este cambio.

Siguiente paso sugerido: revisar este cambio en el dispositivo objetivo y continuar el proceso de firma/distribución acordado cuando se solicite. No se inicia otra fase en esta iteración.
