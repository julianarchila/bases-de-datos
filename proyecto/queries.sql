-- ============================================================
-- FUNCIÓN: Estado detallado de un presupuesto en el mes actual
-- Retorna límite, lo gastado, lo disponible y el % usado.
-- ============================================================
CREATE OR REPLACE FUNCTION estado_presupuesto(p_id_budget INT)
RETURNS TABLE(
    categoria       VARCHAR,
    limite          DECIMAL(12,2),
    gastado         DECIMAL(12,2),
    disponible      DECIMAL(12,2),
    porcentaje_uso  DECIMAL(5,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        c.name::VARCHAR,
        b.limit_amount,
        COALESCE(SUM(t.amount), 0)::DECIMAL(12,2)                                  AS gastado,
        (b.limit_amount - COALESCE(SUM(t.amount), 0))::DECIMAL(12,2)               AS disponible,
        ROUND(COALESCE(SUM(t.amount), 0) / b.limit_amount * 100, 2)::DECIMAL(5,2)  AS porcentaje_uso
    FROM budget b
    JOIN category c ON b.id_category = c.id_category
    LEFT JOIN account a      ON a.id_user = b.id_user
    LEFT JOIN transaction t  ON t.id_account = a.id_account
                             AND t.type = 'expense'
                             AND DATE_TRUNC('month', t.date) = DATE_TRUNC('month', CURRENT_DATE)
    LEFT JOIN transaction_category tc ON tc.id_transaction = t.id_transaction
                                      AND tc.id_category   = b.id_category
    WHERE b.id_budget = p_id_budget
    GROUP BY c.name, b.limit_amount;
END;
$$ LANGUAGE plpgsql;

-- Uso: SELECT * FROM estado_presupuesto(1);


-- ============================================================
-- VIEW: Resumen mensual de ingresos y gastos por usuario
-- ============================================================
CREATE OR REPLACE VIEW resumen_mensual AS
SELECT
    u.id_user,
    u.name                              AS usuario,
    TO_CHAR(t.date, 'YYYY-MM')         AS mes,
    SUM(CASE WHEN t.type = 'income'  THEN t.amount ELSE 0 END)  AS total_ingresos,
    SUM(CASE WHEN t.type = 'expense' THEN t.amount ELSE 0 END)  AS total_gastos,
    SUM(CASE WHEN t.type = 'income'  THEN t.amount
             WHEN t.type = 'expense' THEN -t.amount
             ELSE 0 END)                                         AS balance_neto
FROM "user" u
JOIN account     a  ON a.id_user       = u.id_user
JOIN transaction t  ON t.id_account    = a.id_account
GROUP BY u.id_user, u.name, TO_CHAR(t.date, 'YYYY-MM')
ORDER BY u.id_user, mes DESC;

-- Uso: SELECT * FROM resumen_mensual WHERE id_user = 1;


-- ============================================================
-- CONSULTA 1: Historial de transacciones de un usuario con categorías
-- ============================================================
SELECT
    t.id_transaction,
    t.date,
    t.type,
    t.amount,
    t.description,
    a.name                              AS cuenta,
    STRING_AGG(c.name, ', ')           AS categorias
FROM transaction t
JOIN account a             ON t.id_account     = a.id_account
LEFT JOIN transaction_category tc ON tc.id_transaction = t.id_transaction
LEFT JOIN category c       ON tc.id_category   = c.id_category
WHERE a.id_user = 1                    -- <- cambiar por el id del usuario
GROUP BY t.id_transaction, t.date, t.type, t.amount, t.description, a.name
ORDER BY t.date DESC;


-- ============================================================
-- CONSULTA 2: Top 5 categorías con mayor gasto del mes actual
-- ============================================================
SELECT
    c.name                              AS categoria,
    COUNT(t.id_transaction)            AS num_transacciones,
    SUM(t.amount)                      AS total_gastado
FROM transaction t
JOIN account a              ON t.id_account     = a.id_account
JOIN transaction_category tc ON tc.id_transaction = t.id_transaction
JOIN category c             ON tc.id_category   = c.id_category
WHERE a.id_user = 1                    -- <- cambiar por el id del usuario
  AND t.type = 'expense'
  AND DATE_TRUNC('month', t.date) = DATE_TRUNC('month', CURRENT_DATE)
GROUP BY c.name
ORDER BY total_gastado DESC
LIMIT 5;


-- ============================================================
-- CONSULTA 3: Alertas activas con detalle del presupuesto
-- ============================================================
SELECT
    al.id_alert,
    al.message,
    al.description                      AS detalle_alerta,
    c.name                              AS categoria,
    b.limit_amount                      AS limite,
    b.alert_threshold                  AS umbral_pct,
    u.name                              AS usuario
FROM alert al
JOIN budget b   ON al.id_budget    = b.id_budget
JOIN category c ON b.id_category   = c.id_category
JOIN "user" u   ON b.id_user       = u.id_user
ORDER BY al.id_alert DESC;


-- ============================================================
-- TRIGGER: Al insertar una transacción
--   1. Actualiza el balance de la cuenta automáticamente.
--   2. Si supera el umbral de algún presupuesto, crea una alerta.
-- ============================================================
CREATE OR REPLACE FUNCTION trg_procesar_transaccion()
RETURNS TRIGGER AS $$
DECLARE
    v_id_user        INT;
    v_id_category    INT;
    v_gastado        DECIMAL(12,2);
    v_budget         RECORD;
BEGIN
    -- 1. Actualizar balance de la cuenta
    IF NEW.type = 'income' THEN
        UPDATE account SET balance = balance + NEW.amount WHERE id_account = NEW.id_account;
    ELSIF NEW.type = 'expense' THEN
        UPDATE account SET balance = balance - NEW.amount WHERE id_account = NEW.id_account;
    END IF;

    -- 2. Obtener el usuario dueño de la cuenta
    SELECT id_user INTO v_id_user
    FROM account
    WHERE id_account = NEW.id_account;

    -- Solo verificar presupuestos para gastos
    IF NEW.type = 'expense' THEN
        FOR v_budget IN
            SELECT b.id_budget, b.limit_amount, b.alert_threshold, b.id_category
            FROM budget b
            WHERE b.id_user = v_id_user
        LOOP
            -- Total gastado en esa categoría este mes
            SELECT COALESCE(SUM(t.amount), 0) INTO v_gastado
            FROM transaction t
            JOIN account a             ON t.id_account    = a.id_account
            JOIN transaction_category tc ON tc.id_transaction = t.id_transaction
            WHERE a.id_user          = v_id_user
              AND tc.id_category     = v_budget.id_category
              AND t.type             = 'expense'
              AND DATE_TRUNC('month', t.date) = DATE_TRUNC('month', NEW.date);

            -- Crear alerta si se superó el umbral y no existe ya una para este mes
            IF v_gastado >= (v_budget.limit_amount * v_budget.alert_threshold / 100)
               AND NOT EXISTS (
                   SELECT 1 FROM alert al
                   WHERE al.id_budget = v_budget.id_budget
                     AND DATE_TRUNC('month', NEW.date) = DATE_TRUNC('month', CURRENT_DATE)
               )
            THEN
                INSERT INTO alert (message, description, id_budget)
                VALUES (
                    'Umbral de presupuesto superado',
                    FORMAT(
                        'Has gastado $%s de $%s (%.0f%%) en el presupuesto #%s.',
                        v_gastado, v_budget.limit_amount,
                        v_gastado / v_budget.limit_amount * 100,
                        v_budget.id_budget
                    ),
                    v_budget.id_budget
                );
            END IF;
        END LOOP;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transaccion_insert
AFTER INSERT ON transaction
FOR EACH ROW
EXECUTE FUNCTION trg_procesar_transaccion();
