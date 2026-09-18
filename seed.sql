-- Seed 5 rows each into the master tables

INSERT INTO edge_sensors (sensor_id, sensor_name, sensor_type, status, last_known_latitude, last_known_longitude, created_at)
VALUES 
  ('S-1', 'Radar-Alpha', 'SAT', 'ACTIVE', -6.1750, 106.8283, NOW() - INTERVAL '30 days'),
  ('S-2', 'Drone-Eye-1', 'DRONE', 'ACTIVE', -6.2012, 106.8541, NOW() - INTERVAL '20 days'),
  ('S-3', 'Titan-Scan-A', 'TITAN', 'OFFLINE', -6.1523, 106.8011, NOW() - INTERVAL '15 days'),
  ('S-4', 'Sat-Vanguard', 'SAT', 'ACTIVE', -6.2289, 106.8834, NOW() - INTERVAL '10 days'),
  ('S-5', 'Drone-Eye-2', 'DRONE', 'ACTIVE', -6.1845, 106.8392, NOW() - INTERVAL '5 days');

INSERT INTO target_categories (category_id, category_name, threat_level, description)
VALUES 
  (1, 'UAV', 'HIGH', 'Unmanned Aerial Vehicle'),
  (2, 'ARMORED_VEHICLE', 'MEDIUM', 'Ground Reconnaissance Vehicle'),
  (3, 'NAVAL_VESSEL', 'CRITICAL', 'Patrol Vessel'),
  (4, 'INFANTRY', 'LOW', 'Foot Patrol Unit'),
  (5, 'MISSILE', 'CRITICAL', 'Ballistic Projectile');

-- Seed 1200 rows of data into the transactional tables

INSERT INTO sensor_telemetry_logs (sensor_id, timestamp, altitude_meters, battery_bandwidth_pct, latitude, longitude, network_connected)
SELECT 
  (ARRAY['S-1', 'S-2', 'S-3', 'S-4', 'S-5'])[floor(random() * 5 + 1)],
  NOW() - (i || ' seconds')::interval,
  round((50 + random() * 4950)::numeric, 2),
  round((15 + random() * 85)::numeric, 1),
  round((-6.25 + random() * 0.1)::numeric, 6),
  round((106.75 + random() * 0.1)::numeric, 6),
  (random() > 0.05)
FROM generate_series(1, 1200) i;

INSERT INTO threat_detections (sensor_id, category_id, detected_at, confidence_score, latitude, longitude, bounding_box_json, edge_model_version)
SELECT 
  (ARRAY['S-1', 'S-2', 'S-3', 'S-4', 'S-5'])[floor(random() * 5 + 1)],
  floor(random() * 5 + 1)::int,
  NOW() - (i || ' minutes')::interval,
  round((0.55 + random() * 0.44)::numeric, 2),
  round((-6.25 + random() * 0.1)::numeric, 6),
  round((106.75 + random() * 0.1)::numeric, 6),
  jsonb_build_object(
    'x', floor(random() * 800),
    'y', floor(random() * 600),
    'w', floor(random() * 150 + 20),
    'h', floor(random() * 150 + 20)
  ),
  (ARRAY['v1.0.0', 'v1.2.1', 'v2.0.4'])[floor(random() * 3 + 1)]
FROM generate_series(1, 1200) i;

INSERT INTO targeting_effector_pairings (detection_id, effector_type, paired_at, kill_chain_latency_ms, target_latitude, target_longitude, pairing_status)
SELECT 
  i, 
  (ARRAY['ARTILLERY', 'DRONE', 'JAMMING'])[floor(random() * 3 + 1)], 
  NOW() - (i || ' minutes')::interval + interval '2 seconds',
  floor(80 + random() * 1420),
  round((-6.25 + random() * 0.1)::numeric, 6),
  round((106.75 + random() * 0.1)::numeric, 6),
  (ARRAY['RECOMMENDED', 'EXECUTED', 'CANCELLED'])[floor(random() * 3 + 1)]
FROM generate_series(1, 1200) i;

INSERT INTO operator_decision_logs (pairing_id, operator_id, decision_type, decided_at, operational_context, command_post_latitude, command_post_longitude)
SELECT 
  i, 
  'OP-' || floor(random() * 5 + 1)::int, 
  (ARRAY['AUTHORIZE', 'OVERRIDE', 'REJECT'])[floor(random() * 3 + 1)], 
  NOW() - (i || ' minutes')::interval + interval '5 seconds',
  (ARRAY['Target visually verified', 'High collateral risk', 'Automated recommendation accepted', 'Sector rule of engagement applied'])[floor(random() * 4 + 1)],
  -6.1750, 106.8283
FROM generate_series(1, 1200) i;

INSERT INTO mission_deployments (mission_code, area_of_responsibility_geojson, start_time, end_time, mission_status, priority)
SELECT 
  'M-' || LPAD(i::text, 4, '0'),
  jsonb_build_object(
    'type', 'Polygon',
    'coordinates', jsonb_build_array(
      jsonb_build_array(
        jsonb_build_array(pts.p_lon, pts.p_lat),
        jsonb_build_array(pts.p_lon + 0.05, pts.p_lat),
        jsonb_build_array(pts.p_lon + 0.05, pts.p_lat + 0.05),
        jsonb_build_array(pts.p_lon, pts.p_lat)
      )
    )
  ),
  NOW() - (i || ' hours')::interval,
  NOW() - (i || ' hours')::interval + (floor(random() * 8 + 1) || ' hours')::interval,
  (ARRAY['ONGOING', 'COMPLETED', 'ABORTED'])[floor(random() * 3 + 1)],
  (ARRAY['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'])[floor(random() * 4 + 1)]
FROM generate_series(1, 1200) i
CROSS JOIN LATERAL (
  SELECT round((106.70 + random() * 0.05)::numeric, 4) AS p_lon,
         round((-6.30 + random() * 0.05)::numeric, 4) AS p_lat
) pts;