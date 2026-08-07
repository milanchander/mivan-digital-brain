-- schema-postgres.sql  Aurora PostgreSQL DDL — MICPS-4471
-- Mirrors MIVANCPS DB2 z/OS schema for Java track deployment
-- Applied via Flyway in prod; H2 uses Hibernate ddl-auto=create-drop

CREATE SCHEMA IF NOT EXISTS mivancps;

CREATE TABLE IF NOT EXISTS mivancps.claim_payment (
    claim_id            VARCHAR(20)      NOT NULL,
    member_id           VARCHAR(15)      NOT NULL,
    prov_npi            VARCHAR(10)      NOT NULL,
    dos_from            INTEGER          NOT NULL,
    dos_to              INTEGER,
    cpt_cd              VARCHAR(5)       NOT NULL,
    modifier_1          VARCHAR(2),
    modifier_2          VARCHAR(2),
    charge_amt          NUMERIC(9,2)     NOT NULL,
    paid_amt            NUMERIC(9,2),
    payment_status_cd   VARCHAR(2),
    payment_dt          INTEGER,
    CONSTRAINT claim_payment_pk PRIMARY KEY (claim_id)
);

CREATE INDEX IF NOT EXISTS cp_ix1
    ON mivancps.claim_payment (member_id, prov_npi, cpt_cd, dos_from, payment_status_cd);

CREATE TABLE IF NOT EXISTS mivancps.near_dup_queue (
    ndup_claim_id       VARCHAR(20)      NOT NULL,
    ndup_orig_claim_id  VARCHAR(20)      NOT NULL,
    ndup_member_id      VARCHAR(15)      NOT NULL,
    ndup_prov_npi       VARCHAR(10)      NOT NULL,
    ndup_dos            INTEGER          NOT NULL,
    ndup_cpt_cd         VARCHAR(5)       NOT NULL,
    ndup_charge_amt     NUMERIC(9,2)     NOT NULL,
    ndup_match_type     VARCHAR(10)      NOT NULL
                            CHECK (ndup_match_type IN (''DATE-DRIFT'',''AMT-VAR'',''MODIFIER'',''COMBINED'')),
    ndup_pend_reason    VARCHAR(20)      NOT NULL DEFAULT ''NEAR-DUP-REVIEW'',
    ndup_create_dt      INTEGER          NOT NULL,
    ndup_status         CHAR(1)          NOT NULL DEFAULT ''P''
                            CHECK (ndup_status IN (''P'',''A'',''D'')),
    CONSTRAINT near_dup_queue_pk PRIMARY KEY (ndup_claim_id),
    CONSTRAINT ndupq_fk1 FOREIGN KEY (ndup_claim_id)
        REFERENCES mivancps.claim_payment (claim_id)
        ON DELETE RESTRICT
);

CREATE INDEX IF NOT EXISTS ndupq_ix1
    ON mivancps.near_dup_queue (ndup_status ASC, ndup_create_dt ASC);

CREATE INDEX IF NOT EXISTS ndupq_ix2
    ON mivancps.near_dup_queue (ndup_member_id, ndup_dos);

CREATE INDEX IF NOT EXISTS ndupq_ix3
    ON mivancps.near_dup_queue (ndup_pend_reason, ndup_status);