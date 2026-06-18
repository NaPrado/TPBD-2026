# Trabajo Práctico Especial — Base de Datos I

**Sistema de subastas online (PL/pgSQL sobre PostgreSQL)** · 1er cuatrimestre 2026

Entregables asociados: `funciones.sql` (esquema, triggers y funciones) y este informe.

---

## 1. Roles del grupo

Todos los integrantes participaron en el conjunto del trabajo; la siguiente tabla
asigna, para cada tarea, un responsable de supervisión.

| Rol (supervisión) | Integrante | Tareas principales |
|---|---|---|
| Encargado del informe | ⟨Nombre y Apellido⟩ | Redacción y revisión ortográfica de este documento. |
| Encargado de las funciones | ⟨Nombre y Apellido⟩ | `cerrar_subasta` y `reporte_subastas` (PSM, cursor explícito). |
| Encargado de los triggers | ⟨Nombre y Apellido⟩ | Triggers de autopoblado de `usuario` y de validación/numeración de ofertas. |
| Encargado del funcionamiento global | ⟨Nombre y Apellido⟩ | Diseño del esquema, integración y batería de pruebas. |
| Encargado de investigación | ⟨Nombre y Apellido⟩ | Relevamiento de PSM/triggers, concurrencia y comando de importación. |

> Nota para el grupo: completar los nombres. Si el grupo es de cuatro, un mismo
> integrante asume dos roles (por ejemplo, *informe* + *investigación*, o
> *funcionamiento global* + *triggers*).

---

## 2. Investigación realizada

- **Triggers `BEFORE INSERT ... FOR EACH ROW`.** Se eligió `BEFORE` (no `AFTER`)
  porque permite modificar la fila entrante a través de la variable `NEW` —imprescindible
  para asignar `nro_oferta`— y abortar la operación antes de escribir. La función de
  trigger devuelve `NEW`.
- **Control de concurrencia con `SELECT ... FOR UPDATE`.** Se investigó el bloqueo
  pesimista de fila para numerar ofertas y validar montos sin condiciones de carrera:
  dos inserciones simultáneas sobre la misma subasta quedan serializadas, evitando
  `nro_oferta` duplicados o validaciones sobre un estado desactualizado.
- **UPSERT con `INSERT ... ON CONFLICT (email) DO NOTHING`.** Forma idiomática de
  autopoblar `usuario` sin un `SELECT` previo y sin error si el email ya existe.
- **Tipos `%ROWTYPE` y `record`.** Para almacenar filas completas de `subasta` y
  `oferta` en variables locales dentro de las funciones.
- **Cursor explícito (`refcursor`, `OPEN`/`FETCH`/`CLOSE`).** Requerido por el
  enunciado; se comparó con el `FOR ... IN SELECT` implícito. El cursor permite llevar
  el estado de agrupación (categoría actual, subtotales) en una única pasada ordenada.
- **`RAISE NOTICE` frente a `RAISE EXCEPTION`.** `NOTICE` emite la salida del reporte
  sin abortar; `EXCEPTION` rechaza la operación y revierte la transacción (rechazos del
  trigger de ofertas y de `cerrar_subasta`).
- **Formato de importes con `to_char(monto, 'FM999999999990.00')`.** Imprime dos
  decimales fijos; la máscara `FM` elimina el relleno de espacios.
- **Casteo `::date`.** `fecha_cierre` es `timestamp` y `p_desde` es `date`; se castea
  para comparar correctamente en el filtro del reporte.
- **`\copy` frente a `COPY`.** `COPY` se ejecuta del lado del servidor (requiere que el
  servidor acceda al archivo); `\copy` es un meta-comando de `psql` que lee el archivo
  desde el cliente. Se utilizó `\copy` con `FORMAT csv, HEADER true`.

---

## 3. Dificultades encontradas y cómo se resolvieron

- **`nro_oferta` no viene en el CSV.** El archivo `oferta.csv` no incluye esa columna.
  Se resolvió calculándola en el trigger como `COALESCE(MAX(nro_oferta), 0) + 1` por
  subasta e importando con una lista de columnas que la omite. Como `\copy` procesa las
  filas en el orden del archivo, el correlativo respeta el orden del CSV.
