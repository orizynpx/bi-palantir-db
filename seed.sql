SELECT setseed(0.69);

TRUNCATE TABLE 
    fact_sensor_telemetry_snapshot,
    fact_killchain_decisions,
    fact_threat_detections,
    dim_time,
    dim_date,
    dim_geography,
    dim_operator,
    dim_effector,
    dim_target_category,
    dim_mission,
    dim_sensor
RESTART IDENTITY CASCADE;

-- Dim Sensor
INSERT INTO dim_sensor (sensor_key, sensor_id, sensor_name, sensor_type, status, is_current, valid_from, valid_to)
VALUES 
    (1, 'S-1', 'Radar-Alpha', 'SAT', 'ACTIVE', TRUE, '2026-01-01', NULL),
    (2, 'S-2', 'Drone-Eye-1', 'DRONE', 'ACTIVE', TRUE, '2026-01-01', NULL),
    (3, 'S-3', 'Titan-Scan-A', 'TITAN', 'OFFLINE', TRUE, '2026-01-01', NULL),
    (4, 'S-4', 'Sat-Vanguard', 'SAT', 'ACTIVE', TRUE, '2026-01-01', NULL),
    (5, 'S-5', 'Drone-Eye-2', 'DRONE', 'ACTIVE', TRUE, '2026-01-01', NULL);

-- Dim Mission
INSERT INTO dim_mission (mission_key, mission_id, mission_code, mission_status, priority)
SELECT 
    i AS mission_key,
    1000 + i AS mission_id,
    (ARRAY['M-', 'OP-', 'RECON-', 'PATROL-', 'TASK-'])[floor(random() * 5 + 1)] || LPAD(i::text, 4, '0') AS mission_code,
    (ARRAY['ONGOING', 'COMPLETED', 'ABORTED', 'PLANNED', 'SUSPENDED', 'STANDBY'])[floor(random() * 6 + 1)] AS mission_status,
    (ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'FLASH'])[floor(random() * 5 + 1)] AS priority
FROM generate_series(1, 50) i;

-- Dim Target Category
INSERT INTO dim_target_category (category_key, category_id, category_name, threat_level)
VALUES 
    (1, 101, 'UAV', 'HIGH'),
    (2, 102, 'ARMORED_VEHICLE', 'MEDIUM'),
    (3, 103, 'NAVAL_VESSEL', 'CRITICAL'),
    (4, 104, 'INFANTRY', 'LOW'),
    (5, 105, 'MISSILE', 'CRITICAL');

-- Dim Effector
INSERT INTO dim_effector (effector_key, effector_id, effector_name, effector_type, max_range_km, is_current)
VALUES 
    (1, 'E-101', 'Iron Dome Alpha', 'MISSILE_INTERCEPT', 70.00, TRUE),
    (2, 'E-102', 'Thunderbolt Howitzer', 'ARTILLERY', 40.00, TRUE),
    (3, 'E-103', 'Scorpion Jammer', 'JAMMING', 15.00, TRUE),
    (4, 'E-104', 'Helios Directed Energy', 'DIRECTED_ENERGY', 10.00, TRUE),
    (5, 'E-105', 'Reaper Strike UAV', 'DRONE', 150.00, TRUE),
    (6, 'E-106', 'Phalanx Sea-Gun', 'NAVAL_GUN', 5.50, TRUE),
    (7, 'E-107', 'Cyber Intercept Grid', 'CYBER', 0.00, TRUE);

-- Dim Operator
INSERT INTO dim_operator (operator_key, operator_id, command_post_unit, clearance_level)
SELECT 
    i AS operator_key,
    'OP-' || LPAD(i::text, 3, '0') AS operator_id,
    'Command Unit ' || (ARRAY['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'])[floor(random() * 5 + 1)] AS command_post_unit,
    (ARRAY['CONFIDENTIAL', 'SECRET', 'TOP_SECRET'])[floor(random() * 3 + 1)] AS clearance_level
