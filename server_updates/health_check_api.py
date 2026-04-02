import asyncio
import time
import psutil
from aiohttp import web
from .helpers import TTLCache, require_bearer_token

_cache = TTLCache()
_reports_store: list = []
_MAX_REPORTS = 100


async def health_check(request: web.Request) -> web.Response:
    """POST /api/health/check - Run a health check and return report."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error
    report = await asyncio.to_thread(_run_health_check)
    _reports_store.insert(0, report)
    if len(_reports_store) > _MAX_REPORTS:
        _reports_store.pop()
    return web.json_response(report)


async def health_reports(request: web.Request) -> web.Response:
    """GET /api/health/reports - Return recent health check reports."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error
    limit = min(int(request.query.get("limit", "10")), _MAX_REPORTS)
    return web.json_response(_reports_store[:limit])


def _run_health_check() -> dict:
    checks = []
    overall = "healthy"

    # CPU
    cpu = psutil.cpu_percent(interval=0.5)
    checks.append({
        "name": "cpu",
        "status": "warning" if cpu > 90 else "healthy",
        "value": f"{cpu}%",
        "message": f"CPU at {cpu}%",
    })

    # Memory
    mem = psutil.virtual_memory()
    mem_status = "warning" if mem.percent > 85 else "healthy"
    checks.append({
        "name": "memory",
        "status": mem_status,
        "value": f"{mem.percent}%",
        "message": f"Memory {mem.percent}% used",
    })

    # Disk
    disk = psutil.disk_usage("/")
    disk_status = "critical" if disk.percent > 95 else ("warning" if disk.percent > 85 else "healthy")
    checks.append({
        "name": "disk",
        "status": disk_status,
        "value": f"{disk.percent}%",
        "message": f"Disk {disk.percent}% used",
    })

    # Temperature
    try:
        temps = psutil.sensors_temperatures()
        if "cpu_thermal" in temps:
            temp = temps["cpu_thermal"][0].current
            t_status = "critical" if temp > 80 else ("warning" if temp > 70 else "healthy")
            checks.append({
                "name": "temperature",
                "status": t_status,
                "value": f"{temp:.1f}C",
                "message": f"CPU temp {temp:.1f}C",
            })
    except Exception:
        pass

    # Determine overall
    for c in checks:
        if c["status"] == "critical":
            overall = "critical"
            break
        if c["status"] == "warning":
            overall = "warning"

    return {
        "timestamp": time.time(),
        "overall_status": overall,
        "checks": checks,
        "uptime_seconds": time.time() - psutil.boot_time(),
    }
