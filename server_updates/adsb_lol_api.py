"""
ADS-B LOL endpoint stub:
  GET /api/adsb/adsb_lol

This function should be added to the EXISTING adsb_api.py on the server
and the route registered in api_server.py.
"""
import logging
import time

from aiohttp import web

from .helpers import TTLCache, require_bearer_token

logger = logging.getLogger("api_server")
_cache = TTLCache()


async def adsb_lol(request: web.Request) -> web.Response:
    """GET /api/adsb/adsb_lol - Fetch nearby aircraft from adsb.lol public API."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    cached = _cache.get("adsb_lol")
    if cached:
        return web.json_response(cached)

    import aiohttp

    try:
        # adsb.lol public API - aircraft near Franca/SP Brazil
        lat, lon = -20.51, -47.40
        radius = 250  # nautical miles
        url = f"https://api.adsb.lol/v2/lat/{lat}/lon/{lon}/dist/{radius}"

        async with aiohttp.ClientSession() as session:
            async with session.get(url, timeout=aiohttp.ClientTimeout(total=10)) as resp:
                if resp.status == 200:
                    data = await resp.json()
                    payload = {
                        "timestamp": time.time(),
                        "source": "adsb.lol",
                        "aircraft_count": len(data.get("ac", [])),
                        "aircraft": data.get("ac", [])[:100],
                    }
                    _cache.set("adsb_lol", payload, ttl=15.0)
                    return web.json_response(payload)
                else:
                    return web.json_response(
                        {"error": f"adsb.lol returned {resp.status}"}, status=502
                    )
    except Exception as e:
        logger.exception("Error fetching adsb.lol data")
        return web.json_response({"error": str(e)}, status=500)
