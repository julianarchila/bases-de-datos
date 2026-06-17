CREATE TABLE "user" (
    id_user   SERIAL PRIMARY KEY,
    name      VARCHAR(100)        NOT NULL,
    email     VARCHAR(150) UNIQUE NOT NULL,
    password  VARCHAR(255)        NOT NULL
);

CREATE TABLE account (
    id_account SERIAL PRIMARY KEY,
    name       VARCHAR(100)   NOT NULL,
    balance    DECIMAL(12, 2) NOT NULL DEFAULT 0,
    type       VARCHAR(50)    NOT NULL,
    id_user    INT            NOT NULL REFERENCES "user" (id_user)
);

CREATE TABLE transaction (
    id_transaction SERIAL PRIMARY KEY,
    amount         DECIMAL(12, 2) NOT NULL,
    type           VARCHAR(50)    NOT NULL,
    description    TEXT,
    date           DATE           NOT NULL,
    id_account     INT            NOT NULL REFERENCES account (id_account)
);

CREATE TABLE category (
    id_category SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL,
    type        VARCHAR(50)  NOT NULL
);

CREATE TABLE transaction_category (
    id_transaction INT NOT NULL REFERENCES transaction (id_transaction),
    id_category    INT NOT NULL REFERENCES category (id_category),
    PRIMARY KEY (id_transaction, id_category)
);

CREATE TABLE budget (
    id_budget        SERIAL PRIMARY KEY,
    limit_amount     DECIMAL(12, 2) NOT NULL,
    period           VARCHAR(50)    NOT NULL,
    alert_threshold  DECIMAL(5, 2)  NOT NULL,
    id_user          INT            NOT NULL REFERENCES "user" (id_user),
    id_category      INT            NOT NULL REFERENCES category (id_category)
);

CREATE TABLE alert (
    id_alert    SERIAL PRIMARY KEY,
    message     VARCHAR(255) NOT NULL,
    description TEXT,
    id_budget   INT          NOT NULL REFERENCES budget (id_budget)
);
