# Palantir DB

This the the repository for a mock database themed around the software company Palantir. A Business Intelligence assignment.

## Database Design

```mermaid
erDiagram
    edge_sensors ||--o{ sensor_telemetry_logs : "records telemetry (1:N)"
    edge_sensors ||--o{ threat_detections : "detects threats (1:N)"
    target_categories ||--o{ threat_detections : "categorizes (1:N)"
    threat_detections ||--o{ targeting_effector_pairings : "initiates kill-chain (1:N)"
    targeting_effector_pairings ||--o| operator_decision_logs : "reviewed by human (1:1/1:N)"
    mission_deployments ||--o{ threat_detections : "contains via GeoJSON / BBox"

    edge_sensors {
        VARCHAR sensor_id PK "Primary Key"
        VARCHAR sensor_name
        VARCHAR sensor_type "SAT / DRONE / TITAN"
        VARCHAR status "ACTIVE / OFFLINE"
        DOUBLE_PRECISION last_known_latitude
        DOUBLE_PRECISION last_known_longitude
        TIMESTAMPTZ created_at
    }

    target_categories {
        SERIAL category_id PK "Primary Key"
        VARCHAR category_name "Unique"
        VARCHAR threat_level "LOW to CRITICAL"
        TEXT description
    }

    sensor_telemetry_logs {
        BIGSERIAL telemetry_id PK "Primary Key"
        VARCHAR sensor_id FK "Foreign Key"
        TIMESTAMPTZ timestamp
        NUMERIC altitude_meters
        NUMERIC battery_bandwidth_pct
        DOUBLE_PRECISION latitude
        DOUBLE_PRECISION longitude
        BOOLEAN network_connected "Edge AI Offline / Online"
    }

    threat_detections {
        BIGSERIAL detection_id PK "Primary Key"
        VARCHAR sensor_id FK "Foreign Key"
        INT category_id FK "Foreign Key"
        TIMESTAMPTZ detected_at
        NUMERIC confidence_score
        DOUBLE_PRECISION latitude
        DOUBLE_PRECISION longitude
        JSONB bounding_box_json
        VARCHAR edge_model_version
    }

    targeting_effector_pairings {
        BIGSERIAL pairing_id PK "Primary Key"
        BIGINT detection_id FK "Foreign Key"
        VARCHAR effector_type "ARTILLERY / DRONE / JAMMING"
        TIMESTAMPTZ paired_at
        INT kill_chain_latency_ms
        DOUBLE_PRECISION target_latitude
        DOUBLE_PRECISION target_longitude
        VARCHAR pairing_status "RECOMMENDED / EXECUTED"
    }

    operator_decision_logs {
        BIGSERIAL decision_id PK "Primary Key"
        BIGINT pairing_id FK "Foreign Key"
        VARCHAR operator_id
        VARCHAR decision_type "AUTHORIZE / OVERRIDE / REJECT"
        TIMESTAMPTZ decided_at
        TEXT operational_context
        DOUBLE_PRECISION command_post_latitude
        DOUBLE_PRECISION command_post_longitude
    }

    mission_deployments {
        BIGSERIAL mission_id PK "Primary Key"
        VARCHAR mission_code "Unique"
        JSONB area_of_responsibility_geojson "GeoJSON Polygon Boundary"
        TIMESTAMPTZ start_time
        TIMESTAMPTZ end_time
        VARCHAR mission_status "ONGOING / COMPLETED"
        VARCHAR priority
    }
```

Master tables are

- `edge_sensors`
- `target_categories`

While the rest are transactional tables:

- `mission_deployments`
- `sensor_telemetry_logs`
- `threat_detections`
- `targeting_effector_pairings`
- `operator_decision_logs`

## How to Replicate

1. Clone this repository:

```sh
git clone https://github.com/orizynpx/bi-palantir-db.git
```

2. Run the Docker Compose command (it initializes and seeds the Postgre DB):

```sh
docker compose up -d
```

3. Enter the database shell to write SQL statements:

```sh
docker exec -it palantir_db psql -U admin -d palantir_ops
```

4. Use this SQL statement to verify the number of rows for each of the transactional tables:

```sh
SELECT 'mission_deployments' AS table_name, COUNT(*) AS row_count FROM mission_deployments
UNION ALL
SELECT 'sensor_telemetry_logs', COUNT(*) FROM sensor_telemetry_logs
UNION ALL
SELECT 'threat_detections', COUNT(*) FROM threat_detections
UNION ALL
SELECT 'targeting_effector_pairings', COUNT(*) FROM targeting_effector_pairings
UNION ALL
SELECT 'operator_decision_logs', COUNT(*) FROM operator_decision_logs;
```

## Credits

- **Arya Arrozza Ridho Syaputra (2410817210010):** Database design
- **Noor Muhammad Akmal Sulaiman (2410817210007):** PostgreSQL implementation on Docker container
