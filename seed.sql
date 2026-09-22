SELECT setseed(0.69);

TRUNCATE TABLE 
  operator_decision_logs,
  targeting_effector_pairings,
  threat_detections,
  sensor_telemetry_logs,
  mission_deployments,
  target_categories,
  edge_sensors
RESTART IDENTITY CASCADE;

-- Master tables
INSERT INTO edge_sensors (sensor_id, sensor_name, sensor_type, status, last_known_latitude, last_known_longitude, created_at)
VALUES 
  ('S-1', 'Radar-Alpha', 'SAT', 'ACTIVE', -6.1750, 106.8283, '2026-09-01 12:00:00+00'::timestamptz - INTERVAL '30 days'),
  ('S-2', 'Drone-Eye-1', 'DRONE', 'ACTIVE', -6.2012, 106.8541, '2026-09-01 12:00:00+00'::timestamptz - INTERVAL '20 days'),
  ('S-3', 'Titan-Scan-A', 'TITAN', 'OFFLINE', -6.1523, 106.8011, '2026-09-01 12:00:00+00'::timestamptz - INTERVAL '15 days'),
  ('S-4', 'Sat-Vanguard', 'SAT', 'ACTIVE', -6.2289, 106.8834, '2026-09-01 12:00:00+00'::timestamptz - INTERVAL '10 days'),
  ('S-5', 'Drone-Eye-2', 'DRONE', 'ACTIVE', -6.1845, 106.8392, '2026-09-01 12:00:00+00'::timestamptz - INTERVAL '5 days');

INSERT INTO target_categories (category_id, category_name, threat_level, description)
VALUES 
  (1, 'UAV', 'HIGH', 'Unmanned Aerial Vehicle'),
  (2, 'ARMORED_VEHICLE', 'MEDIUM', 'Ground Reconnaissance Vehicle'),
  (3, 'NAVAL_VESSEL', 'CRITICAL', 'Patrol Vessel'),
  (4, 'INFANTRY', 'LOW', 'Foot Patrol Unit'),
  (5, 'MISSILE', 'CRITICAL', 'Ballistic Projectile');

-- Transactional tables
INSERT INTO sensor_telemetry_logs (sensor_id, timestamp, altitude_meters, battery_bandwidth_pct, latitude, longitude, network_connected)
SELECT 
  (ARRAY['S-1', 'S-2', 'S-3', 'S-4', 'S-5'])[floor(random() * 5 + 1)],
  '2026-09-01 12:00:00+00'::timestamptz - (pow(random(), 2) * 2592000 || ' seconds')::interval,
  round((CASE WHEN random() > 0.4 THEN 50 + pow(random(), 3) * 1500 ELSE 15000 + random() * 35000 END)::numeric, 2),
  round((pow(random(), 0.7) * 100)::numeric, 1),
  round((-7.00 + random() * 1.50)::numeric, 6),
  round((106.00 + random() * 2.00)::numeric, 6),
  (random() > 0.12)
FROM generate_series(1, 1200) i;

INSERT INTO threat_detections (sensor_id, category_id, detected_at, confidence_score, latitude, longitude, bounding_box_json, edge_model_version)
SELECT 
  (ARRAY['S-1', 'S-2', 'S-3', 'S-4', 'S-5'])[floor(random() * 5 + 1)],
  floor(random() * 5 + 1)::int,
  '2026-09-01 12:00:00+00'::timestamptz - (random() * 2592000 || ' seconds')::interval,
  round((CASE WHEN random() > 0.3 THEN 0.75 + random() * 0.24 ELSE 0.10 + random() * 0.45 END)::numeric, 2),
  round((-7.00 + random() * 1.50)::numeric, 6),
  round((106.00 + random() * 2.00)::numeric, 6),
  jsonb_build_object(
    'x', floor(random() * 3840),
    'y', floor(random() * 2160),
    'w', floor(pow(random(), 2) * 600 + 10),
    'h', floor(pow(random(), 2) * 600 + 10),
    'rotation_deg', round((random() * 360)::numeric, 1),
    'inference_time_ms', floor(12 + pow(random(), 2) * 250)
  ),
  (ARRAY['v1.0.0', 'v1.1.2-beta', 'v1.2.1', 'v2.0.0', 'v2.0.4-patch', 'v2.1.0-rc1', 'v3.0.0-alpha'])[floor(random() * 7 + 1)]
FROM generate_series(1, 1200) i;

