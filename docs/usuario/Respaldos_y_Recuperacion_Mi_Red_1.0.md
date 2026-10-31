# Mi Red — Respaldo y recuperación

**Instrucciones para conservar tus clientes, equipos, cobros y pagos.**

> **Lee esto antes de reinstalar o cambiar de teléfono.** Mi Red no tiene cuenta en la nube ni puede recuperar una contraseña olvidada.

## Qué guarda una copia

Una copia cifrada incluye los datos de los clientes, sus equipos (MAC e IP), mensualidades, pagos válidos y anulados, y la configuración del negocio y recordatorios. **No recupera permisos Android ni el tema de apariencia propio del teléfono receptor**.

El archivo termina en **`.miredbk`**, se protege con contraseña y solo se puede leer desde el flujo de restauración de Mi Red con esa contraseña.

## A. Crear la copia

1. Abre **Ajustes → Copias de seguridad → Crear copia**.
2. Introduce una contraseña nueva de **al menos 12 caracteres** y confírmala.
3. Pulsa **Cifrar y elegir destino**.
4. En el selector de Android, elige **Descargas, Documentos** u otro destino al que puedas acceder.
5. Pulsa Guardar y espera a que Mi Red confirme el guardado.
6. Comprueba el nombre del archivo `.miredbk` y **cópialo también fuera del teléfono** (por ejemplo, un ordenador o unidad externa protegida).
7. Conserva la contraseña por separado, preferentemente en un gestor de contraseñas.

**Nunca** consideres suficiente una copia que solo exista dentro del teléfono que utilizas a diario.

## B. Restaurar una copia

1. Abre **Ajustes → Copias de seguridad → Restaurar copia**.
2. Selecciona el `.miredbk` original.
3. Escribe la contraseña y pulsa **Comprobar copia**.
4. Revisa la fecha, clientes, dispositivos, mensualidades y pagos del respaldo y compáralos con los datos actuales.
5. Si quieres reemplazar todo el contenido, marca **Entiendo que se reemplazarán mis datos actuales**.
6. Pulsa **Reemplazar datos** y espera la confirmación.
7. Vuelve a Inicio, abre Clientes y Cobros, y comprueba también los permisos de Recordatorios.

**La restauración sustituye la base actual completa; no combina ni agrega los clientes del archivo.**

## C. Si aparece un error

| Mensaje o situación | Qué hacer |
|---|---|
| Contraseña incorrecta / archivo dañado | Revisa contraseña, archivo y que no esté truncado. La base actual permanece sin cambios. |
| No aparece el archivo | Comprueba la carpeta o transfiérelo nuevamente al teléfono. |
| Se canceló el selector | Vuelve a Crear copia o Restaurar copia; no supongas que se guardó algo. |
| No hay espacio disponible | Libera espacio de forma segura y repite la operación. |
| Se restauraron los datos pero faltan avisos | Revisa **Ajustes → Recordatorios** y los permisos de Android. |
| La copia es antigua | Después de abrir Inicio pueden generarse los períodos faltantes; los pagos históricos no se reescriben. |

## D. Antes de actualizar, reinstalar o cambiar de teléfono

- Crea un **respaldo nuevo** y conserva su contraseña.
- Verifica que puedes acceder al archivo desde fuera de la aplicación.
- Al actualizar, instala el APK firmado por el mismo desarrollador **sobre** la versión anterior cuando Android lo permita.
- Si necesitas desinstalar o utilizar otro móvil, prepara primero el archivo y la contraseña: desinstalar puede eliminar la base local.
- En el teléfono nuevo, instala Mi Red, restaura y comprueba los registros antes de dar por terminado el traslado.

## E. Buenas prácticas

- Repite los respaldos después de jornadas con muchos pagos o cambios de clientes.
- Guarda al menos **dos copias en lugares distintos**.
- No envíes contraseñas junto con el archivo de respaldo.
- No compartas un respaldo real en capturas, repositorios públicos ni chats de prueba.
- No utilices la misma contraseña débil para todos los respaldos.

**Mi Red 1.0 · CoreX4Dev** · <https://corex4dev.com>
