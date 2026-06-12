\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_before integer;
    v_after integer;
BEGIN
    SELECT COUNT(*) INTO v_before FROM usuario WHERE email = 'nuevo.vendedor@mail.com';

    INSERT INTO subasta(id, descripcion, categoria, email_vendedor, fecha_inicio, fecha_cierre, precio_base, incremento_min)
    VALUES (900, 'Objeto de prueba', 'Pruebas', 'nuevo.vendedor@mail.com',
            '2026-06-01 10:00:00', '2026-07-01 10:00:00', 100.00, 10.00);

    SELECT COUNT(*) INTO v_after FROM usuario WHERE email = 'nuevo.vendedor@mail.com';
    IF v_before <> 0 OR v_after <> 1 THEN
        RAISE EXCEPTION 'El trigger de subasta no autopueblo usuario correctamente';
    END IF;

    INSERT INTO subasta(id, descripcion, categoria, email_vendedor, fecha_inicio, fecha_cierre, precio_base, incremento_min)
    VALUES (901, 'Otro objeto de prueba', 'Pruebas', 'nuevo.vendedor@mail.com',
            '2026-06-01 10:00:00', '2026-07-01 10:00:00', 100.00, 10.00);

    SELECT COUNT(*) INTO v_after FROM usuario WHERE email = 'nuevo.vendedor@mail.com';
    IF v_after <> 1 THEN
        RAISE EXCEPTION 'El trigger de subasta duplico un usuario existente';
    END IF;
END;
$$;

ROLLBACK;
