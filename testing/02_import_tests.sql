\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_count integer;
BEGIN
    SELECT COUNT(*) INTO v_count FROM subasta;
    IF v_count <> 31 THEN
        RAISE EXCEPTION 'subasta: esperado 31, obtenido %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM oferta;
    IF v_count <> 139 THEN
        RAISE EXCEPTION 'oferta: esperado 139, obtenido %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count FROM usuario;
    IF v_count <> 25 THEN
        RAISE EXCEPTION 'usuario: esperado 25, obtenido %', v_count;
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM (
        SELECT id_subasta
        FROM oferta
        GROUP BY id_subasta
        HAVING MIN(nro_oferta) <> 1
           OR MAX(nro_oferta) <> COUNT(*)
           OR COUNT(*) <> COUNT(DISTINCT nro_oferta)
    ) t;
    IF v_count <> 0 THEN
        RAISE EXCEPTION 'Hay subastas con nro_oferta no correlativo o con huecos';
    END IF;
END;
$$;

ROLLBACK;
