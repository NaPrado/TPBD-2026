\set ON_ERROR_STOP on
BEGIN;

DO $$
DECLARE
    v_email text;
    v_monto numeric(12, 2);
BEGIN
    BEGIN
        PERFORM cerrar_subasta(999999);
        RAISE EXCEPTION 'Debio rechazar subasta inexistente';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar subasta inexistente' THEN RAISE; END IF;
    END;

    BEGIN
        PERFORM cerrar_subasta(100);
        RAISE EXCEPTION 'Debio rechazar subasta activa';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar subasta activa' THEN RAISE; END IF;
    END;

    PERFORM cerrar_subasta(150);

    SELECT email_ganador, monto_ganador
    INTO v_email, v_monto
    FROM subasta
    WHERE id = 150;

    IF v_email <> 'victoria.reyes@mail.com' OR v_monto <> 285000.00 THEN
        RAISE EXCEPTION 'Ganador subasta 150 incorrecto: %, %', v_email, v_monto;
    END IF;

    BEGIN
        PERFORM cerrar_subasta(150);
        RAISE EXCEPTION 'Debio rechazar doble cierre con ganador';
    EXCEPTION WHEN raise_exception THEN
        IF SQLERRM = 'Debio rechazar doble cierre con ganador' THEN RAISE; END IF;
    END;

    PERFORM cerrar_subasta(200);
    PERFORM cerrar_subasta(200);

    SELECT email_ganador, monto_ganador
    INTO v_email, v_monto
    FROM subasta
    WHERE id = 200;

    IF v_email IS NOT NULL OR v_monto IS NOT NULL THEN
        RAISE EXCEPTION 'Subasta 200 no debia asignar ganador: %, %', v_email, v_monto;
    END IF;
END;
$$;

ROLLBACK;
