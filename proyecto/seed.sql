-- ============================================================
-- SEED: datos de prueba para app de gastos personales
-- Ejecutar después de schema.sql y queries.sql
-- ============================================================

-- Usuarios
INSERT INTO "user" (name, email, password) VALUES
    ('Ana García',    'ana.garcia@email.com',  'hashed_pw_1'),
    ('Carlos López',  'carlos.lopez@email.com', 'hashed_pw_2');

-- Cuentas
INSERT INTO account (name, balance, type, id_user) VALUES
    ('Cuenta Corriente Ana',    2500000.00, 'checking', 1),
    ('Ahorros Ana',             8000000.00, 'savings',  1),
    ('Cuenta Corriente Carlos', 1800000.00, 'checking', 2);

-- Categorías
INSERT INTO category (name, type) VALUES
    ('Alimentación',    'expense'),   -- 1
    ('Transporte',      'expense'),   -- 2
    ('Entretenimiento', 'expense'),   -- 3
    ('Salud',           'expense'),   -- 4
    ('Salario',         'income'),    -- 5
    ('Servicios',       'expense');   -- 6

-- Transacciones (el trigger actualiza el balance automáticamente)
-- Ana – cuenta corriente (id_account = 1)
INSERT INTO transaction (amount, type, description, date, id_account) VALUES
    (4500000.00, 'income',  'Salario junio',              '2026-06-01', 1),
    (85000.00,   'expense', 'Mercado semanal',             '2026-06-02', 1),
    (15000.00,   'expense', 'Bus mensual',                 '2026-06-03', 1),
    (120000.00,  'expense', 'Cena restaurante',            '2026-06-05', 1),
    (250000.00,  'expense', 'Consulta médica',             '2026-06-07', 1),
    (65000.00,   'expense', 'Netflix + Spotify',           '2026-06-08', 1),
    (95000.00,   'expense', 'Mercado semanal',             '2026-06-10', 1),
    (180000.00,  'expense', 'Recibo de luz y gas',         '2026-06-12', 1),
    (45000.00,   'expense', 'Taxi aeropuerto',             '2026-06-14', 1),
    (320000.00,  'expense', 'Compras de ropa',             '2026-06-15', 1);

-- Carlos – cuenta corriente (id_account = 3)
INSERT INTO transaction (amount, type, description, date, id_account) VALUES
    (3800000.00, 'income',  'Salario junio',              '2026-06-01', 3),
    (110000.00,  'expense', 'Mercado',                    '2026-06-03', 3),
    (200000.00,  'expense', 'Gasolina mes',               '2026-06-04', 3),
    (75000.00,   'expense', 'Cine + comida',              '2026-06-06', 3),
    (90000.00,   'expense', 'Internet + TV cable',        '2026-06-10', 3);

-- Categorizar transacciones (transaction_category)
-- Ana
INSERT INTO transaction_category (id_transaction, id_category) VALUES
    (1,  5),  -- Salario junio          → Salario
    (2,  1),  -- Mercado                → Alimentación
    (3,  2),  -- Bus                    → Transporte
    (4,  1),  -- Cena restaurante       → Alimentación
    (4,  3),  -- Cena restaurante       → Entretenimiento
    (5,  4),  -- Consulta médica        → Salud
    (6,  3),  -- Streaming              → Entretenimiento
    (7,  1),  -- Mercado                → Alimentación
    (8,  6),  -- Servicios públicos     → Servicios
    (9,  2),  -- Taxi                   → Transporte
    (10, 3);  -- Ropa (entretenimiento/compras)

-- Carlos
INSERT INTO transaction_category (id_transaction, id_category) VALUES
    (11, 5),  -- Salario                → Salario
    (12, 1),  -- Mercado                → Alimentación
    (13, 2),  -- Gasolina               → Transporte
    (14, 3),  -- Cine                   → Entretenimiento
    (15, 6);  -- Internet               → Servicios

-- Presupuestos
INSERT INTO budget (limit_amount, period, alert_threshold, id_user, id_category) VALUES
    (400000.00,  'monthly', 80.00, 1, 1),  -- Ana: $400k en Alimentación, alerta al 80%
    (200000.00,  'monthly', 75.00, 1, 3),  -- Ana: $200k en Entretenimiento, alerta al 75%
    (300000.00,  'monthly', 80.00, 2, 1),  -- Carlos: $300k en Alimentación, alerta al 80%
    (250000.00,  'monthly', 70.00, 2, 2);  -- Carlos: $250k en Transporte, alerta al 70%

-- Alertas (generadas manualmente para datos históricos;
--           las nuevas transacciones las genera el trigger automáticamente)
INSERT INTO alert (message, description, id_budget) VALUES
    (
        'Umbral de presupuesto superado',
        'Has gastado $300000.00 de $400000.00 (75%) en el presupuesto #1.',
        1
    ),
    (
        'Umbral de presupuesto superado',
        'Has gastado $185000.00 de $200000.00 (92.5%) en el presupuesto #2.',
        2
    );
