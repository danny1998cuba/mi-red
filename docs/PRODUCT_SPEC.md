# Mi Red — Especificación funcional MVP v1.1

Fecha base: 2026-10-27. Idioma: español. Plataforma: Android (APK por instalación directa).

Revisión T03.2 (2026-10-28): IP opcional por dispositivo; SQLite v1 se conserva mediante migración incremental a v2.

Ampliación explícita T06 (2026-10-29): recordatorios optativos los días 2 y 3, a las 09:00 locales de forma aproximada. No modifican la contabilidad ni el estado del servicio.

## 1. Problema y usuario
El operador de una pequeña red local necesita gestionar desde UN teléfono Android, SIN internet, los datos de sus clientes, los equipos/MAC asociados, la cuota mensual individual y el seguimiento del cobro. Solo una persona opera la app. Los datos residen en SQLite; los respaldos se guardan en documentos seleccionados por el usuario y pueden compartirse o transferirse.

## 2. Flujos incluidos

### Clientes y equipos
- Registrar, listar, buscar, filtrar, editar y archivar clientes.
- Campos: nombre (obligatorio), teléfono (opcional pero necesario para WhatsApp), dirección, tarifa mensual individual (obligatoria, >=0), notas, estado de servicio (activo/suspendido/archivado), fechas de creación/edición.
- Un cliente puede tener cero o más dispositivos: tipo (antena/ONT/router/otro), MAC (opcional pero validada si está presente), dirección IP (opcional, independiente de la MAC), comentario. Permitir al menos dos MAC sin fijar límite; normalizar a mayúsculas con separador `:` y advertir si coincide con otro dispositivo.
- La IP se registra manualmente para cada dispositivo, no para el cliente. Aceptar IPv4 e IPv6 numéricas, recortar espacios y normalizar su representación; campo vacío equivale a NULL y permite borrar una IP anterior. Rechazar hostnames, puertos, CIDR, identificadores de zona y corchetes. Se permiten IP repetidas. Mostrar solo las IP existentes y permitir seleccionarlas/copiar mediante el menú del sistema. No realizar DNS, escaneo, ping ni conexiones al equipo.
- Archivo lógico para conservar historial. Si se solicita borrar definitivamente, permitirlo solo para clientes sin historial financiero y tras doble confirmación; los que tengan pagos/cargos se archivan, evitando pérdida accidental de contabilidad.

### Mensualidades y pagos
- Todos los clientes usan la fecha estándar de cierre/inicio de cobro: día 30 de cada mes. Cada cliente tiene su propia cuota.
- **Convención MVP:** el cobro del mes `YYYY-MM` se abre el día 30 del mes PREVIO. Ej.: período `2026-12` se abre y vence el 2026-11-30; un impago de diciembre es candidato a suspensión el 2026-12-03.
- Si el mes previo tiene menos de 30 días, el corte ocurre el último día de ese mes; el momento de posible suspensión continúa siendo el día 3 del mes facturado.
- Al abrir la app, conciliar cargos faltantes de cada período aplicable sin duplicarlos. Los clientes activos dados de alta antes del corte generan cargo para ese período; si se registran dentro de un período ya abierto, se genera su primer cargo del período vigente una sola vez. No generar cargos retroactivos para períodos anteriores a la fecha de alta.
- Al archivar un cliente, no generar cargos nuevos. Los cargos ya emitidos y deudas históricas permanecen. La reactivación surte efecto desde el período vigente, sin reconstruir cargos antiguos indiscriminadamente.
- Guardar en el cargo la cuota individual vigente al generar el período (`amountMinor`); cambiar la tarifa solo afecta cargos generados posteriormente. Se permite corregir un cargo vigente aún no pagado mediante una acción explícita de edición y confirmación (no automática).
- Solo pagos COMPLETOS en el MVP; un cargo puede tener como máximo un pago vigente. Guardar fecha/hora del pago, importe exacto y nota opcional.
- Permitir anular un pago registrado por error conservando un rastro (`voidedAt`) y devolviendo el cargo a pendiente.
- No permitir crear cargos repetidos para un mismo `(clientId, periodKey)`.
- Estados de cobro derivados: `paid` si existe pago vigente; `pending` si no se pagó y aún no llega el día 3 del período; `suspension_candidate` si impagado y `fecha local >= día 3 del período`.
- Si existen deudas vencidas anteriores, un cliente sigue siendo candidato hasta pagar los cargos anteriores. Esto NO cambia automáticamente el estado real del servicio ni gestiona router alguno.
- Cambios de fecha del dispositivo: recalcular al abrir/vuelve al primer plano; los datos de pagos y períodos permanecen persistidos. Usar hora local del equipo.

### Inicio y cobros
- Dashboard con total de clientes activos, pagados y pendientes del período vigente, número de candidatos a suspensión, recaudación del período.
- Lista de clientes/cargos con pestañas o filtros `Todos`, `Pendientes`, `Pagados`, `Posible suspensión`; buscador y acción `Registrar pago`.
- Ficha de cliente con datos de equipos, mensualidad vigente, historial y botón WhatsApp.
- Una vista sencilla para consultar períodos anteriores.

