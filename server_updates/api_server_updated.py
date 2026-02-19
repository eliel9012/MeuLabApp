#!/usr/bin/env python3
"""API HTTP para expor dados ao app SwiftUI - MeuLab.fun."""
import logging
import os
from pathlib import Path

from aiohttp import web
from dotenv import load_dotenv

from api.acars_api import (
    acars_alerts_recent,
    acars_history,
    acars_hourly,
    acars_messages,
    acars_search,
    acars_summary,
)
from api.adsb_api import (
    adsb_aircraft,
    adsb_alerts_recent,
    adsb_history,
    adsb_summary,
)
from api.dashboard_api import dashboard
from api.docker_api import docker_logs, docker_status, docker_version
from api.health_api import health
from api.metrics import metrics_middleware
from api.metrics_api import api_metrics
from api.notifications_api import (
    get_notifications,
    notifications_ack,
    notifications_feed,
    register_device,
    unregister_device,
)
from api.radio_api import radio_now_playing
from api.satdump_api import (
    satdump_last_images,
    satdump_list_passes,
    satdump_pass_images,
    satdump_pass_images_lossless,
    satdump_serve_image,
    satdump_serve_image_legend,
    satdump_serve_image_light,
    satdump_serve_image_lossless,
    satdump_status,
)
from api.system_api import (
    system_network,
    system_partitions,
    system_processes,
    system_status,
)
from api.systemd_api import systemd_status
from api.weather_api import weather_current

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("api_server")

# Carrega .env do projeto, se existir.
load_dotenv(Path(__file__).parent / ".env")


def create_app() -> web.Application:
    app = web.Application(middlewares=[metrics_middleware])
    app.router.add_get("/health", health)
    # ADS-B
    app.router.add_get("/api/adsb/summary", adsb_summary)
    app.router.add_get("/api/adsb/aircraft", adsb_aircraft)
    app.router.add_get("/api/adsb/history", adsb_history)
    app.router.add_get("/api/adsb/alerts", adsb_alerts_recent)
    # ACARS
    app.router.add_get("/api/acars/summary", acars_summary)
    app.router.add_get("/api/acars/messages", acars_messages)
    app.router.add_get("/api/acars/search", acars_search)
    app.router.add_get("/api/acars/hourly", acars_hourly)
    app.router.add_get("/api/acars/history", acars_history)
    app.router.add_get("/api/acars/alerts", acars_alerts_recent)
    # Satdump
    app.router.add_get("/api/satdump/passes", satdump_list_passes)
    app.router.add_get("/api/satdump/last/images", satdump_last_images)
    app.router.add_get("/api/satdump/pass/images", satdump_pass_images)
    app.router.add_get("/api/satdump/image", satdump_serve_image)
    app.router.add_get("/api/satdump/image_light", satdump_serve_image_light)
    app.router.add_get("/api/satdump/image_lossless", satdump_serve_image_lossless)
    app.router.add_get("/api/satdump/image_legend", satdump_serve_image_legend)
    app.router.add_get("/api/satdump/pass/images_lossless", satdump_pass_images_lossless)
    app.router.add_get("/api/satdump/status", satdump_status)
    # Radio
    app.router.add_get("/api/radio/now-playing", radio_now_playing)
    # System
    app.router.add_get("/api/system/status", system_status)
    app.router.add_get("/api/system/processes", system_processes)
    app.router.add_get("/api/system/partitions", system_partitions)
    app.router.add_get("/api/system/network", system_network)
    # Docker
    app.router.add_get("/api/docker/version", docker_version)
    app.router.add_get("/api/docker/status", docker_status)
    app.router.add_get("/api/docker/logs", docker_logs)
    # Systemd
    app.router.add_get("/api/systemd/status", systemd_status)
    # Weather
    app.router.add_get("/api/weather/current", weather_current)
    # Notifications
    app.router.add_post("/api/notifications/register", register_device)
    app.router.add_post("/api/notifications/unregister", unregister_device)
    app.router.add_get("/api/notifications", get_notifications)
    app.router.add_get("/api/notifications/feed", notifications_feed)
    app.router.add_post("/api/notifications/ack", notifications_ack)
    # Aliases for legacy app paths
    app.router.add_post("/notifications/register", register_device)
    app.router.add_post("/notifications/unregister", unregister_device)
    app.router.add_get("/notifications", get_notifications)
    app.router.add_get("/notifications/feed", notifications_feed)
    app.router.add_post("/notifications/ack", notifications_ack)
    # Dashboard
    app.router.add_get("/api/dashboard", dashboard)
    # API metrics
    app.router.add_get("/api/metrics", api_metrics)
    return app


def main() -> None:
    host = os.getenv("API_HOST", "0.0.0.0")
    port = int(os.getenv("API_PORT", "8090"))
    logger.info("Iniciando API em %s:%s", host, port)
    web.run_app(create_app(), host=host, port=port)


if __name__ == "__main__":
    main()
