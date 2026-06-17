-- Retorna límite, gastado, disponible y % de uso de un presupuesto en el mes actual
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
    WITH gasto AS (
        SELECT COALESCE(SUM(t.amount), 0) AS total
        FROM budget b
        JOIN account a              ON a.id_user          = b.id_user
        JOIN transaction t          ON t.id_account       = a.id_account
                                   AND t.type             = 'expense'
                                   AND DATE_TRUNC('month', t.date) = DATE_TRUNC('month', CURRENT_DATE)
        JOIN transaction_category tc ON tc.id_transaction = t.id_transaction
                                    AND tc.id_category    = b.id_category
        WHERE b.id_budget = p_id_budget
    )
    SELECT
        c.name::VARCHAR,
        b.limit_amount,
        gasto.total::DECIMAL(12,2),
        (b.limit_amount - gasto.total)::DECIMAL(12,2),
        ROUND(gasto.total / b.limit_amount * 100, 2)::DECIMAL(5,2)
    FROM budget b
    JOIN category c ON b.id_category = c.id_category
    CROSS JOIN gasto
    WHERE b.id_budget = p_id_budget;
END;
$$ LANGUAGE plpgsql;


-- Ingresos, gastos y balance neto por usuario agrupados por mes
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


-- Historial de transacciones de un usuario con sus categorías
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


-- Top 5 categorías con mayor gasto del mes actual
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


-- Alertas activas con detalle del presupuesto asociado
SELECT
    al.id_alert,
    al.message,
    al.description                      AS detalle_alerta,
    c.name                              AS categoria,
    b.limit_amount                      AS limite,
    b.alert_threshold                   AS umbral_pct,
    u.name                              AS usuario
FROM alert al
JOIN budget b   ON al.id_budget    = b.id_budget
JOIN category c ON b.id_category   = c.id_category
JOIN "user" u   ON b.id_user       = u.id_user
ORDER BY al.id_alert DESC;


-- Actualiza el balance de la cuenta al insertar una transacción
CREATE OR REPLACE FUNCTION trg_actualizar_balance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.type = 'income' THEN
        UPDATE account SET balance = balance + NEW.amount WHERE id_account = NEW.id_account;
    ELSIF NEW.type = 'expense' THEN
        UPDATE account SET balance = balance - NEW.amount WHERE id_account = NEW.id_account;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_transaccion_balance
AFTER INSERT ON transaction
FOR EACH ROW
EXECUTE FUNCTION trg_actualizar_balance();