INSERT INTO targeting_effector_pairings (detection_id, effector_type, paired_at, kill_chain_latency_ms, target_latitude, target_longitude, pairing_status)
SELECT 
  td.detection_id, 
  (ARRAY['ARTILLERY', 'DRONE', 'JAMMING', 'MISSILE_INTERCEPT', 'CYBER', 'DIRECTED_ENERGY', 'NAVAL_GUN'])[floor(random() * 7 + 1)], 
  td.detected_at + (floor(1 + pow(random(), 3) * 120) || ' seconds')::interval,
  floor(35 + exp(random() * 3.5) * 40),
  round((td.latitude + (random() * 0.02 - 0.01))::numeric, 6),
  round((td.longitude + (random() * 0.02 - 0.01))::numeric, 6),
  (ARRAY['RECOMMENDED', 'EXECUTED', 'CANCELLED', 'FAILED', 'PENDING', 'EXPIRED'])[floor(random() * 6 + 1)]
FROM threat_detections td;

INSERT INTO operator_decision_logs (pairing_id, operator_id, decision_type, decided_at, operational_context, command_post_latitude, command_post_longitude)
SELECT 
  tep.pairing_id, 
  'OP-' || LPAD(floor(pow(random(), 1.2) * 150 + 1)::text, 3, '0'),
  (ARRAY['AUTHORIZE', 'OVERRIDE', 'REJECT', 'DELEGATE', 'ABORT', 'STANDBY'])[floor(random() * 6 + 1)], 
  tep.paired_at + (floor(1 + pow(random(), 2) * 300) || ' seconds')::interval,
  (ARRAY['Target visually verified', 'High collateral risk', 'Automated recommendation accepted', 'Sector ROE applied', 'Radar signature ambiguous', 'Thermal confirmation pending', 'Civilian proximity override', 'E-Band jamming detected', 'Command link latency spike'])[floor(random() * 9 + 1)]
  || ' | ' || (ARRAY['WX: Clear', 'WX: Heavy Rain', 'WX: Dense Fog', 'WX: Night Operations'])[floor(random() * 4 + 1)]
  || ' | Priority: P' || floor(random() * 4 + 1),
  round((-6.50 + random() * 1.00)::numeric, 6),
  round((106.20 + random() * 1.00)::numeric, 6)
FROM targeting_effector_pairings tep;

INSERT INTO mission_deployments (mission_code, area_of_responsibility_geojson, start_time, end_time, mission_status, priority)
SELECT 
  (ARRAY['M-', 'OP-', 'RECON-', 'PATROL-', 'TASK-'])[floor(random() * 5 + 1)] || LPAD(i::text, 4, '0'),
  jsonb_build_object(
    'type', 'Polygon',
    'coordinates', jsonb_build_array(
      jsonb_build_array(
        jsonb_build_array(pts.lon, pts.lat),
        jsonb_build_array(pts.lon + round((random() * 0.12 + 0.01)::numeric, 4), pts.lat + round((random() * 0.03 - 0.01)::numeric, 4)),
        jsonb_build_array(pts.lon + round((random() * 0.15 + 0.02)::numeric, 4), pts.lat + round((random() * 0.12 + 0.02)::numeric, 4)),
        jsonb_build_array(pts.lon + round((random() * 0.04 - 0.02)::numeric, 4), pts.lat + round((random() * 0.14 + 0.03)::numeric, 4)),
        jsonb_build_array(pts.lon - round((random() * 0.05)::numeric, 4), pts.lat + round((random() * 0.05)::numeric, 4)),
        jsonb_build_array(pts.lon, pts.lat)
      )
    )
  ),
  '2026-09-01 12:00:00+00'::timestamptz - (random() * 2592000 || ' seconds')::interval,
  '2026-09-01 12:00:00+00'::timestamptz - (random() * 2592000 || ' seconds')::interval + (floor(exp(random() * 4) * 2 + 1) || ' hours')::interval,
  (ARRAY['ONGOING', 'COMPLETED', 'ABORTED', 'PLANNED', 'SUSPENDED', 'STANDBY'])[floor(random() * 6 + 1)],
  (ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL', 'FLASH'])[floor(random() * 5 + 1)]
FROM generate_series(1, 1200) i
CROSS JOIN LATERAL (
  SELECT round((105.80 + random() * 2.00)::numeric, 4) AS lon,
         round((-7.20 + random() * 1.80)::numeric, 4) AS lat
) pts;