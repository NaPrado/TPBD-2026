DROP TABLE IF EXISTS oferta CASCADE;
DROP TABLE IF EXISTS subasta CASCADE;
DROP TABLE IF EXISTS usuario CASCADE;

CREATE TABLE usuario (
    email text PRIMARY KEY
);

CREATE TABLE subasta (
    id integer PRIMARY KEY,
    descripcion text NOT NULL,
    categoria text NOT NULL,
    email_vendedor text NOT NULL REFERENCES usuario(email),
    fecha_inicio timestamp NOT NULL,
    fecha_cierre timestamp NOT NULL,
    precio_base numeric(12, 2) NOT NULL,
    incremento_min numeric(12, 2) NOT NULL,
    email_ganador text NULL REFERENCES usuario(email),
    monto_ganador numeric(12, 2) NULL,
    CONSTRAINT subasta_fechas_validas CHECK (fecha_cierre >= fecha_inicio),
    CONSTRAINT subasta_precio_base_positivo CHECK (precio_base > 0),
    CONSTRAINT subasta_incremento_min_positivo CHECK (incremento_min > 0),
    CONSTRAINT subasta_monto_ganador_positivo CHECK (monto_ganador IS NULL OR monto_ganador > 0),
    CONSTRAINT subasta_ganador_completo CHECK (
        (email_ganador IS NULL AND monto_ganador IS NULL)
        OR (email_ganador IS NOT NULL AND monto_ganador IS NOT NULL)
    )
);

CREATE TABLE oferta (
    id_subasta integer NOT NULL REFERENCES subasta(id),
    nro_oferta integer NOT NULL,
    email_usuario text NOT NULL REFERENCES usuario(email),
    fecha_hora timestamp NOT NULL,
    monto numeric(12, 2) NOT NULL,
    PRIMARY KEY (id_subasta, nro_oferta),
    CONSTRAINT oferta_nro_oferta_positivo CHECK (nro_oferta > 0),
    CONSTRAINT oferta_monto_positivo CHECK (monto > 0)
);

CREATE OR REPLACE FUNCTION trg_subasta_autopoblar_usuario()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO usuario(email)
    VALUES (NEW.email_vendedor)
    ON CONFLICT (email) DO NOTHING;

    RETURN NEW;
END;
$$;

CREATE TRIGGER subasta_autopoblar_usuario
BEFORE INSERT ON subasta
FOR EACH ROW
EXECUTE FUNCTION trg_subasta_autopoblar_usuario();

CREATE OR REPLACE FUNCTION trg_oferta_validar_insertar()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_subasta subasta%ROWTYPE;
    v_ultima oferta%ROWTYPE;
    v_max_monto numeric(12, 2);
    v_siguiente_nro integer;
    v_monto_minimo numeric(12, 2);
BEGIN
    SELECT *
    INTO v_subasta
    FROM subasta
    WHERE id = NEW.id_subasta
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la subasta %', NEW.id_subasta;
    END IF;

    INSERT INTO usuario(email)
    VALUES (NEW.email_usuario)
    ON CONFLICT (email) DO NOTHING;

    IF NEW.fecha_hora < v_subasta.fecha_inicio OR NEW.fecha_hora > v_subasta.fecha_cierre THEN
        RAISE EXCEPTION 'La oferta para la subasta % esta fuera del periodo activo [% - %]',
            NEW.id_subasta, v_subasta.fecha_inicio, v_subasta.fecha_cierre;
    END IF;

    IF NEW.email_usuario = v_subasta.email_vendedor THEN
        RAISE EXCEPTION 'El vendedor % no puede ofertar en su propia subasta %',
            NEW.email_usuario, NEW.id_subasta;
    END IF;

    SELECT *
    INTO v_ultima
    FROM oferta
    WHERE id_subasta = NEW.id_subasta
    ORDER BY nro_oferta DESC
    LIMIT 1;

    IF FOUND AND v_ultima.email_usuario = NEW.email_usuario THEN
        RAISE EXCEPTION 'El usuario % no puede realizar dos ofertas consecutivas en la subasta %',
            NEW.email_usuario, NEW.id_subasta;
    END IF;

    SELECT MAX(monto), COALESCE(MAX(nro_oferta), 0) + 1
    INTO v_max_monto, v_siguiente_nro
    FROM oferta
    WHERE id_subasta = NEW.id_subasta;

    IF v_max_monto IS NULL THEN
        v_monto_minimo := v_subasta.precio_base;
        IF NEW.monto < v_monto_minimo THEN
            RAISE EXCEPTION 'La primera oferta de la subasta % debe ser al menos %',
                NEW.id_subasta, v_monto_minimo;
        END IF;
    ELSE
        v_monto_minimo := v_max_monto + v_subasta.incremento_min;
        IF NEW.monto < v_monto_minimo THEN
            RAISE EXCEPTION 'La oferta para la subasta % debe ser al menos %',
                NEW.id_subasta, v_monto_minimo;
        END IF;
    END IF;

    NEW.nro_oferta := v_siguiente_nro;
    RETURN NEW;
END;
$$;

CREATE TRIGGER oferta_validar_insertar
BEFORE INSERT ON oferta
FOR EACH ROW
EXECUTE FUNCTION trg_oferta_validar_insertar();