FROM generate_series(1, 20) i;

-- Dim Geography (Jakarta / West Java area centered coordinates & simulated geospatial hashes)
INSERT INTO dim_geography (geography_key, h3_index_r7, geohash_6, latitude, longitude, region_name)
SELECT 
    i AS geography_key,
    '876543' || LPAD(i::text, 4, '0') AS h3_index_r7,
    'qqg' || LPAD(i::text, 3, '0') AS geohash_6,
    round((-7.00 + random() * 1.50)::numeric, 6) AS latitude,
    round((106.00 + random() * 2.00)::numeric, 6) AS longitude,
    (ARRAY['Greater Jakarta', 'West Java Maritime', 'Southern Coast', 'Air Corridor Alpha', 'Sector Delta'])[floor(random() * 5 + 1)] AS region_name
FROM generate_series(1, 100) i;

-- Dim Date (Populates August & September 2026)
INSERT INTO dim_date (date_key, full_date, year, quarter, month, day_of_week)
SELECT 
    to_char(d, 'YYYYMMDD')::int AS date_key,
    d::date AS full_date,
    EXTRACT(YEAR FROM d)::int AS year,
    EXTRACT(QUARTER FROM d)::int AS quarter,
    EXTRACT(MONTH FROM d)::int AS month,
    EXTRACT(ISODOW FROM d)::int AS day_of_week
FROM generate_series('2026-08-01'::date, '2026-09-30'::date, '1 day'::interval) d;

-- Dim Time (Hourly breakdown to optimize dimensional space)
INSERT INTO dim_time (time_key, hour, minute, second)
SELECT 
    to_char(t, 'HH24MISS')::int AS time_key,
    EXTRACT(HOUR FROM t)::int AS hour,
    EXTRACT(MINUTE FROM t)::int AS minute,
    EXTRACT(SECOND FROM t)::int AS second
FROM generate_series(
    '2026-01-01 00:00:00'::timestamp, 
    '2026-01-01 23:30:00'::timestamp, 
    '30 minutes'::interval
) t;


-- Fact Threat Detections
INSERT INTO fact_threat_detections (
    detection_fact_id,
    sensor_key,
    mission_key,
    category_key,
    geography_key,
    detected_date_key,
    edge_model_version,
    detection_id,
    confidence_score,
    detection_count
)
SELECT 
    i AS detection_fact_id,
    floor(random() * 5 + 1)::bigint AS sensor_key,
    floor(random() * 50 + 1)::bigint AS mission_key,
    floor(random() * 5 + 1)::int AS category_key,
    floor(random() * 100 + 1)::bigint AS geography_key,
    to_char('2026-09-01'::date - (floor(random() * 30) || ' days')::interval, 'YYYYMMDD')::int AS detected_date_key,
    (ARRAY['v1.0.0', 'v1.1.2-beta', 'v1.2.1', 'v2.0.0', 'v2.0.4-patch', 'v2.1.0-rc1', 'v3.0.0-alpha'])[floor(random() * 7 + 1)] AS edge_model_version,
    'DET-' || LPAD(i::text, 6, '0') AS detection_id,
    round((CASE WHEN random() > 0.3 THEN 0.75 + random() * 0.24 ELSE 0.10 + random() * 0.45 END)::numeric, 4) AS confidence_score,
    1 AS detection_count
FROM generate_series(1, 1200) i;

