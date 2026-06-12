\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_subastas integer;
    v_ganadores integer;
    v_recaudado numeric(14, 2);
BEGIN
    PERFORM cerrar_subasta(id)
    FROM subasta
    WHERE fecha_cierre <= CURRENT_TIMESTAMP
    ORDER BY id;

    SELECT COUNT(*),
           COUNT(email_ganador),
           COALESCE(SUM(monto_ganador), 0)
    INTO v_subastas, v_ganadores, v_recaudado
    FROM subasta
    WHERE fecha_cierre::date >= '2026-01-01'
      AND categoria = 'Electrónica';

    IF v_subastas <> 7 OR v_ganadores <> 3 OR v_recaudado <> 1136000.00 THEN
        RAISE EXCEPTION 'Resumen Electronica incorrecto: subastas %, ganadores %, recaudado %',
            v_subastas, v_ganadores, v_recaudado;
    END IF;

    SELECT COUNT(*),
           COUNT(email_ganador),
           COALESCE(SUM(monto_ganador), 0)
    INTO v_subastas, v_ganadores, v_recaudado
    FROM subasta
    WHERE fecha_cierre::date >= '2026-01-01';

    IF v_subastas <> 31 OR v_ganadores <> 8 OR v_recaudado <> 2163000.00 THEN
        RAISE EXCEPTION 'Resumen general incorrecto: subastas %, ganadores %, recaudado %',
            v_subastas, v_ganadores, v_recaudado;
    END IF;
END;
$$;

SELECT reporte_subastas('2026-01-01'::date, NULL);
SELECT reporte_subastas('2026-01-01'::date, 'Electrónica');
SELECT reporte_subastas('2030-01-01'::date, NULL);

ROLLBACK;
