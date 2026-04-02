import csv
import io
import json
from aiohttp import web
from .helpers import require_bearer_token


async def export_data(request: web.Request) -> web.Response:
    """GET /api/export - Export data in JSON or CSV format."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    data_type = request.query.get("data_type", "system")
    fmt = request.query.get("format", "json")
    date_from = request.query.get("date_from")
    date_to = request.query.get("date_to")

    payload = {
        "data_type": data_type,
        "format": fmt,
        "date_from": date_from,
        "date_to": date_to,
        "records": [],
        "message": "Export endpoint ready. Data collection in progress.",
    }

    if fmt == "csv":
        output = io.StringIO()
        writer = csv.DictWriter(
            output,
            fieldnames=["data_type", "format", "date_from", "date_to", "message"],
        )
        writer.writeheader()
        writer.writerow({
            "data_type": data_type,
            "format": fmt,
            "date_from": date_from or "",
            "date_to": date_to or "",
            "message": payload["message"],
        })
        return web.Response(text=output.getvalue(), content_type="text/csv")

    return web.json_response(payload)
