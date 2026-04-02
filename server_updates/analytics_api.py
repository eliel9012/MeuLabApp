"""Analytics API endpoints — real data from system, ADS-B history, and satellites."""

import asyncio
import json
import logging
import os
import sqlite3
import subprocess
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from aiohttp import web

logger = logging.getLogger("analytics")

DATA_DIR = Path(os.getenv("DATA_DIR", "/home/pi/bot2/data"))
ADSB_HISTORY_FILE = Path(os.getenv("ADSB_HISTORY_FILE", "/home/pi/adsb_history.json"))
METRICS_DB = DATA_DIR / "system_metrics.db"
TUYA_HISTORY = DATA_DIR / "tuya_temperature_history.json"
SATDUMP_BASE = DATA_DIR / "satdump_out" / "meteor_autotrack"

# ---------------------------------------------------------------------------
# SQLite metrics collector
# ---------------------------------------------------------------------------

_COLLECT_INTERVAL = 60  # seconds


def _init_db(db_path: Path) -> None:
    conn = sqlite3.connect(str(db_path))
    conn.execute("""
        CREATE TABLE IF NOT EXISTS system_metrics (
            ts       TEXT PRIMARY KEY,
            cpu_pct  REAL,
            load1    REAL,
            load5    REAL,
            load15   REAL,
            mem_used_mb   INTEGER,
            mem_avail_mb  INTEGER,
            mem_pct  REAL,
            disk_used_gb  REAL,
            disk_avail_gb REAL,
            disk_pct REAL,
            temp_c   REAL
        )
    """)
    conn.execute("""
        CREATE INDEX IF NOT EXISTS idx_metrics_ts ON system_metrics(ts)
    """)
    conn.commit()
    conn.close()


def _collect_snapshot() -> Dict[str, Any]:
    """Collect one system metrics snapshot using /proc and vcgencmd."""
    snap: Dict[str, Any] = {"ts": datetime.now().strftime("%Y-%m-%dT%H:%M:%S")}

    # CPU from /proc/loadavg
    try:
        with open("/proc/loadavg") as f:
            parts = f.read().split()
        load1, load5, load15 = float(parts[0]), float(parts[1]), float(parts[2])
        cores = os.cpu_count() or 1
        snap["cpu_pct"] = round(min((load1 / cores) * 100, 100), 1)
        snap["load1"] = load1
        snap["load5"] = load5
        snap["load15"] = load15
    except Exception:
        snap["cpu_pct"] = 0
        snap["load1"] = snap["load5"] = snap["load15"] = 0

    # Memory from /proc/meminfo
    try:
        info = {}
        with open("/proc/meminfo") as f:
            for line in f:
                k, v = line.split(":", 1)
                info[k.strip()] = int(v.strip().split()[0])  # kB
        total_kb = info.get("MemTotal", 1)
        avail_kb = info.get("MemAvailable", 0)
        used_kb = total_kb - avail_kb
        snap["mem_used_mb"] = used_kb // 1024
        snap["mem_avail_mb"] = avail_kb // 1024
        snap["mem_pct"] = round((used_kb / total_kb) * 100, 1)
    except Exception:
        snap["mem_used_mb"] = snap["mem_avail_mb"] = 0
        snap["mem_pct"] = 0

    # Disk from /proc/mounts + statvfs
    try:
        st = os.statvfs("/")
        total = st.f_frsize * st.f_blocks
        avail = st.f_frsize * st.f_bavail
        used = total - avail
        snap["disk_used_gb"] = round(used / (1024 ** 3), 1)
        snap["disk_avail_gb"] = round(avail / (1024 ** 3), 1)
        snap["disk_pct"] = round((used / total) * 100, 1) if total else 0
    except Exception:
        snap["disk_used_gb"] = snap["disk_avail_gb"] = 0
        snap["disk_pct"] = 0

    # Temperature from vcgencmd
    try:
        out = subprocess.check_output(["vcgencmd", "measure_temp"], text=True, timeout=2).strip()
        snap["temp_c"] = float(out.replace("temp=", "").replace("'C", ""))
    except Exception:
        snap["temp_c"] = 0

    return snap


