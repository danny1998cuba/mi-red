# Hoja de ruta Codex — 8 tareas, MVP

Trabajar en secuencia; tras cada tarea detenerse y entregar un informe corto. Estimación: **35–55 horas humanas efectivas** distribuidas aproximadamente en **7–12 jornadas de trabajo concentrado** (no garantiza plazo calendario). Precio de amistad propuesto: **USD 300** por el alcance documentado; trabajo fuera de alcance se acuerda aparte.

## T01 — Bootstrap (3–5 h)
- Crear proyecto Flutter Android con nombre provisional `mi_red`, appId propio estable y Material 3.
- Tema claro/oscuro; navegación inferior Inicio/Clientes/Cobros/Ajustes, pantallas placeholder y gestión básica de errores.
- Añadir Riverpod y go_router; organizar por feature. Añadir README de setup.
- **Aceptación:** corre en emulador/dispositivo, navega entre 4 pantallas, `flutter analyze` y `flutter test` pasan.

## T02 — Persistencia y motor de fechas (5–7 h)
- Drift+SQLite con tablas, claves, índices y migración inicial.
- Repositorios mínimos; funciones puras para períodos, corte día 30/último día, candidato el 3.
- Generación idempotente de cargos, snapshot de tarifa, altas/archivo, anulaciones y estados derivados.
- **Aceptación:** tests de noviembre/diciembre, enero/febrero, febrero bisiesto, apertura repetida, tarifa individual, cliente archivado y deuda histórica.

## T03 — Clientes y dispositivos (5–8 h)
- Listar, buscar, registrar, editar, archivar/reactivar, detalle y dispositivos ilimitados con MAC normalizada.
- Formularios validados, estados vacíos, mensajes de error.
- **Aceptación:** gestión CRUD funcional offline y persistente tras reinicio; los clientes con historial se archivan, no se borran accidentalmente.

## T04 — Cobros y pagos (6–9 h)
- Listado por período y estado; registro de pago completo, historial y anulación con confirmación.
- Integrar reconciliación segura al entrar en la app/listado.
- **Aceptación:** sin duplicados; marcar pago cambia vistas y sumas; una tarifa cambiada no reescribe cargos históricos; día 3 candidato, sin corte automático.

## T05 — Dashboard y pulido de flujo (3–5 h)
- Resumen y acciones rápidas; indicadores del período y candidatos con deuda anterior; filtros y pequeñas mejoras UX.
- **Aceptación:** cifras consistentes con consultas y usabilidad en pantalla pequeña.

## T06 — WhatsApp, reportes y recordatorios (4–7 h)
- Abrir WhatsApp/chat con mensaje prellenado, teléfono válido y sin envío automático.
- Compartir reporte de texto del período/filtro mediante diálogo nativo (incluye elección de WhatsApp).
- Recordatorios locales inexactos los días 2 y 3 (ampliación explícita T06), con ajuste optativo para activarlos/desactivarlos. Al tocar, abrir Cobros actualizado.
- **Aceptación:** no requiere internet para generar texto/estados; avisos no cambian la BD; funcionamiento digno si WhatsApp está ausente y si se deniegan permisos.

## T07 — Backup y restauración (5–8 h)
- Incluir la IP opcional por dispositivo incorporada en SQLite v2/T03.2 y definir compatibilidad con respaldos sin ese campo. Esta nota no adelanta la implementación de T07.
- Exportación externa con SAF, JSON versionado con checksum; restauración con previsualización, validación, copia previa y transacción.
- Comprobar que no dependa del sandbox privado. Avisar privacidad del archivo.
- **Aceptación:** ciclo exportar/restaurar íntegro en Android real, incluido archivo corrupto, incompatibilidad y cancelación sin pérdida de datos.

## T08 — QA y APK firmado (4–6 h)
- Revisión de onboarding, permisos, transiciones, offline, rotación, reinstalación/restauración, actualización de APK.
- Tests, compilación `flutter build apk --release`, firma y guardar keystore FUERA de Git.
- Guía de instalación, respaldo y actualización, build reproducible y lista de limitaciones.
- **Aceptación:** APK funcional en teléfono objetivo, sin red, con pruebas de usuarios y respaldo recuperable.

## Pruebas críticas de negocio
| Caso | Resultado esperado |
|---|---|
| Ciclo 2026-12 | Corte 2026-11-30, candidato 2026-12-03 |
| Ciclo 2027-03 | Corte 2027-02-28 |
| Ciclo 2028-03 | Corte 2028-02-29 |
| Cobro repetido | Mismo clientId+periodKey, exactamente un cargo |
| Cambio de tarifa | Cargos antiguos sin alteración |
| Pago de período nuevo con viejo pendiente | Cliente sigue mostrando deuda histórica |
| Anulación de pago | Cargo vuelve a pendiente/candidato según fecha |
| Archivo del cliente | Sin cargos nuevos, historial preservado |
| Restauración inválida | Base de datos actual intacta |
| WhatsApp no disponible | Texto copiable o compartir general |

## Entrega de cada tarea Codex
Responder: (1) resumen; (2) archivos; (3) decisiones; (4) pruebas y comandos; (5) riesgos/bloqueos; (6) siguiente tarea sugerida, SIN implementarla. Nunca avanzar de T01 a T02 sin revisión del resultado.

## Orden práctico
T01 -> T02 -> T03 -> T04 -> T05 -> T06 -> T07 -> T08. En pruebas tempranas de T02 verificar migraciones y consistencia antes de construir pantallas.

## Tiempo y costo (no promesas)
- 35–55 horas, 7–12 jornadas enfocadas si Codex y el entorno funcionan bien.
- Precio de amistad US$300 incluye APK, código, guía y una ronda de arreglos de bugs del alcance acordado.
- No incluye integraciones con redes, mensajes automáticos, nube, ampliaciones ni nuevas funciones.
