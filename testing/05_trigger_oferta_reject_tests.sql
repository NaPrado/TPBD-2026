\set ON_ERROR_STOP on
BEGIN;

INSERT INTO subasta(id, descripcion, categoria, email_vendedor, fecha_inicio, fecha_cierre, precio_base, incremento_min)
VALUES (920, 'Subasta rechazos', 'Pruebas', 'vendedor.rechazos@mail.com',
        '2026-06-01 10:00:00', '2026-07-01 10:00:00', 100.00, 10.00);

DO $$
BEGIN
    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (999999, 'rechazo@mail.com', '2026-06-02 10:00:00', 100.00);
        RAISE EXCEPTION 'Debio rechazar subasta inexistente';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar subasta inexistente' THEN RAISE; END IF;
    END;

    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (920, 'rechazo@mail.com', '2026-07-02 10:00:00', 100.00);
        RAISE EXCEPTION 'Debio rechazar fecha fuera de rango';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar fecha fuera de rango' THEN RAISE; END IF;
    END;

    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (920, 'vendedor.rechazos@mail.com', '2026-06-02 10:00:00', 100.00);
        RAISE EXCEPTION 'Debio rechazar vendedor pujando';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar vendedor pujando' THEN RAISE; END IF;
    END;

    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (920, 'rechazo@mail.com', '2026-06-02 10:00:00', 90.00);
        RAISE EXCEPTION 'Debio rechazar primera oferta bajo base';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar primera oferta bajo base' THEN RAISE; END IF;
    END;

    INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
    VALUES (920, 'ofertante.a@mail.com', '2026-06-02 10:00:00', 100.00);

    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (920, 'ofertante.a@mail.com', '2026-06-02 11:00:00', 120.00);
        RAISE EXCEPTION 'Debio rechazar ofertas consecutivas del mismo usuario';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar ofertas consecutivas del mismo usuario' THEN RAISE; END IF;
    END;

    BEGIN
        INSERT INTO oferta(id_subasta, email_usuario, fecha_hora, monto)
        VALUES (920, 'ofertante.b@mail.com', '2026-06-02 11:00:00', 109.99);
        RAISE EXCEPTION 'Debio rechazar monto posterior insuficiente';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar monto posterior insuficiente' THEN RAISE; END IF;
    END;
END;
$$;

ROLLBACK;