CREATE OR REPLACE FUNCTION cerrar_subasta(p_id integer)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_subasta subasta%ROWTYPE;
    v_ganadora oferta%ROWTYPE;
BEGIN
    SELECT *
    INTO v_subasta
    FROM subasta
    WHERE id = p_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'No existe la subasta %', p_id;
    END IF;

    IF v_subasta.fecha_cierre > CURRENT_TIMESTAMP THEN
        RAISE EXCEPTION 'La subasta % todavia esta activa. Fecha de cierre: %',
            p_id, v_subasta.fecha_cierre;
    END IF;

    IF v_subasta.email_ganador IS NOT NULL THEN
        RAISE EXCEPTION 'La subasta % ya fue cerrada con ganador %',
            p_id, v_subasta.email_ganador;
    END IF;

    SELECT *
    INTO v_ganadora
    FROM oferta
    WHERE id_subasta = p_id
    ORDER BY monto DESC, nro_oferta DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    UPDATE subasta
    SET email_ganador = v_ganadora.email_usuario,
        monto_ganador = v_ganadora.monto
    WHERE id = p_id;
END;
$$;

CREATE OR REPLACE FUNCTION reporte_subastas(p_desde date, p_categoria text DEFAULT NULL)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_cur refcursor;
    v_row record;
    v_hay_resultados boolean := false;
    v_categoria_actual text := NULL;
    v_subtotal_subastas integer := 0;
    v_subtotal_ganadores integer := 0;
    v_subtotal_recaudado numeric(14, 2) := 0;
    v_total_subastas integer := 0;
    v_total_ganadores integer := 0;
    v_total_recaudado numeric(14, 2) := 0;
BEGIN
    OPEN v_cur FOR
        SELECT s.id,
               s.descripcion,
               s.categoria,
               s.precio_base,
               s.email_ganador,
               s.monto_ganador,
               COUNT(o.nro_oferta)::integer AS cantidad_ofertas
        FROM subasta s
        LEFT JOIN oferta o ON o.id_subasta = s.id
        WHERE s.fecha_cierre::date >= p_desde
          AND (p_categoria IS NULL OR s.categoria = p_categoria)
        GROUP BY s.id, s.descripcion, s.categoria, s.precio_base, s.email_ganador, s.monto_ganador
        ORDER BY s.categoria ASC, s.id ASC;

    LOOP
        FETCH v_cur INTO v_row;
        EXIT WHEN NOT FOUND;

        IF NOT v_hay_resultados THEN
            v_hay_resultados := true;
            RAISE NOTICE '====== REPORTE DE SUBASTAS ======';
            IF p_categoria IS NULL THEN
                RAISE NOTICE 'Desde: %', p_desde;
            ELSE
                RAISE NOTICE 'Categoria: %', p_categoria;
                RAISE NOTICE 'Desde: %', p_desde;
            END IF;
        END IF;

        IF v_categoria_actual IS DISTINCT FROM v_row.categoria THEN
            IF v_categoria_actual IS NOT NULL THEN
                RAISE NOTICE '-- subtotal %: % subastas, % con ganador, $ % recaudado',
                    v_categoria_actual, v_subtotal_subastas, v_subtotal_ganadores,
                    to_char(v_subtotal_recaudado, 'FM999999999990.00');
            END IF;

            v_categoria_actual := v_row.categoria;
            v_subtotal_subastas := 0;
            v_subtotal_ganadores := 0;
            v_subtotal_recaudado := 0;
            RAISE NOTICE '== Categoria: % ==', v_categoria_actual;
        END IF;

        IF v_row.email_ganador IS NULL THEN
            RAISE NOTICE '[#%] % - base $ % -> sin ganador asignado (% ofertas)',
                v_row.id, v_row.descripcion, to_char(v_row.precio_base, 'FM999999999990.00'),
                v_row.cantidad_ofertas;
        ELSE
            RAISE NOTICE '[#%] % - base $ % -> ganador % por $ % (% ofertas)',
                v_row.id, v_row.descripcion, to_char(v_row.precio_base, 'FM999999999990.00'),
                v_row.email_ganador, to_char(v_row.monto_ganador, 'FM999999999990.00'),
                v_row.cantidad_ofertas;
        END IF;

        v_subtotal_subastas := v_subtotal_subastas + 1;
        v_total_subastas := v_total_subastas + 1;

        IF v_row.email_ganador IS NOT NULL THEN
            v_subtotal_ganadores := v_subtotal_ganadores + 1;
            v_total_ganadores := v_total_ganadores + 1;
            v_subtotal_recaudado := v_subtotal_recaudado + v_row.monto_ganador;
            v_total_recaudado := v_total_recaudado + v_row.monto_ganador;
        END IF;
    END LOOP;

    CLOSE v_cur;

    IF NOT v_hay_resultados THEN
        RETURN;
    END IF;

    RAISE NOTICE '-- subtotal %: % subastas, % con ganador, $ % recaudado',
        v_categoria_actual, v_subtotal_subastas, v_subtotal_ganadores,
        to_char(v_subtotal_recaudado, 'FM999999999990.00');

    RAISE NOTICE '======== TOTAL: % subastas, % con ganador, $ % recaudado ========',
        v_total_subastas, v_total_ganadores, to_char(v_total_recaudado, 'FM999999999990.00');
END;
$$;
