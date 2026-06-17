-- Listar todos los triggers del schema
SELECT trigger_name, event_manipulation, event_object_table, action_statement
FROM information_schema.triggers
WHERE trigger_schema = 'public';

-- Listar triggers de una tabla específica (psql)
-- \d transaction

-- Editar el cuerpo del trigger (se reemplaza la función)
CREATE OR REPLACE FUNCTION trg_actualizar_balance()
RETURNS TRIGGER AS $$
BEGIN
    -- nuevo cuerpo
END;
$$ LANGUAGE plpgsql;

-- Renombrar un trigger
ALTER TRIGGER trg_transaccion_balance ON transaction RENAME TO nuevo_nombre;

-- Eliminar solo el trigger
DROP TRIGGER IF EXISTS trg_transaccion_balance ON transaction;

-- Eliminar trigger y su función
DROP TRIGGER IF EXISTS trg_transaccion_balance ON transaction;
DROP FUNCTION IF EXISTS trg_actualizar_balance();