### WhatsApp y compartir
- En ficha o detalle de cargo, botón **Recordar por WhatsApp**: valida el teléfono, compone mensaje con nombre, período, importe y estado, y abre el chat con texto prellenado. El administrador debe revisar/pulsar Enviar. No usar WhatsApp Business API ni envío automático.
- En Cobros, botón **Compartir reporte**: generar un texto legible del período/filtro con resumen, nombres, montos y estados; compartir por el diálogo nativo Android (puede elegir WhatsApp). No incluir por defecto direcciones, números telefónicos o MAC en ese texto.
- Las operaciones anteriores requieren una app compatible y conexión para el envío real; si no está instalada, ofrecer copiar texto o diálogo general, sin bloquear la gestión offline.

### Notificaciones
- Recordatorios locales optativos el día 2 para revisar cobros pendientes y el día 3 para revisar posibles suspensiones; 09:00 hora local aproximada, con posibles retrasos según Android/batería/permisos.
- En la app mostrar candidatos desde el día 3. Al abrir, recomputar siempre el estado real; una notificación no marca deudores ni modifica BD.
- Ajuste para activar/desactivar avisos. Permisos gestionados de manera respetuosa.

### Ajustes y respaldo
- Ajustar nombre del negocio, etiqueta de moneda, código telefónico por defecto (opcional), activar/desactivar avisos.
- Exportar **copia completa** seleccionando carpeta/archivo con el diálogo del sistema Android. Formato versionado, por ejemplo `.mired-backup.json`, con clientes, dispositivos, cargos, pagos y ajustes, metadatos y suma SHA-256 del contenido serializado de manera determinista.
- En T07, cada dispositivo exportado/restaurado debe incluir su IP opcional, además de la MAC. El respaldo todavía no está implementado; su versión es independiente de SQLite v1/v2 y deberá definir la compatibilidad con archivos sin IP.
- Restaurar desde archivo: comprobar versión, integridad, relaciones, unicidad y valores; mostrar vista previa del conteo de registros y aviso de reemplazo; generar una copia local de seguridad previa y restaurar en transacción, con rollback ante error.
- Una copia dentro del espacio privado de la app NO cuenta como backup recuperable después de desinstalarla; el usuario debe poder guardar en Documentos/Descargas/otra ubicación accesible.
- Recordar visualmente cuándo se realizó el último respaldo. Los archivos exportados pueden contener datos personales en texto claro: mostrar advertencia de privacidad al compartirlos.

## 3. Exclusiones explícitas
- Login/cuentas, panel web, nube, API, sincronización, multiusuario.
- Control/suspensión real de router/MikroTik, acceso a red, cortes automáticos.
- Pagos parciales, créditos, intereses, descuentos, facturas fiscales, pagos en línea.
- Envío automático, masivo o silencioso de WhatsApp, lectura de confirmaciones.
- Múltiples monedas o conversiones, exportación PDF, estadísticas avanzadas.
- Publicación en Google Play, servidores, analítica o suscripciones.

## 4. Decisiones UX
- Español, Material 3, interfaz clara, accesible y rápida; soporte oscuro si es fácil.
- Navegación inferior: Inicio, Clientes, Cobros, Ajustes.
- Acción de pago visible desde Inicio, Cobros y ficha de cliente.
- Indicadores claros de deuda, pagado y candidato a suspensión, nunca solo color.
- Confirmar operaciones con pérdida de información; mostrar mensajes de éxito/error y estados vacíos.

## 5. Escenarios de aceptación
1. Crear dos clientes con tarifas diferentes; se crean cargos con importes diferentes.
2. Generar un período dos veces no duplica cargos.
3. Cargar diciembre 2026 el 30-nov; el 2-dic continúa pendiente; el 3-dic se convierte en candidato si no paga.
4. Al pagar el 3-dic deja de ser candidato para ese cargo; se conserva fecha, importe e historial.
5. Un cargo de período antiguo impagado mantiene la advertencia de deuda del cliente, aunque haya pagado el período vigente.
6. Modificar tarifa no altera importes históricos.
7. Dar de baja/archivar impide crear nuevos cargos, pero mantiene deuda/historial.
8. Febrero no provoca fallo, con 28 o 29 días según año.
9. WhatsApp abre texto preparado, sin enviar automáticamente; el reporte se comparte mediante selector Android.
10. Guardar backup externamente, borrar datos en un entorno de prueba e importar; deben recuperarse datos y pagos. Archivo dañado o incompatible se rechaza sin tocar datos actuales.
11. La app mantiene funcionalidades básicas en modo avión y después de reiniciar el teléfono.

## 6. Entrega
APK release firmado, instrucciones de instalación y de habilitar instalación de origen desconocido cuando sea necesario, código fuente y guía rápida para backups/restauración. Custodiar keystore y mantener package ID para futuras actualizaciones.