def _store_snapshot(snap: Dict[str, Any]) -> None:
    try:
        conn = sqlite3.connect(str(METRICS_DB))
        conn.execute(
            """INSERT OR REPLACE INTO system_metrics
               (ts, cpu_pct, load1, load5, load15, mem_used_mb, mem_avail_mb,
                mem_pct, disk_used_gb, disk_avail_gb, disk_pct, temp_c)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                snap["ts"], snap["cpu_pct"], snap["load1"], snap["load5"], snap["load15"],
                snap["mem_used_mb"], snap["mem_avail_mb"], snap["mem_pct"],
                snap["disk_used_gb"], snap["disk_avail_gb"], snap["disk_pct"],
                snap["temp_c"],
            ),
        )
        conn.commit()
        conn.close()
    except Exception as e:
        logger.warning("metrics store error: %s", e)


def _prune_old(max_age_days: int = 8) -> None:
    """Remove metrics older than max_age_days."""
    try:
        cutoff = (datetime.now() - timedelta(days=max_age_days)).strftime("%Y-%m-%dT%H:%M:%S")
        conn = sqlite3.connect(str(METRICS_DB))
        conn.execute("DELETE FROM system_metrics WHERE ts < ?", (cutoff,))
        conn.commit()
        conn.close()
    except Exception:
        pass


async def _collector_loop() -> None:
    """Background loop that collects system metrics every minute."""
    _init_db(METRICS_DB)
    prune_counter = 0
    while True:
        try:
            snap = await asyncio.to_thread(_collect_snapshot)
            await asyncio.to_thread(_store_snapshot, snap)
            prune_counter += 1
            if prune_counter >= 60:  # prune every ~60 min
                await asyncio.to_thread(_prune_old)
                prune_counter = 0
        except Exception as e:
            logger.warning("collector error: %s", e)
        await asyncio.sleep(_COLLECT_INTERVAL)


def start_collector(app: web.Application) -> None:
    """Call from api_server setup to start the background collector."""
    async def _on_startup(app: web.Application) -> None:
        app["_metrics_collector"] = asyncio.create_task(_collector_loop())
    async def _on_cleanup(app: web.Application) -> None:
        task = app.get("_metrics_collector")
        if task:
            task.cancel()
    app.on_startup.append(_on_startup)
    app.on_cleanup.append(_on_cleanup)


# ---------------------------------------------------------------------------
# Period helpers
# ---------------------------------------------------------------------------

_PERIOD_MINUTES = {
    "5m": 5,
    "1h": 60,
    "6h": 360,
    "24h": 1440,
    "7d": 10080,
}


def _period_to_minutes(period: str) -> int:
    return _PERIOD_MINUTES.get(period, 1440)


# ---------------------------------------------------------------------------
# System analytics endpoint
# ---------------------------------------------------------------------------

def _query_metrics(period: str, interval: str) -> List[Dict[str, Any]]:
    """Return metric rows from SQLite for the given period."""
    minutes = _period_to_minutes(period)
    cutoff = (datetime.now() - timedelta(minutes=minutes)).strftime("%Y-%m-%dT%H:%M:%S")

    # Determine grouping bucket size
    interval_map = {"1m": 1, "5m": 5, "15m": 15, "1h": 60}
    bucket_min = interval_map.get(interval, 5)

    conn = sqlite3.connect(str(METRICS_DB))
    conn.row_factory = sqlite3.Row
    rows = conn.execute(
        "SELECT * FROM system_metrics WHERE ts >= ? ORDER BY ts",
        (cutoff,),
    ).fetchall()
    conn.close()

    if not rows:
        return []

    # Group into buckets and average
    buckets: Dict[str, List[Dict]] = {}
    for r in rows:
        dt_obj = datetime.strptime(r["ts"], "%Y-%m-%dT%H:%M:%S")
        # Round down to bucket
        minute_of_day = dt_obj.hour * 60 + dt_obj.minute
        bucket_start = (minute_of_day // bucket_min) * bucket_min
        bucket_key = dt_obj.strftime("%Y-%m-%dT") + f"{bucket_start // 60:02d}:{bucket_start % 60:02d}:00"
        if bucket_key not in buckets:
            buckets[bucket_key] = []
        buckets[bucket_key].append(dict(r))

    result = []
    for ts_key in sorted(buckets.keys()):
        group = buckets[ts_key]
        n = len(group)
        result.append({
            "timestamp": ts_key,
            "usage": round(sum(r["cpu_pct"] for r in group) / n, 1),
            "load1min": round(sum(r["load1"] for r in group) / n, 2),
            "load5min": round(sum(r["load5"] for r in group) / n, 2),
            "load15min": round(sum(r["load15"] for r in group) / n, 2),
            "usedMb": round(sum(r["mem_used_mb"] for r in group) / n),
            "availableMb": round(sum(r["mem_avail_mb"] for r in group) / n),
            "usedPercent_mem": round(sum(r["mem_pct"] for r in group) / n, 1),
            "usedGb": round(sum(r["disk_used_gb"] for r in group) / n, 1),
            "availableGb": round(sum(r["disk_avail_gb"] for r in group) / n, 1),
            "usedPercent_disk": round(sum(r["disk_pct"] for r in group) / n, 1),
            "temperature": round(sum(r["temp_c"] for r in group) / n, 1),
        })
    return result


def _uptime_info() -> Dict[str, Any]:
    try:
        with open("/proc/uptime") as f:
            secs = int(float(f.read().split()[0]))
        return {"current": secs, "average": secs, "reboots": 0}
    except Exception:
        return {"current": 0, "average": 0, "reboots": 0}


async def system_analytics(request: web.Request) -> web.Response:
    """Real system analytics from the metrics collector DB."""
    period = request.query.get("period", "24h")
    interval = request.query.get("interval", "5m")

    points = await asyncio.to_thread(_query_metrics, period, interval)

    # If no historical data yet, return a single live snapshot
    if not points:
        snap = await asyncio.to_thread(_collect_snapshot)
        points = [{
            "timestamp": snap["ts"],
            "usage": snap["cpu_pct"],
            "load1min": snap["load1"],
            "load5min": snap["load5"],
            "load15min": snap["load15"],
            "usedMb": snap["mem_used_mb"],
            "availableMb": snap["mem_avail_mb"],
            "usedPercent_mem": snap["mem_pct"],
            "usedGb": snap["disk_used_gb"],
            "availableGb": snap["disk_avail_gb"],
            "usedPercent_disk": snap["disk_pct"],
            "temperature": snap["temp_c"],
        }]

    # Build separate metric arrays for the iOS app
    cpu_data = [{"timestamp": p["timestamp"], "usage": p["usage"],
                 "load1min": p["load1min"], "load5min": p["load5min"],
                 "load15min": p["load15min"]} for p in points]
    mem_data = [{"timestamp": p["timestamp"], "usedMb": p["usedMb"],
                 "availableMb": p["availableMb"],
                 "usedPercent": p["usedPercent_mem"]} for p in points]
    disk_data = [{"timestamp": p["timestamp"], "usedGb": p["usedGb"],
                  "availableGb": p["availableGb"],
                  "usedPercent": p["usedPercent_disk"]} for p in points]
    temp_data = [{"timestamp": p["timestamp"],
                  "temperature": p["temperature"]} for p in points]

    def _avg(lst, key):
        vals = [d[key] for d in lst if d.get(key) is not None]
        return round(sum(vals) / len(vals), 1) if vals else 0

    def _peak(lst, key):
        vals = [d[key] for d in lst if d.get(key) is not None]
        return round(max(vals), 1) if vals else 0

    def _min_val(lst, key):
        vals = [d[key] for d in lst if d.get(key) is not None]
        return round(min(vals), 1) if vals else 0

    data = {
        "period": period,
        "interval": interval,
        "cpu": {
            "dataPoints": cpu_data,
            "average": _avg(cpu_data, "usage"),
            "peak": _peak(cpu_data, "usage"),
            "minimum": _min_val(cpu_data, "usage"),
        },
        "memory": {
            "dataPoints": mem_data,
            "averageUsage": _avg(mem_data, "usedPercent"),
            "peakUsage": _peak(mem_data, "usedPercent"),
            "minimumAvailable": min((d["availableMb"] for d in mem_data), default=0),
        },
        "disk": {
            "dataPoints": disk_data,
            "averageUsage": _avg(disk_data, "usedPercent"),
            "peakUsage": _peak(disk_data, "usedPercent"),
            "growthRate": None,
        },
        "temperature": {
            "dataPoints": temp_data,
            "average": _avg(temp_data, "temperature"),
            "peak": _peak(temp_data, "temperature"),
            "minimum": _min_val(temp_data, "temperature"),
        },
        "uptime": _uptime_info(),
    }
    return web.json_response(data)


# ---------------------------------------------------------------------------
# ADS-B analytics endpoint — uses real /home/pi/adsb_history.json
# ---------------------------------------------------------------------------

def _load_adsb_history() -> Optional[Dict]:
    try:
        with open(ADSB_HISTORY_FILE) as f:
            return json.load(f)
    except Exception:
        return None


async def adsb_analytics(request: web.Request) -> web.Response:
    """Real ADS-B analytics from adsb_history.json."""
    period = request.query.get("period", "24h")
    minutes = _period_to_minutes(period)
    days_needed = max(1, minutes // 1440)

    history = await asyncio.to_thread(_load_adsb_history)
    if not history:
        return web.json_response({"error": "adsb_history not available", "period": period}, status=503)

    daily_peaks = history.get("daily_peaks", {})
    sorted_days = sorted(daily_peaks.keys())
    selected_days = sorted_days[-days_needed:] if len(sorted_days) >= days_needed else sorted_days

    # Build hourly stats across the selected days
    hourly_totals: Dict[int, List[int]] = {h: [] for h in range(24)}
    for day in selected_days:
        dp = daily_peaks.get(day, {})
        for hour_str, count in dp.items():
            try:
                h = int(hour_str)
                hourly_totals[h].append(count)
            except (ValueError, TypeError):
                pass

    hourly_stats = []
    total_flights = 0
    for hour in range(24):
        vals = hourly_totals[hour]
        avg_count = round(sum(vals) / len(vals)) if vals else 0
        total_flights += avg_count
        hourly_stats.append({
            "hour": hour,
            "flightCount": avg_count,
            "averageAltitude": None,
            "averageSpeed": None,
        })

    # Daily stats
    daily_stats = []
    for day in selected_days:
        dp = daily_peaks.get(day, {})
        day_total = sum(dp.values())
        unique_aircraft = len([v for v in dp.values() if v > 0])
        peak_hour = max(dp, key=lambda k: dp[k], default="0")
        daily_stats.append({
            "date": day,
            "flightCount": day_total,
            "uniqueAircraft": unique_aircraft,
            "peakHour": int(peak_hour),
            "averageFlightDuration": 0.0,
        })

    # Top models from history
    models_seen = history.get("models_seen", {})
    sorted_models = sorted(models_seen.items(), key=lambda x: x[1], reverse=True)[:5]
    total_models = sum(models_seen.values()) or 1
    top_aircraft_types = [
        {"type": m, "count": c, "percentage": round(c / total_models * 100, 1)}
        for m, c in sorted_models
    ]

    # Top routes from history
    routes = history.get("routes", {})
    sorted_routes = sorted(routes.items(), key=lambda x: x[1], reverse=True)[:5]
    total_routes = sum(routes.values()) or 1
    top_routes = []
    for route_key, count in sorted_routes:
        parts = route_key.split("-", 1)
        origin = parts[0] if len(parts) > 0 else "?"
        dest = parts[1] if len(parts) > 1 else "?"
        top_routes.append({
            "origin": origin,
            "destination": dest,
            "count": count,
            "percentage": round(count / total_routes * 100, 1),
        })

    # Records
    records = history.get("records", {})

    data = {
        "period": period,
        "totalFlights": total_flights,
        "uniqueAircraft": records.get("peak_unique", 0),
        "hourlyStats": hourly_stats,
        "dailyStats": daily_stats,
        "topAircraftTypes": top_aircraft_types,
        "topRoutes": top_routes,
        "altitudeDistribution": [],
        "records": records,
    }
    return web.json_response(data)


# ---------------------------------------------------------------------------
# Satellite analytics endpoint — uses real satdump output directories
# ---------------------------------------------------------------------------

def _scan_satdump_passes(period_minutes: int) -> Dict[str, Any]:
    """Scan satdump output directories for real pass data."""
    cutoff = datetime.now() - timedelta(minutes=period_minutes)
    passes: List[Dict[str, Any]] = []

    if not SATDUMP_BASE.is_dir():
        return {"total": 0, "passes": []}

    for folder in sorted(SATDUMP_BASE.iterdir()):
        if not folder.is_dir():
            continue
        try:
            # Folder names are timestamps like "2026-03-08_123456"
            name = folder.name
            ts_str = name.replace("_", "T").replace("T", " ", 1)
            # Try common patterns
            for fmt in ("%Y-%m-%d %H%M%S", "%Y-%m-%d_%H%M%S", "%Y%m%d_%H%M%S"):
                try:
                    ts = datetime.strptime(name, fmt.split(" ")[0] if " " in fmt else fmt)
                    break
                except ValueError:
                    ts = None
            if ts is None:
                # Try to get mtime
                ts = datetime.fromtimestamp(folder.stat().st_mtime)

            if ts < cutoff:
                continue

            images = list(folder.glob("*.png")) + list(folder.glob("*.jpg"))
            total_size = sum(f.stat().st_size for f in images) if images else 0
            success = total_size > 500_000  # > 500KB means good capture

            passes.append({
                "timestamp": ts.strftime("%Y-%m-%dT%H:%M:%S"),
                "satellite": "Meteor M2-x",
                "duration": 0.0,
                "maxElevation": 0.0,
                "success": success,
                "imageCount": len(images),
                "totalSizeMb": round(total_size / (1024 * 1024), 1),
            })
        except Exception:
            continue

    return {"total": len(passes), "passes": sorted(passes, key=lambda p: p["timestamp"], reverse=True)}


async def satellite_analytics(request: web.Request) -> web.Response:
    """Real satellite analytics from satdump output directories."""
    period = request.query.get("period", "7d")
    minutes = _period_to_minutes(period)

    result = await asyncio.to_thread(_scan_satdump_passes, minutes)
    passes = result["passes"]

    total_passes = len(passes)
    successful = sum(1 for p in passes if p["success"])
    failed = total_passes - successful

    # If no real data, return zeros (not mock)
    if total_passes == 0:
        data = {
            "period": period,
            "totalPasses": 0,
            "successfulPasses": 0,
            "failedPasses": 0,
            "averageDuration": 0,
            "passesPerDay": 0,
            "satelliteStats": [{
                "satellite": "Meteor M2-x",
                "passes": 0,
                "successRate": 0,
                "averageElevation": 0.0,
                "averageDuration": 0.0,
            }],
            "imageStats": {
                "totalImages": 0,
                "averageSize": 0,
                "totalSize": 0,
                "formats": [],
            },
            "passTimeline": [],
            "message": "Nenhuma passagem encontrada no período selecionado.",
        }
        return web.json_response(data)

    days_in_period = max(1, minutes / 1440)
    ppd = round(total_passes / days_in_period, 1)
    success_rate = round(successful / total_passes * 100, 1) if total_passes else 0
    total_images = sum(p["imageCount"] for p in passes if p["success"])
    total_size_mb = sum(p["totalSizeMb"] for p in passes if p["success"])

    data = {
        "period": period,
        "totalPasses": total_passes,
        "successfulPasses": successful,
        "failedPasses": failed,
        "averageDuration": 0.0,
        "passesPerDay": ppd,
        "satelliteStats": [{
            "satellite": "Meteor M2-x",
            "passes": total_passes,
            "successRate": success_rate,
            "averageElevation": 0.0,
            "averageDuration": 0.0,
        }],
        "imageStats": {
            "totalImages": total_images,
            "averageSize": round(total_size_mb / total_images, 1) if total_images else 0,
            "totalSize": round(total_size_mb / 1024, 2),
            "formats": [
                {"format": "PNG", "count": total_images, "percentage": 100.0},
            ],
        },
        "passTimeline": passes[:20],
    }
    return web.json_response(data)
