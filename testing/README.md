# Testing

Ejecutar:

```bash
bash testing/run_tests.sh
```

Requisitos:

- Docker con soporte para `docker compose`.
- Cliente `psql` instalado en la maquina host.
- Archivo `.env.local` con `POSTGRES_DB`, `POSTGRES_USER` y `POSTGRES_PASSWORD`.

El runner levanta el servicio `db`, recrea el esquema ejecutando `funciones.sql`, importa `subasta.csv` y `oferta.csv` con `\copy`, y ejecuta los archivos `testing/[0-9][0-9]_*.sql` cortando ante el primer error.

Cobertura:

- `01_schema_tests.sql`: tablas, columnas, claves primarias, claves foraneas y checks principales.
- `02_import_tests.sql`: cantidades importadas, usuarios autopoblados y numeracion correlativa de ofertas.
- `03_trigger_subasta_tests.sql`: autopoblado de vendedores nuevos y no duplicacion de existentes.
- `04_trigger_oferta_accept_tests.sql`: insercion de ofertas validas, numeracion automatica y usuarios oferentes.
- `05_trigger_oferta_reject_tests.sql`: rechazos por subasta inexistente, fecha fuera de rango, vendedor pujando, ofertas consecutivas, primera oferta bajo base y monto posterior insuficiente.
- `06_cerrar_subasta_tests.sql`: subasta inexistente, activa, cierre con ganador, doble cierre y cierre sin ofertas idempotente.
- `07_reporte_subastas_tests.sql`: cierre de vencidas, subtotales esperados, total general e invocaciones del reporte con y sin filtro.
