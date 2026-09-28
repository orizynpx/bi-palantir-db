import datetime
import os
import random
import sys
import faker
import numpy as np
import psycopg2
from psycopg2.extras import execute_values

# Setup configuration from environment variables
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "palantir_ops")
DB_USER = os.getenv("DB_USER", "admin")
DB_PASS = os.getenv("DB_PASSWORD", "password")

fake = faker.Faker()
np.random.seed(42)
random.seed(42)


def get_db_connection():
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
    )


def seed_database():
    conn = get_db_connection()
    cur = conn.cursor()
    print("Connected to database. Truncating existing operational tables...")

    # Clear old data
    cur.execute("""
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
    """)

    # --- 1. Populate Dimension Tables ---
    print("Seeding dimensions...")

    sensors = [
        (1, "S-1", "Radar-Alpha", "SAT", "ACTIVE", True, "2026-01-01", None),
        (2, "S-2", "Drone-Eye-1", "DRONE", "ACTIVE", True, "2026-01-01", None),
        (3, "S-3", "Titan-Scan-A", "TITAN", "OFFLINE", True, "2026-01-01", None),
        (4, "S-4", "Sat-Vanguard", "SAT", "ACTIVE", True, "2026-01-01", None),
        (5, "S-5", "Drone-Eye-2", "DRONE", "ACTIVE", True, "2026-01-01", None),
    ]
    execute_values(
        cur,
        """
        INSERT INTO dim_sensor (sensor_key, sensor_id, sensor_name, sensor_type, status, is_current, valid_from, valid_to) 
        VALUES %s
    """,
        sensors,
    )

    missions = []
    for i in range(1, 51):
        prefix = random.choice(["M-", "OP-", "RECON-", "PATROL-", "TASK-"])
        missions.append((
            i,
            1000 + i,
            f"{prefix}{i:04d}",
            random.choice([
                "ONGOING",
                "COMPLETED",
                "ABORTED",
                "PLANNED",
                "SUSPENDED",
                "STANDBY",
            ]),
            random.choice(["LOW", "MEDIUM", "HIGH", "CRITICAL", "FLASH"]),
        ))
    execute_values(
        cur,
        """
        INSERT INTO dim_mission (mission_key, mission_id, mission_code, mission_status, priority) 
        VALUES %s
    """,
        missions,
    )

    categories = [
        (1, 101, "UAV", "HIGH"),
        (2, 102, "ARMORED_VEHICLE", "MEDIUM"),
        (3, 103, "NAVAL_VESSEL", "CRITICAL"),
        (4, 104, "INFANTRY", "LOW"),
        (5, 105, "MISSILE", "CRITICAL"),
    ]
    execute_values(
        cur,
        """
        INSERT INTO dim_target_category (category_key, category_id, category_name, threat_level) 
        VALUES %s
    """,
        categories,
    )

    effectors = [
        (1, "E-101", "Iron Dome Alpha", "MISSILE_INTERCEPT", 70.00, True),
        (2, "E-102", "Thunderbolt Howitzer", "ARTILLERY", 40.00, True),
        (3, "E-103", "Scorpion Jammer", "JAMMING", 15.00, True),
        (4, "E-104", "Helios Directed Energy", "DIRECTED_ENERGY", 10.00, True),
        (5, "E-105", "Reaper Strike UAV", "DRONE", 150.00, True),
        (6, "E-106", "Phalanx Sea-Gun", "NAVAL_GUN", 5.50, True),
        (7, "E-107", "Cyber Intercept Grid", "CYBER", 0.00, True),
    ]
    execute_values(
        cur,
        """
        INSERT INTO dim_effector (effector_key, effector_id, effector_name, effector_type, max_range_km, is_current) 
        VALUES %s
    """,
        effectors,
    )

    operators = []
    for i in range(1, 21):
        operators.append((
            i,
            f"OP-{i:03d}",
            f"Command Unit {random.choice(['Alpha', 'Bravo', 'Charlie', 'Delta', 'Echo'])}",
            random.choice(["CONFIDENTIAL", "SECRET", "TOP_SECRET"]),
        ))
    execute_values(
        cur,
        """
        INSERT INTO dim_operator (operator_key, operator_id, command_post_unit, clearance_level) 
        VALUES %s
    """,
        operators,
    )

    geographies = []
    for i in range(1, 101):
        # Realistic spatial cluster around Jakarta coordinates
        lat = float(np.round(np.random.normal(loc=-6.2088, scale=0.15), 6))
        lon = float(np.round(np.random.normal(loc=106.8456, scale=0.15), 6))
        geographies.append((
            i,
            f"876543{i:04d}",
            f"qqg{i:03d}",
            lat,
            lon,
            random.choice([
                "Greater Jakarta",
                "West Java Maritime",
                "Southern Coast",
                "Air Corridor Alpha",
                "Sector Delta",
            ]),
        ))
    execute_values(
        cur,
        """
        INSERT INTO dim_geography (geography_key, h3_index_r7, geohash_6, latitude, longitude, region_name) 
        VALUES %s
    """,
        geographies,
    )

    # Dates: August to September 2026
    start_date = datetime.date(2026, 8, 1)
    dates = []
    date_keys = []
    for d in range(61):
        dt = start_date + datetime.timedelta(days=d)
        dk = int(dt.strftime("%Y%m%d"))
        date_keys.append(dk)
        dates.append(
            (dk, dt, dt.year, (dt.month - 1) // 3 + 1, dt.month, dt.isoweekday())
        )
    execute_values(
        cur,
        """
        INSERT INTO dim_date (date_key, full_date, year, quarter, month, day_of_week) 
        VALUES %s
    """,
        dates,
    )

    # Time (30-min steps)
    times = []
    time_keys = []
    for h in range(24):
        for m in (0, 30):
            tk = h * 10000 + m * 100
            time_keys.append(tk)
            times.append((tk, h, m, 0))
    execute_values(
        cur,
        """
        INSERT INTO dim_time (time_key, hour, minute, second) 
        VALUES %s
    """,
        times,
    )

    # --- 2. Populate Fact Tables with Realistic Distributions ---
    print("Seeding fact tables with realistic statistical distribution...")

    sensor_keys = [s[0] for s in sensors]
    mission_keys = [m[0] for m in missions]
    category_keys = [c[0] for c in categories]
    effector_keys = [e[0] for e in effectors]
    operator_keys = [o[0] for o in operators]
    geography_keys = [g[0] for g in geographies]

    # Fact: Threat Detections
    # Using Beta distribution (a=5, b=2) so confidence leans realistically high (0.7-0.95)
    confidence_scores = np.random.beta(a=5, b=2, size=1200)
    # Using Poisson distribution for realistic threat count spikes
    detection_counts = np.random.poisson(lam=1.8, size=1200) + 1

    threat_detections = []
    for i in range(1, 1201):
        threat_detections.append((
            i,
            random.choice(sensor_keys),
            random.choice(mission_keys),
            random.choice(category_keys),
            random.choice(geography_keys),
            random.choice(date_keys),
            random.choice([
                "v1.0.0",
                "v1.1.2-beta",
                "v1.2.1",
                "v2.0.0",
                "v2.0.4-patch",
            ]),
            f"DET-{random.randint(100000, 999999)}",
            float(np.round(confidence_scores[i - 1], 4)),
            int(detection_counts[i - 1]),
        ))
    execute_values(
        cur,
        """
        INSERT INTO fact_threat_detections (
            detection_fact_id, sensor_key, mission_key, category_key, geography_key, 
            detected_date_key, edge_model_version, detection_id, confidence_score, detection_count
        ) VALUES %s
    """,
        threat_detections,
    )

    # Fact: Killchain Decisions
    # Using Log-Normal distribution for latency (mimics real network/human response times)
    kc_latencies = np.random.lognormal(mean=4.2, sigma=0.5, size=1200).astype(
        int
    )  # ~60-150ms average
    op_latencies = np.random.lognormal(mean=7.0, sigma=0.8, size=1200).astype(
        int
    )  # ~1000-3000ms human delay

    killchain_decisions = []
    for i in range(1, 1201):
        kc_lat = int(kc_latencies[i - 1])
        op_lat = int(op_latencies[i - 1])
        total_lat = kc_lat + op_lat

        ctx = f"Target verified | WX: {random.choice(['Clear', 'Rain', 'Fog'])} | Priority: P{random.randint(1, 4)}"
        authorized = 1 if random.random() > 0.20 else 0
        overridden = 1 if (authorized == 0 or random.random() > 0.85) else 0

        killchain_decisions.append((
            i,
            random.choice(sensor_keys),
            random.choice(mission_keys),
            random.choice(category_keys),
            random.choice(effector_keys),
            random.choice(operator_keys),
            random.choice(date_keys),
            random.choice([
                "RECOMMENDED",
                "EXECUTED",
                "CANCELLED",
                "FAILED",
                "PENDING",
            ]),
            random.choice([
                "AUTHORIZE",
                "OVERRIDE",
                "REJECT",
                "DELEGATE",
                "ABORT",
            ]),
            ctx,
            kc_lat,
            op_lat,
            total_lat,
            authorized,
            overridden,
        ))
    execute_values(
        cur,
        """
        INSERT INTO fact_killchain_decisions (
            decision_fact_id, sensor_key, mission_key, category_key, effector_key, operator_key, 
            decided_date_key, pairing_status, decision_type, operational_context, 
            kill_chain_latency_ms, operator_response_latency_ms, total_end_to_end_latency_ms, 
            is_authorized, is_overridden
        ) VALUES %s
    """,
        killchain_decisions,
    )

    # Fact: Sensor Telemetry
    telemetry = []
    for i in range(1, 1201):
        telemetry.append((
            i,
            random.choice(sensor_keys),
            random.choice(mission_keys),
            random.choice(geography_keys),
            random.choice(date_keys),
            random.choice(time_keys),
            float(np.round(random.uniform(100.0, 12000.0), 2)),
            float(np.round(random.uniform(20.0, 100.0), 2)),
            random.randint(600, 3600),
            random.randint(10, 300),
        ))
    execute_values(
        cur,
        """
        INSERT INTO fact_sensor_telemetry_snapshot (
            telemetry_snapshot_id, sensor_key, mission_key, geography_key, snapshot_date_key, 
            snapshot_time_key, avg_altitude_meters, min_battery_bandwidth_pct, 
            network_uptime_seconds, telemetry_event_count
        ) VALUES %s
    """,
        telemetry,
    )

    conn.commit()
    cur.close()
    conn.close()
    print("Database seeding completed successfully!")


if __name__ == "__main__":
    try:
        seed_database()
    except Exception as e:
        print(f"Error seeding database: {e}", file=sys.stderr)
        sys.exit(1)