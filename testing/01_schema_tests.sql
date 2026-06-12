\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name IN ('usuario', 'subasta', 'oferta');
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'Se esperaban 3 tablas, hay %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'subasta'
      AND column_name IN (
          'id', 'descripcion', 'categoria', 'email_vendedor', 'fecha_inicio',
          'fecha_cierre', 'precio_base', 'incremento_min', 'email_ganador', 'monto_ganador'
      );
    IF v_count <> 10 THEN
        RAISE EXCEPTION 'Columnas de subasta incompletas: %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'oferta'
      AND column_name IN ('id_subasta', 'nro_oferta', 'email_usuario', 'fecha_hora', 'monto');
    IF v_count <> 5 THEN
        RAISE EXCEPTION 'Columnas de oferta incompletas: %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name IN ('usuario', 'subasta', 'oferta')
      AND constraint_type = 'PRIMARY KEY';
    IF v_count <> 3 THEN
        RAISE EXCEPTION 'PKs esperadas: 3, encontradas: %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name IN ('subasta', 'oferta')
      AND constraint_type = 'FOREIGN KEY';
    IF v_count <> 4 THEN
        RAISE EXCEPTION 'FKs esperadas: 4, encontradas: %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM information_schema.table_constraints
    WHERE table_schema = 'public'
      AND table_name IN ('subasta', 'oferta')
      AND constraint_type = 'CHECK';
    IF v_count < 6 THEN
        RAISE EXCEPTION 'Checks esperados al menos 6, encontrados: %', v_count;
    END IF;
END;
$$;

ROLLBACK;
