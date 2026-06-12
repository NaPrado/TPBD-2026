\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_nro integer;
BEGIN
    INSERT INTO subasta(id, descripcion, categoria, email_vendedor, fecha_inicio, fecha_cierre, precio_base, incremento_min)
    VALUES (910, 'Subasta aceptacion', 'Pruebas', 'vendedor.aceptacion@mail.com',
            '2026-06-01 10:00:00', '2026-07-01 10:00:00', 100.00, 10.00);

    INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
    VALUES (910, 'ofertante.uno@mail.com', '2026-06-02 10:00:00', 100.00);

    SELECT nro_oferta INTO v_nro
    FROM oferta
    WHERE id_subasta = 910 AND email_usuario = 'ofertante.uno@mail.com';
    IF v_nro <> 1 THEN
        RAISE EXCEPTION 'Primera oferta esperaba nro 1, obtuvo %', v_nro;
    END IF;

    INSERT INTO oferta(id_subasta, nro_oferta, email_usuario, fecha_hora, monto)
    VALUES (910, 99, 'ofertante.dos@mail.com', '2026-06-02 11:00:00', 110.00);

    SELECT nro_oferta INTO v_nro
    FROM oferta
    WHERE id_subasta = 910 AND email_usuario = 'ofertante.dos@mail.com';
    IF v_nro <> 2 THEN
        RAISE EXCEPTION 'Segunda oferta esperaba nro 2 ignorando valor provisto, obtuvo %', v_nro;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM usuario WHERE email = 'ofertante.uno@mail.com')
       OR NOT EXISTS (SELECT 1 FROM usuario WHERE email = 'ofertante.dos@mail.com') THEN
        RAISE EXCEPTION 'El trigger de oferta no autopueblo usuarios oferentes';
    END IF;
END;
$$;

ROLLBACK;