- **Condiciones de carrera al numerar y validar montos.** Resueltas con el bloqueo
  `SELECT ... FOR UPDATE` sobre la subasta al inicio del trigger y de `cerrar_subasta`.
- **Orden de las acciones y atomicidad.** Se toma primero el lock de la subasta y se
  confirma su existencia; el autopoblado del oferente se realiza a continuación, de modo
  que una oferta dirigida a una subasta inexistente no crea un usuario. Dado que cualquier
  `RAISE EXCEPTION` revierte toda la transacción, ningún autopoblado queda huérfano.
- **Idempotencia de `cerrar_subasta`.** Hubo que distinguir una subasta vencida **sin
  ofertas** (no modifica nada, no falla y puede reinvocarse) de una **ya cerrada con
  ganador** (se rechaza). Se aprovecha el invariante de que `email_ganador` y
  `monto_ganador` son ambos nulos o ambos no nulos: `email_ganador IS NOT NULL` señala un
  cierre previo; si no hay ofertas, la función hace `RETURN` sin `UPDATE`.
- **Reporte que no imprime nada cuando no hay resultados.** Un indicador
  `v_hay_resultados` difiere la impresión del encabezado hasta el primer `FETCH` exitoso;
  si el cursor no devuelve filas, la función retorna en silencio (ni siquiera el encabezado).
- **Subtotales por categoría en una sola pasada.** Al detectar un cambio de categoría
  (`IS DISTINCT FROM`) se emite el subtotal de la categoría anterior y se reinician los
  acumuladores; el último subtotal se emite tras el bucle, antes del total general.
- **Genericidad.** Como la cátedra prueba con otros datasets, no se hardcodean ids,
  fechas ni montos: todo deriva de los parámetros y de las propias filas (`precio_base`,
  `incremento_min`, etc.).
- **CSV inmodificables.** Las columnas calculadas o diferidas (`nro_oferta`,
  `email_ganador`, `monto_ganador`) quedan fuera del `\copy`; se importan exactamente las
  columnas presentes en cada archivo.

---

## 4. Proceso de importación de los datos

1. **Recreación del esquema.** Se ejecuta `funciones.sql`, que recrea las tablas
   (`DROP ... CASCADE` en orden `oferta → subasta → usuario`), los triggers y las
   funciones. El script es idempotente: reejecutarlo resetea el estado.
2. **Orden de carga.** Primero `subasta.csv` y luego `oferta.csv`. La clave foránea
   `oferta.id_subasta → subasta.id` obliga a importar las subastas antes que las ofertas.
   La tabla `usuario` **no se importa**: se completa por triggers.
3. **Comando utilizado.** Se usa `\copy` de `psql` (lado cliente) con lista de columnas
   explícita y opciones `FORMAT csv, HEADER true`:

   ```sql
   \copy subasta(id, descripcion, categoria, email_vendedor,
                 fecha_inicio, fecha_cierre, precio_base, incremento_min)
         FROM 'subasta.csv' WITH (FORMAT csv, HEADER true)

   \copy oferta(id_subasta, email_usuario, fecha_hora, monto)
         FROM 'oferta.csv'  WITH (FORMAT csv, HEADER true)
   ```

   Se omiten `email_ganador` y `monto_ganador` (quedan en `NULL` hasta procesar el
   cierre) y `nro_oferta` (lo asigna el trigger).
4. **Efecto de los triggers durante la carga.** Cada fila de `subasta` autopobla
   `usuario` con su `email_vendedor`; cada fila de `oferta` autopobla el oferente, valida
   todas las reglas de negocio y numera la oferta. Los datos provistos están construidos
   para que ninguna fila sea rechazada durante la importación.
5. **Volumen importado.** 31 subastas y 139 ofertas, repartidas en 5 categorías (Arte,
   Coleccionables, Electrónica, Libros y Vehículos). Los usuarios quedan poblados
   íntegramente por los triggers.
6. **Verificación.** El script `testing/run_tests.sh` levanta la base en Docker, recrea
   el esquema, importa ambos CSV con `\copy` y ejecuta siete lotes de pruebas (esquema,
   importación, triggers de subasta y de oferta —aceptación y rechazo—, `cerrar_subasta`
   y `reporte_subastas`), deteniéndose ante el primer error.
