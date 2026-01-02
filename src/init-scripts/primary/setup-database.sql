-- =====================================================================
-- 2. TYPOWE ENUMY / TYPOWANIE LOGICZNE
-- =====================================================================

-- Role użytkowników zgodne z UC:
--  - ADMIN      – pełne zarządzanie
--  - OPERATOR   – dodaje/edytuje odczyty
--  - CLIENT     – klient końcowy, widzi swoje liczniki
CREATE ROLE replicator WITH REPLICATION LOGIN PASSWORD 'replicator_password';
CREATE ROLE failover LOGIN PASSWORD 'failover_pass' SUPERUSER;
CREATE TYPE user_role AS ENUM ('ADMIN', 'OPERATOR', 'CLIENT');

-- Opcjonalny status licznika (czy licznik jest aktywny)
CREATE TYPE meter_status AS ENUM ('ACTIVE', 'INACTIVE');

-- =====================================================================
-- 3. TABELA UŻYTKOWNIKÓW
--    (logowanie, role, e-mail do powiadomień itd.)
-- =====================================================================

CREATE TABLE app_user (
    id              BIGSERIAL PRIMARY KEY,
    username        VARCHAR(64)  NOT NULL UNIQUE,
    email           VARCHAR(255) NOT NULL UNIQUE,
    password_hash   VARCHAR(255) NOT NULL, -- np. bcrypt/argon2
    role            user_role    NOT NULL DEFAULT 'CLIENT',
    is_active       BOOLEAN      NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Prosty trigger do automatycznej aktualizacji updated_at (opcjonalne):
CREATE OR REPLACE FUNCTION set_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_app_user_set_timestamp
BEFORE UPDATE ON app_user
FOR EACH ROW
EXECUTE FUNCTION set_timestamp();

-- =====================================================================
-- 4. STRUKTURA GEOGRAFICZNA – OBSZARY I ADRESY
--    (raporty po obszarze, filtrowanie po adresie)
-- =====================================================================

-- Obszar działania (np. miasto, dzielnica, rejon)
CREATE TABLE region (
    id          BIGSERIAL PRIMARY KEY,
    code        VARCHAR(32)  NOT NULL UNIQUE, -- np. "PL-WRO-01"
    name        VARCHAR(255) NOT NULL        -- np. "Wrocław – Centrum"
);

-- Adres, do którego można przypisać licznik
CREATE TABLE address (
    id              BIGSERIAL PRIMARY KEY,
    region_id       BIGINT      NOT NULL REFERENCES region(id) ON DELETE RESTRICT,
    city            VARCHAR(128) NOT NULL,
    street          VARCHAR(128) NOT NULL,
    house_number    VARCHAR(16)  NOT NULL,
    apartment_number VARCHAR(16),          -- NULL jeśli brak
    postal_code     VARCHAR(16),          -- np. "50-001"
    latitude        NUMERIC(9,6),         -- opcjonalnie geolokacja
    longitude       NUMERIC(9,6)
);

CREATE INDEX idx_address_region ON address(region_id);

-- =====================================================================
-- 5. LICZNIKI (METERS)
-- =====================================================================

CREATE TABLE meter (
    id                   BIGSERIAL PRIMARY KEY,
    meter_number         VARCHAR(64) NOT NULL UNIQUE,  -- numer licznika
    installation_address_id BIGINT   NOT NULL REFERENCES address(id) ON DELETE RESTRICT,
    owner_user_id        BIGINT REFERENCES app_user(id) ON DELETE SET NULL, -- klient
    status               meter_status NOT NULL DEFAULT 'ACTIVE',
    installation_date    DATE,
    deactivation_date    DATE,
    notes                TEXT
);

CREATE INDEX idx_meter_owner       ON meter(owner_user_id);
CREATE INDEX idx_meter_address     ON meter(installation_address_id);

-- =====================================================================
-- 6. ODCZYTY LICZNIKÓW (READINGS)
--    – kluczowa tabela zgodna z UC2, UC3, UC5
-- =====================================================================

CREATE TABLE reading (
    id              BIGSERIAL PRIMARY KEY,
    meter_id        BIGINT      NOT NULL REFERENCES meter(id) ON DELETE CASCADE,
    reading_time    TIMESTAMPTZ NOT NULL,          -- data pomiaru
    value_m3        NUMERIC(12,3) NOT NULL,        -- wartość odczytu w m³
    note            TEXT,                          -- ewentualne uwagi
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_by      BIGINT REFERENCES app_user(id) ON DELETE SET NULL
);

-- Zakładamy, że dla danego licznika możemy mieć co najwyżej jeden odczyt
-- dla tej samej chwili czasowej:
ALTER TABLE reading
    ADD CONSTRAINT uq_meter_time UNIQUE (meter_id, reading_time);

-- Dodatkowe ograniczenie: wartość >= 0
ALTER TABLE reading
    ADD CONSTRAINT chk_reading_nonnegative CHECK (value_m3 >= 0);

CREATE INDEX idx_reading_meter_time ON reading(meter_id, reading_time DESC);

-- =====================================================================
-- 7. ZDARZENIA / ALERTY (opcjonalnie – UC5: alerty o skokach zużycia)
-- =====================================================================

CREATE TYPE alert_type AS ENUM ('SUSPICIOUS_USAGE', 'LEAK_SUSPECTED', 'OTHER');

CREATE TABLE meter_alert (
    id              BIGSERIAL PRIMARY KEY,
    meter_id        BIGINT NOT NULL REFERENCES meter(id) ON DELETE CASCADE,
    alert_time      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    type            alert_type NOT NULL,
    description     TEXT,
    is_resolved     BOOLEAN NOT NULL DEFAULT FALSE,
    resolved_at     TIMESTAMPTZ,
    resolved_by     BIGINT REFERENCES app_user(id) ON DELETE SET NULL
);

CREATE INDEX idx_meter_alert_meter_time ON meter_alert(meter_id, alert_time DESC);

-- =====================================================================
-- 8. RAPORTY (UC4) – LOG METADANYCH WYGNEROWANYCH RAPORTÓW
--    (same dane agregujemy SELECT-ami, tu tylko meta + ścieżka/ID pliku)
-- =====================================================================

CREATE TABLE usage_report (
    id                  BIGSERIAL PRIMARY KEY,
    generated_by        BIGINT REFERENCES app_user(id) ON DELETE SET NULL,
    generated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    region_id           BIGINT REFERENCES region(id) ON DELETE SET NULL,
    date_from           DATE NOT NULL,
    date_to             DATE NOT NULL,
    format              VARCHAR(16) NOT NULL CHECK (format IN ('PDF','CSV')),
    file_path           TEXT NOT NULL, -- np. ścieżka na serwerze / w S3
    description         TEXT
);

CREATE INDEX idx_usage_report_region_date
    ON usage_report(region_id, date_from, date_to);

-- =====================================================================
-- 9. PRZYKŁADOWE WIDOKI POMOCNICZE
--    (nie są wymagane, ale przydadzą się w aplikacji / raportach)
-- =====================================================================

-- Ostatni odczyt dla każdego licznika – przydatne do UC5
CREATE OR REPLACE VIEW v_meter_last_reading AS
SELECT DISTINCT ON (m.id)
    m.id                    AS meter_id,
    m.meter_number,
    m.owner_user_id,
    r.reading_time,
    r.value_m3,
    r.note
FROM meter m
LEFT JOIN reading r
       ON r.meter_id = m.id
ORDER BY m.id, r.reading_time DESC;

-- Dzienne/miesięczne zużycie wody per licznik (różnica między kolejnymi odczytami)
-- Przykład: zużycie per dzień
CREATE OR REPLACE VIEW v_meter_daily_usage AS
SELECT
    meter_id,
    date_trunc('day', reading_time) AS day,
    value_m3 - LAG(value_m3) OVER (PARTITION BY meter_id ORDER BY reading_time) AS usage_m3
FROM reading
ORDER BY meter_id, day;


-- =====================================================================
-- INITIAL DATA FOR WATER METER SYSTEM
-- (to be run AFTER CREATE TABLES)
-- =====================================================================

-- ========================================
-- 1. USERS
-- ========================================

-- przykładowe bcrypt (hasło: "admin123")
-- możesz wygenerować nowe np. w Pythonie: bcrypt.hashpw(...)
INSERT INTO app_user (username, email, password_hash, role)
VALUES
    ('admin',    'admin@example.com',    '$2b$12$eImiTXuWVxfM37uY4JANjQ==', 'ADMIN'),
    ('operator', 'operator@example.com', '$2b$12$2khmWRzq7pXv0uL4qY5FSu==', 'OPERATOR'),
    ('client1',  'client1@example.com',  '$2b$12$XpPOp6WavR2PvTQu4W4n9u==', 'CLIENT'),
    ('client2',  'client2@example.com',  '$2b$12$XpPOp6WavR2PvTQu4W4n9u==', 'CLIENT');

-- ========================================
-- 2. REGIONS
-- ========================================

INSERT INTO region (code, name)
VALUES
    ('PL-WRO-01', 'Wrocław – Śródmieście'),
    ('PL-WRO-02', 'Wrocław – Fabryczna'),
    ('PL-WRO-03', 'Wrocław – Krzyki');

-- ========================================
-- 3. ADDRESSES
-- ========================================

INSERT INTO address (region_id, city, street, house_number, apartment_number, postal_code, latitude, longitude)
VALUES
    (1, 'Wrocław', 'Norwida', '15', '12', '50-374', 51.1160, 17.0600),
    (1, 'Wrocław', 'Reja', '8',  NULL, '50-354', 51.1201, 17.0525),
    (2, 'Wrocław', 'Legnicka', '45', '5', '54-203', 51.1284, 16.9901),
    (3, 'Wrocław', 'Powstańców Śląskich', '101', NULL, '53-332', 51.0902, 17.0208);

-- ========================================
-- 4. METERS
-- ========================================

INSERT INTO meter (meter_number, installation_address_id, owner_user_id, status, installation_date, notes)
VALUES
    ('WM-100001', 1, 3, 'ACTIVE', '2022-03-01', 'Licznik w mieszkaniu klient1'),
    ('WM-100002', 2, 3, 'ACTIVE', '2021-11-10', 'Drugi licznik klient1'),
    ('WM-200001', 3, 4, 'ACTIVE', '2023-01-15', 'Licznik klient2'),
    ('WM-300001', 4, NULL, 'ACTIVE', '2022-05-20', 'Licznik firmowy – brak właściciela');

-- ========================================
-- 5. READINGS
-- ========================================
-- Dla klient1 – licznik WM-100001

INSERT INTO reading (meter_id, reading_time, value_m3, note, created_by)
VALUES
    (1, '2024-01-01 08:00', 120.500, 'Odczyt początkowy', 2),
    (1, '2024-02-01 08:00', 128.900, NULL, 2),
    (1, '2024-03-01 08:00', 135.200, 'Wzrost zużycia', 2);

-- Drugi licznik klient1 – WM-100002
INSERT INTO reading (meter_id, reading_time, value_m3, note, created_by)
VALUES
    (2, '2024-01-01 09:00', 300.000, NULL, 2),
    (2, '2024-02-01 09:00', 312.300, NULL, 2);

-- Klient2 – WM-200001
INSERT INTO reading (meter_id, reading_time, value_m3, note, created_by)
VALUES
    (3, '2024-01-15 07:30', 50.800, 'Instalacja', 2),
    (3, '2024-02-15 07:30', 56.100, NULL, 2),
    (3, '2024-03-15 07:30', 62.400, 'Możliwy wyciek?', 2);

-- Licznik firmowy – WM-300001
INSERT INTO reading (meter_id, reading_time, value_m3, note, created_by)
VALUES
    (4, '2024-01-10 12:00', 1000.000, NULL, 2),
    (4, '2024-02-10 12:00', 1035.200, NULL, 2);

-- ========================================
-- 6. ALERTS
-- ========================================

INSERT INTO meter_alert (meter_id, alert_time, type, description, is_resolved)
VALUES
    (3, '2024-03-20 14:00', 'SUSPICIOUS_USAGE',
     'Nagły skok zużycia – licznik WM-200001', FALSE);

-- ========================================
-- 7. EXAMPLE REPORT ENTRY
-- ========================================

INSERT INTO usage_report (generated_by, region_id, date_from, date_to, format, file_path, description)
VALUES
    (1, 1, '2024-01-01', '2024-03-31', 'PDF',
     '/var/reports/report_wro_01_q1_2024.pdf',
     'Raport kwartalny dla regionu PL-WRO-01');

