"""
Satdump filter endpoints:
  GET /api/satdump/passes_by_satellite
  GET /api/satdump/passes_by_date

These functions should be added to the EXISTING satdump_api.py on the server
and their routes registered in api_server.py.
"""
import datetime as dt
import logging
from pathlib import Path

from aiohttp import web

from .helpers import TTLCache, json_error, parse_int, require_bearer_token

logger = logging.getLogger("api_server")
_cache = TTLCache()
_BASE_PATH = Path("/home/pi/satdump_out/meteor_autotrack")


def _collect_all_passes():
    """Collect all passes (shared logic)."""
    passes = []
    if not _BASE_PATH.exists():
        return passes

    all_folders = sorted(_BASE_PATH.iterdir(), reverse=True)
    for folder in all_folders:
        if not folder.is_dir():
            continue
        image_folders = [f for f in folder.iterdir() if f.is_dir()]
        for img_folder in image_folders:
            images = list(img_folder.glob("*.png"))
            if images:
                size_bytes = sum(
                    f.stat().st_size for f in folder.rglob("*") if f.is_file()
                )
                size_mb = size_bytes / 1_000_000
                if size_mb >= 15:
                    quality_stars = 5
                elif size_mb >= 10:
                    quality_stars = 4
                elif size_mb >= 5:
                    quality_stars = 3
                elif size_mb >= 1:
                    quality_stars = 2
                else:
                    quality_stars = 1

                passes.append({
                    "name": folder.name,
                    "image_folder": img_folder.name,
                    "image_count": len(images),
                    "size_mb": round(size_mb, 1),
                    "quality_stars": quality_stars,
                })
                break
    return passes


async def satdump_passes_by_satellite(request: web.Request) -> web.Response:
    """GET /api/satdump/passes_by_satellite?satellite=METEOR"""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    satellite = request.query.get("satellite", "").upper()
    if not satellite:
        return json_error("Missing 'satellite' parameter", 400)

    page = parse_int(request.query.get("page", "1"), 1, 1, 1000)
    limit = parse_int(request.query.get("limit", "50"), 50, 1, 200)

    cache_key = f"satdump_by_sat:{satellite}:{page}:{limit}"
    cached = _cache.get(cache_key)
    if cached:
        return web.json_response(cached)

    try:
        all_passes = _collect_all_passes()
        filtered = [p for p in all_passes if satellite in p["name"].upper()]

        total_count = len(filtered)
        start_idx = (page - 1) * limit
        paginated = filtered[start_idx : start_idx + limit]
        total_pages = max(1, (total_count + limit - 1) // limit)

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "satellite": satellite,
            "count": len(paginated),
            "total_count": total_count,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
            "passes": paginated,
        }
        _cache.set(cache_key, payload, ttl=30.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Error filtering passes by satellite")
        return json_error(str(e), 500)


async def satdump_passes_by_date(request: web.Request) -> web.Response:
    """GET /api/satdump/passes_by_date?date_from=2025-01-01&date_to=2025-01-31"""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    date_from_str = request.query.get("date_from")
    date_to_str = request.query.get("date_to")

    if not date_from_str or not date_to_str:
        return json_error("Missing 'date_from' or 'date_to' parameter", 400)

    try:
        date_from = dt.datetime.strptime(date_from_str, "%Y-%m-%d").date()
        date_to = dt.datetime.strptime(date_to_str, "%Y-%m-%d").date()
    except ValueError:
        return json_error("Invalid date format. Use YYYY-MM-DD.", 400)

    page = parse_int(request.query.get("page", "1"), 1, 1, 1000)
    limit = parse_int(request.query.get("limit", "50"), 50, 1, 200)

    cache_key = f"satdump_by_date:{date_from}:{date_to}:{page}:{limit}"
    cached = _cache.get(cache_key)
    if cached:
        return web.json_response(cached)

    try:
        all_passes = _collect_all_passes()
        filtered = []
        for p in all_passes:
            # Folder names contain dates like "2025-03-08_..." or similar patterns
            # Try to extract date from the folder name
            folder_name = p["name"]
            try:
                # Common pattern: YYYY-MM-DD at the start of folder name
                folder_date = dt.datetime.strptime(folder_name[:10], "%Y-%m-%d").date()
                if date_from <= folder_date <= date_to:
                    filtered.append(p)
            except (ValueError, IndexError):
                # If date can't be parsed, skip this pass for date filtering
                continue

        total_count = len(filtered)
        start_idx = (page - 1) * limit
        paginated = filtered[start_idx : start_idx + limit]
        total_pages = max(1, (total_count + limit - 1) // limit)

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "date_from": date_from_str,
            "date_to": date_to_str,
            "count": len(paginated),
            "total_count": total_count,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
            "passes": paginated,
        }
        _cache.set(cache_key, payload, ttl=30.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Error filtering passes by date")
        return json_error(str(e), 500)