-- Fact Killchain Decisions
INSERT INTO fact_killchain_decisions (
    decision_fact_id,
    sensor_key,
    mission_key,
    category_key,
    effector_key,
    operator_key,
    decided_date_key,
    pairing_status,
    decision_type,
    operational_context,
    kill_chain_latency_ms,
    operator_response_latency_ms,
    total_end_to_end_latency_ms,
    is_authorized,
    is_overridden
)
SELECT 
    i AS decision_fact_id,
    floor(random() * 5 + 1)::bigint AS sensor_key,
    floor(random() * 50 + 1)::bigint AS mission_key,
    floor(random() * 5 + 1)::int AS category_key,
    floor(random() * 7 + 1)::bigint AS effector_key,
    floor(random() * 20 + 1)::bigint AS operator_key,
    to_char('2026-09-01'::date - (floor(random() * 30) || ' days')::interval, 'YYYYMMDD')::int AS decided_date_key,
    (ARRAY['RECOMMENDED', 'EXECUTED', 'CANCELLED', 'FAILED', 'PENDING', 'EXPIRED'])[floor(random() * 6 + 1)] AS pairing_status,
    dec_type AS decision_type,
    (ARRAY['Target visually verified', 'High collateral risk', 'Automated recommendation accepted', 'Sector ROE applied', 'Radar signature ambiguous', 'Thermal confirmation pending', 'Civilian proximity override', 'E-Band jamming detected', 'Command link latency spike'])[floor(random() * 9 + 1)]
    || ' | ' || (ARRAY['WX: Clear', 'WX: Heavy Rain', 'WX: Dense Fog', 'WX: Night Operations'])[floor(random() * 4 + 1)]
    || ' | Priority: P' || floor(random() * 4 + 1) AS operational_context,
    kc_lat AS kill_chain_latency_ms,
    op_lat AS operator_response_latency_ms,
    (kc_lat + op_lat) AS total_end_to_end_latency_ms,
    CASE WHEN dec_type IN ('AUTHORIZE', 'EXECUTED') THEN 1 ELSE 0 END AS is_authorized,
    CASE WHEN dec_type = 'OVERRIDE' THEN 1 ELSE 0 END AS is_overridden
FROM generate_series(1, 1200) i
CROSS JOIN LATERAL (
    SELECT 
        (ARRAY['AUTHORIZE', 'OVERRIDE', 'REJECT', 'DELEGATE', 'ABORT', 'STANDBY'])[floor(random() * 6 + 1)] AS dec_type,
        floor(35 + exp(random() * 3.5) * 40)::int AS kc_lat,
        floor(100 + random() * 2000)::int AS op_lat
) metrics;

-- Fact Sensor Telemetry Snapshot
INSERT INTO fact_sensor_telemetry_snapshot (
    telemetry_snapshot_id,
    sensor_key,
    mission_key,
    geography_key,
    snapshot_date_key,
    snapshot_time_key,
    avg_altitude_meters,
    min_battery_bandwidth_pct,
    network_uptime_seconds,
    telemetry_event_count
)
SELECT 
    i AS telemetry_snapshot_id,
    floor(random() * 5 + 1)::bigint AS sensor_key,
    floor(random() * 50 + 1)::bigint AS mission_key,
    floor(random() * 100 + 1)::bigint AS geography_key,
    to_char('2026-09-01'::date - (floor(random() * 30) || ' days')::interval, 'YYYYMMDD')::int AS snapshot_date_key,
    (ARRAY[0, 3000, 10000, 13000, 20000, 23000, 30000, 33000, 40000, 43000, 50000, 53000, 60000, 63000, 70000, 73000, 80000, 83000, 90000, 93000, 100000, 103000, 110000, 113000, 120000, 123000, 130000, 133000, 140000, 143000, 150000, 153000, 160000, 163000, 170000, 173000, 180000, 183000, 190000, 193000, 200000, 203000, 210000, 213000, 220000, 223000, 230000, 233000])[floor(random() * 48 + 1)] AS snapshot_time_key,
    round((CASE WHEN random() > 0.4 THEN 50 + pow(random(), 3) * 1500 ELSE 15000 + random() * 35000 END)::numeric, 2) AS avg_altitude_meters,
    round((pow(random(), 0.7) * 100)::numeric, 2) AS min_battery_bandwidth_pct,
    floor(random() * 3600)::int AS network_uptime_seconds,
    floor(random() * 50 + 1)::int AS telemetry_event_count
FROM generate_series(1, 1200) i;