# AGENTS.md — Mi Red (MVP Android offline)

## Objetivo
Crear una app Flutter Android, de una sola persona administradora, 100 % operativa offline para clientes, dispositivos, mensualidades, pagos y respaldos. No existe backend, cuenta, sincronización, API de router ni publicación en tiendas. WhatsApp es una integración externa iniciada por el usuario y necesita conectividad para enviar.

## Fuente de verdad
Leer ANTES de cada cambio:
1. `docs/PRODUCT_SPEC.md` (alcance y reglas)
2. `docs/DATA_MODEL.md` (persistencia y estados)
3. `docs/IMPLEMENTATION_PLAN.md` (tareas y criterios)

Si hay conflicto, priorizar reglas de producto, informar la discrepancia y no inventar funcionalidades.

## Stack objetivo
Flutter estable y Dart, Material 3, Riverpod, go_router, Drift + SQLite. Usar url_launcher para abrir chats, share_plus para compartir texto, flutter_local_notifications para recordatorios locales, y un selector de documentos compatible con Android Storage Access Framework para backup/exportación. Comprobar la documentación vigente y la compatibilidad de versiones antes de agregar dependencias.

## Normas obligatorias
- Código y nombres de identificadores en inglés; interfaz y mensajes en español.
- Priorizar simplicidad: feature-first ligera (`features/clients`, `features/billing`, `features/dashboard`, `features/settings`; `core/database`, `core/services`). Sin clean architecture ceremonial, service locators innecesarios, repositorios genéricos ni codegen adicional salvo el requerido por Drift/Riverpod.
- Ninguna dependencia de red para operaciones esenciales. No Firebase, login, telemetría, publicidad, analytics ni conexiones al router.
- Montos almacenados como **enteros en unidades menores**; jamás `double`/`float` para dinero. Configurar etiqueta de moneda desde Ajustes y no realizar conversiones.
- Operaciones críticas de BD en transacciones; claves únicas para impedir cargos duplicados; integridad referencial.
- Los pagos son históricos. Nunca reescribirlos al recalcular un ciclo ni cambiar cobros anteriores por modificar tarifas.
- Fecha `YYYY-MM` para identificar un período; las fechas de cobro y posible suspensión se derivan explícitamente para ese período.
- Ninguna tarea en segundo plano es necesaria para que la deuda sea correcta: reconciliar cuando se abre la aplicación y antes de mostrar cobros.
- Las notificaciones son **recordatorios**, no la fuente de verdad. No prometer exactitud al minuto.
- WhatsApp: preparar mensaje, abrir conversación o compartir reporte, nunca enviar automáticamente. No reportar un mensaje como enviado sin confirmación de WhatsApp.
- Respaldo externo creado mediante selector del sistema, con versión, validación de esquema, verificación de integridad y restauración transaccional. No basarse únicamente en archivos privados eliminados con la desinstalación.
- No compartir de forma predeterminada números, MAC o direcciones en reportes de WhatsApp: el reporte básico lleva únicamente nombre, mensualidad, monto y estado.
- Prohibido registrar datos reales o sensibles de clientes en logs, fixtures o capturas de pruebas.
- No incluir llaves de firma en Git. Documentar cómo generar y custodiar el keystore.

## Forma de trabajo para Codex
- Ejecutar **una sola tarea** del plan por iteración. No adelantar fases.
- Antes de editar: resumir archivos afectados, dependencias y plan mínimo.
- Después de editar: ejecutar `dart format .`, `flutter analyze`, `flutter test` cuando el entorno lo permita; indicar claramente errores o bloqueos.
- Cada tarea entrega: funcionalidad implementada, pruebas añadidas, decisiones asumidas, comandos ejecutados y riesgos restantes.
- Probar reglas de días 30/3, febrero, duplicados, tarifa individual, archivado y respaldo/restauración.
- Si falta una definición, aplicar solo el default descrito en PRODUCT_SPEC, documentarlo y evitar añadir funcionalidades nuevas.

## Definition of Done global
Aplicación instalable en Android real sin internet; clientes y dispositivos editables; cargos mensuales sin duplicados; pagos completos y candidatos a suspensión coherentes; WhatsApp y compartir reporte bajo acción del usuario; respaldo fuera del sandbox y restauración verificable; APK release firmado; instrucciones de instalación y recuperación.
