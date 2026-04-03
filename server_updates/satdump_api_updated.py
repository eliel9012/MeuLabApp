import asyncio
import datetime as dt
import hashlib
import logging
import os
import time
import urllib.parse
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, Optional

from aiohttp import web
from aiohttp.web import FileResponse

from modules import satdump

from .helpers import TTLCache, json_error, parse_int, require_bearer_token
from .metrics import METRICS

logger = logging.getLogger("api_server")
_cache = TTLCache()
_BASE_PATH = Path("/home/pi/satdump_out/meteor_autotrack")

# Configuracoes de localizacao para burn-in
STATION_LOCATION = "Franca/SP, Brasil"
STATION_COORDS = "-20.51, -47.40"


async def satdump_list_passes(request: web.Request) -> web.Response:
    """Lista TODOS os passes com imagens, com paginacao opcional."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    # Paginacao
    page = parse_int(request.query.get("page", "1"), 1, 1, 1000)
    limit = parse_int(request.query.get("limit", "50"), 50, 1, 200)

    cache_key = f"satdump_passes_all:{page}:{limit}"
    cached = _cache.get(cache_key)
    if cached:
        return web.json_response(cached)

    try:
        passes = []
        if _BASE_PATH.exists():
            all_folders = sorted(_BASE_PATH.iterdir(), reverse=True)

            for folder in all_folders:
                if folder.is_dir():
                    image_folders = [f for f in folder.iterdir() if f.is_dir()]
                    for img_folder in image_folders:
                        images = list(img_folder.glob("*.png"))
                        if images:
                            # Calcula tamanho da pasta
                            size_bytes = sum(
                                f.stat().st_size
                                for f in folder.rglob("*")
                                if f.is_file()
                            )
                            size_mb = size_bytes / 1_000_000

                            # Calcula qualidade (estrelas)
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

        total_count = len(passes)

        # Aplica paginacao
        start_idx = (page - 1) * limit
        end_idx = start_idx + limit
        paginated_passes = passes[start_idx:end_idx]

        total_pages = (total_count + limit - 1) // limit

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "count": len(paginated_passes),
            "total_count": total_count,
            "page": page,
            "limit": limit,
            "total_pages": total_pages,
            "passes": paginated_passes,
        }
        _cache.set(cache_key, payload, ttl=30.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Erro ao listar passes")
        return json_error(str(e), 500)


async def satdump_last_images(request: web.Request) -> web.Response:
    """Melhores imagens do ultimo passe."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    cached = _cache.get("satdump_last_images")
    if cached:
        return web.json_response(cached)

    try:
        if not _BASE_PATH.exists():
            return json_error("Base path not found", 404)

        folders = sorted([f for f in _BASE_PATH.iterdir() if f.is_dir()], reverse=True)

        last_pass = None
        for folder in folders:
            png_count = sum(1 for _ in folder.rglob("*.png"))
            if png_count > 0:
                last_pass = folder
                break

        if not last_pass:
            return json_error("No passes with images", 404)

        images = satdump.pick_best_images(last_pass, count=5)
        images_list = []

        for img_path, legend in images:
            img = Path(img_path)
            parts = img.parts
            meteor_idx = parts.index("meteor_autotrack")
            pass_name = parts[meteor_idx + 1]
            folder_name = parts[meteor_idx + 2]

            images_list.append({
                "name": img.name,
                "legend": legend,
                "pass_name": pass_name,
                "folder_name": folder_name,
                "image_light_url": (
                    "/api/satdump/image_light"
                    f"?pass={urllib.parse.quote(pass_name)}"
                    f"&folder={urllib.parse.quote(folder_name)}"
                    f"&image={urllib.parse.quote(img.name)}"
                ),
            })

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "pass_name": last_pass.name,
            "images": images_list
        }
        _cache.set("satdump_last_images", payload, ttl=10.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Erro imagens")
        return json_error(str(e), 500)


async def satdump_serve_image(request: web.Request) -> web.Response:
    """Serve imagem PNG."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    folder_name = request.query.get("folder", "")
    image_name = request.query.get("image", "")

    if not all([pass_name, folder_name, image_name]):
        return json_error("Missing params", 400)

    if ".." in pass_name or ".." in folder_name or ".." in image_name:
        return json_error("Invalid path", 400)

    try:
        img_path = _BASE_PATH / pass_name / folder_name / image_name

        if not img_path.exists():
            return json_error("Not found", 404)

        if not image_name.endswith('.png'):
            return json_error("PNG only", 400)

        return FileResponse(
            path=img_path,
            headers={
                "Content-Type": "image/png",
                "Cache-Control": "public, max-age=86400"
            }
        )
    except Exception as e:
        logger.exception("Erro serve image")
        return json_error(str(e), 500)


async def satdump_pass_images(request: web.Request) -> web.Response:
    """Lista imagens de um passe especifico."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    if not pass_name or ".." in pass_name:
        return json_error("pass_not_found", 404)

    cache_key = f"satdump_pass_images:{pass_name}"
    cached = _cache.get(cache_key)
    if cached:
        return web.json_response(cached)

    try:
        pass_path = _BASE_PATH / pass_name
        if not pass_path.exists() or not pass_path.is_dir():
            return json_error("pass_not_found", 404)

        images = satdump.pick_best_images(pass_path, count=5)
        images_list = []

        for img_path, legend in images:
            img = Path(img_path)
            parts = img.parts
            meteor_idx = parts.index("meteor_autotrack")
            pass_name_local = parts[meteor_idx + 1]
            folder_name = parts[meteor_idx + 2]

            images_list.append({
                "name": img.name,
                "legend": legend,
                "pass_name": pass_name_local,
                "folder_name": folder_name,
                "image_light_url": (
                    "https://app.meulab.fun/api/satdump/image_light"
                    f"?pass={urllib.parse.quote(pass_name_local)}"
                    f"&folder={urllib.parse.quote(folder_name)}"
                    f"&image={urllib.parse.quote(img.name)}"
                    f"&max=1280"
                ),
            })

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "pass_name": pass_name,
            "images": images_list,
        }
        _cache.set(cache_key, payload, ttl=10.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Erro pass images")
        return json_error(str(e), 500)


async def satdump_serve_image_light(request: web.Request) -> web.Response:
    """Serve imagem redimensionada com suporte a JPEG/WebP (mais leve)."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    folder_name = request.query.get("folder", "")
    image_name = request.query.get("image", "")
    max_px_raw = request.query.get("max", "1280")
    output_format = request.query.get("format", "jpeg").lower()
    quality_raw = request.query.get("quality", "85")

    if not all([pass_name, folder_name, image_name]):
        return json_error("Missing params", 400)

    if ".." in pass_name or ".." in folder_name or ".." in image_name:
        return json_error("Invalid path", 400)

    # Valida formato de saida
    if output_format not in ("jpeg", "webp", "png"):
        output_format = "jpeg"

    max_px = parse_int(max_px_raw, 1280, 320, 2400)
    quality = parse_int(quality_raw, 85, 30, 100)

    try:
        from PIL import Image
        img_path = _BASE_PATH / pass_name / folder_name / image_name
        cache_dir = _BASE_PATH / ".cache_light"

        if not img_path.exists():
            return json_error("Not found", 404)

        if not image_name.endswith(".png"):
            return json_error("PNG only", 400)

        cache_dir.mkdir(parents=True, exist_ok=True)
        st = img_path.stat()

        # Extensao do cache baseada no formato
        ext_map = {"jpeg": ".jpg", "webp": ".webp", "png": ".png"}
        cache_ext = ext_map.get(output_format, ".jpg")

        cache_key = f"{img_path}:{st.st_mtime_ns}:{max_px}:{output_format}:{quality}"
        cache_name = hashlib.sha1(cache_key.encode("utf-8")).hexdigest() + cache_ext
        cache_path = cache_dir / cache_name

        # Content-type baseado no formato
        content_type_map = {
            "jpeg": "image/jpeg",
            "webp": "image/webp",
            "png": "image/png",
        }
        content_type = content_type_map.get(output_format, "image/jpeg")

        if cache_path.exists():
            METRICS["cache_hits"] += 1.0
            return FileResponse(
                path=cache_path,
                headers={
                    "Content-Type": content_type,
                    "Cache-Control": "public, max-age=86400",
                }
            )

        METRICS["cache_misses"] += 1.0
        with Image.open(img_path) as im:
            # Converte para RGB (remove alpha para JPEG)
            if im.mode in ("RGBA", "P"):
                im = im.convert("RGB")

            im.thumbnail((max_px, max_px), Image.LANCZOS)
            buff = BytesIO()

            if output_format == "jpeg":
                im.save(buff, format="JPEG", quality=quality, optimize=True)
            elif output_format == "webp":
                im.save(buff, format="WEBP", quality=quality, method=4)
            else:  # png
                im.save(buff, format="PNG", optimize=True, compress_level=9)

            data = buff.getvalue()

        cache_path.write_bytes(data)

        return web.Response(
            body=data,
            headers={
                "Content-Type": content_type,
                "Cache-Control": "public, max-age=86400",
            }
        )
    except Exception as e:
        logger.exception("Erro serve image light")
        return json_error(str(e), 500)


async def satdump_serve_image_lossless(request: web.Request) -> web.Response:
    """Serve imagem PNG com compressao lossless (sem resize)."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    folder_name = request.query.get("folder", "")
    image_name = request.query.get("image", "")

    if not all([pass_name, folder_name, image_name]):
        return json_error("Missing params", 400)

    if ".." in pass_name or ".." in folder_name or ".." in image_name:
        return json_error("Invalid path", 400)

    try:
        from PIL import Image
        img_path = _BASE_PATH / pass_name / folder_name / image_name
        cache_dir = _BASE_PATH / ".cache_lossless"

        if not img_path.exists():
            return json_error("Not found", 404)

        if not image_name.endswith(".png"):
            return json_error("PNG only", 400)

        cache_dir.mkdir(parents=True, exist_ok=True)
        st = img_path.stat()
        cache_key = f"{img_path}:{st.st_mtime_ns}:lossless"
        cache_name = hashlib.sha1(cache_key.encode("utf-8")).hexdigest() + ".png"
        cache_path = cache_dir / cache_name

        if cache_path.exists():
            METRICS["cache_hits"] += 1.0
            return FileResponse(
                path=cache_path,
                headers={
                    "Content-Type": "image/png",
                    "Cache-Control": "public, max-age=86400",
                }
            )

        METRICS["cache_misses"] += 1.0
        with Image.open(img_path) as im:
            buff = BytesIO()
            im.save(buff, format="PNG", optimize=True, compress_level=9)
            data = buff.getvalue()

        cache_path.write_bytes(data)

        return web.Response(
            body=data,
            headers={
                "Content-Type": "image/png",
                "Cache-Control": "public, max-age=86400",
            }
        )
    except Exception as e:
        logger.exception("Erro serve image lossless")
        return json_error(str(e), 500)


async def satdump_serve_image_legend(request: web.Request) -> web.Response:
    """Serve imagem com metadados burned-in (legenda inferior)."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    folder_name = request.query.get("folder", "")
    image_name = request.query.get("image", "")
    output_format = request.query.get("format", "jpeg").lower()
    quality_raw = request.query.get("quality", "90")

    if not all([pass_name, folder_name, image_name]):
        return json_error("Missing params", 400)

    if ".." in pass_name or ".." in folder_name or ".." in image_name:
        return json_error("Invalid path", 400)

    if output_format not in ("jpeg", "png"):
        output_format = "jpeg"

    quality = parse_int(quality_raw, 90, 50, 100)

    try:
        from PIL import Image, ImageDraw, ImageFont

        img_path = _BASE_PATH / pass_name / folder_name / image_name
        cache_dir = _BASE_PATH / ".cache_legend"

        if not img_path.exists():
            return json_error("Not found", 404)

        if not image_name.endswith(".png"):
            return json_error("PNG only", 400)

        cache_dir.mkdir(parents=True, exist_ok=True)
        st = img_path.stat()

        ext = ".jpg" if output_format == "jpeg" else ".png"
        cache_key = f"{img_path}:{st.st_mtime_ns}:legend:{output_format}:{quality}"
        cache_name = hashlib.sha1(cache_key.encode("utf-8")).hexdigest() + ext
        cache_path = cache_dir / cache_name

        content_type = "image/jpeg" if output_format == "jpeg" else "image/png"

        if cache_path.exists():
            METRICS["cache_hits"] += 1.0
            return FileResponse(
                path=cache_path,
                headers={
                    "Content-Type": content_type,
                    "Cache-Control": "public, max-age=86400",
                }
            )

        METRICS["cache_misses"] += 1.0

        # Extrai metadados do nome da pasta
        # Formato: 2025-12-26_11-43_meteor_m2-x_lrpt_137.9 MHz
        satellite_name = "Meteor M2-x"
        if "m2-4" in pass_name.lower():
            satellite_name = "Meteor M2-4"
        elif "noaa" in pass_name.lower():
            satellite_name = "NOAA"

        # Extrai data/hora
        parts = pass_name.split("_")
        date_str = "Data desconhecida"
        time_str = ""
        if len(parts) >= 2:
            try:
                date_part = parts[0]  # 2025-12-26
                time_part = parts[1]  # 11-43
                dt_utc = dt.datetime.strptime(f"{date_part} {time_part}", "%Y-%m-%d %H-%M")
                # Converte para BRT (UTC-3)
                dt_brt = dt_utc - dt.timedelta(hours=3)
                date_str = dt_brt.strftime("%d/%m/%Y")
                time_str = dt_brt.strftime("%H:%M BRT")
            except ValueError:
                date_str = parts[0]
                time_str = parts[1].replace("-", ":") if len(parts) > 1 else ""

        # Tipo de imagem (da legenda)
        image_type = satdump.get_image_legend(img_path)
        # Remove markdown formatting
        image_type_clean = image_type.split("\n")[0].replace("*", "").replace("_", "").strip()

        with Image.open(img_path) as im:
            if im.mode in ("RGBA", "P"):
                im = im.convert("RGB")

            orig_width, orig_height = im.size

            # Altura da barra de legenda (proporcional a imagem)
            bar_height = max(60, int(orig_height * 0.06))

            # Cria nova imagem com barra preta na parte inferior
            new_height = orig_height + bar_height
            new_img = Image.new("RGB", (orig_width, new_height), (20, 20, 20))
            new_img.paste(im, (0, 0))

            draw = ImageDraw.Draw(new_img)

            # Tenta carregar fonte (fallback para padrao)
            font_size = max(14, int(bar_height * 0.35))
            small_font_size = max(12, int(bar_height * 0.25))

            try:
                # Tenta fontes comuns no sistema
                font_paths = [
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf",
                    "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
                    "/usr/share/fonts/truetype/freefont/FreeSansBold.ttf",
                    "/usr/share/fonts/TTF/DejaVuSans-Bold.ttf",
                ]
                font = None
                small_font = None
                for fp in font_paths:
                    if Path(fp).exists():
                        font = ImageFont.truetype(fp, font_size)
                        small_font = ImageFont.truetype(fp, small_font_size)
                        break
                if font is None:
                    font = ImageFont.load_default()
                    small_font = font
            except Exception:
                font = ImageFont.load_default()
                small_font = font

            # Texto da legenda
            # Linha 1: Satelite + Tipo de imagem
            line1 = f"{satellite_name}  |  {image_type_clean}"
            # Linha 2: Data, Hora, Local
            line2 = f"{date_str}  {time_str}  |  {STATION_LOCATION}"

            # Posicoes do texto (centralizado horizontalmente)
            padding = 15
            y_start = orig_height + padding

            # Desenha linha 1 (branco)
            bbox1 = draw.textbbox((0, 0), line1, font=font)
            text1_width = bbox1[2] - bbox1[0]
            x1 = (orig_width - text1_width) // 2
            draw.text((x1, y_start), line1, fill=(255, 255, 255), font=font)

            # Desenha linha 2 (cinza claro)
            y2 = y_start + font_size + 4
            bbox2 = draw.textbbox((0, 0), line2, font=small_font)
            text2_width = bbox2[2] - bbox2[0]
            x2 = (orig_width - text2_width) // 2
            draw.text((x2, y2), line2, fill=(180, 180, 180), font=small_font)

            buff = BytesIO()
            if output_format == "jpeg":
                new_img.save(buff, format="JPEG", quality=quality, optimize=True)
            else:
                new_img.save(buff, format="PNG", optimize=True)

            data = buff.getvalue()

        cache_path.write_bytes(data)

        return web.Response(
            body=data,
            headers={
                "Content-Type": content_type,
                "Cache-Control": "public, max-age=86400",
                "Content-Disposition": f'inline; filename="{satellite_name}_{date_str.replace("/", "-")}_{image_name}"',
            }
        )
    except Exception as e:
        logger.exception("Erro serve image legend")
        return json_error(str(e), 500)


async def satdump_pass_images_lossless(request: web.Request) -> web.Response:
    """Lista todas as imagens do passe com URLs lossless e legendas."""
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    pass_name = request.query.get("pass", "")
    if not pass_name or ".." in pass_name:
        return json_error("pass_not_found", 404)

    cache_key = f"satdump_pass_images_lossless:{pass_name}"
    cached = _cache.get(cache_key)
    if cached:
        return web.json_response(cached)

    try:
        pass_path = _BASE_PATH / pass_name
        if not pass_path.exists() or not pass_path.is_dir():
            return json_error("pass_not_found", 404)

        images_list = []
        folders = sorted([f for f in pass_path.iterdir() if f.is_dir()])
        for folder in folders:
            pngs = sorted([p for p in folder.glob("*.png") if p.is_file()])
            for img in pngs:
                images_list.append({
                    "name": img.name,
                    "legend": satdump.get_image_legend(img),
                    "pass_name": pass_name,
                    "folder_name": folder.name,
                    "image_lossless_url": (
                        "https://app.meulab.fun/api/satdump/image_lossless"
                        f"?pass={urllib.parse.quote(pass_name)}"
                        f"&folder={urllib.parse.quote(folder.name)}"
                        f"&image={urllib.parse.quote(img.name)}"
                    ),
                    "image_legend_url": (
                        "https://app.meulab.fun/api/satdump/image_legend"
                        f"?pass={urllib.parse.quote(pass_name)}"
                        f"&folder={urllib.parse.quote(folder.name)}"
                        f"&image={urllib.parse.quote(img.name)}"
                    ),
                })

        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "pass_name": pass_name,
            "images": images_list,
        }
        _cache.set(cache_key, payload, ttl=10.0)
        return web.json_response(payload)
    except Exception as e:
        logger.exception("Erro pass images lossless")
        return json_error(str(e), 500)


async def satdump_status(request: web.Request) -> web.Response:
    auth_error = require_bearer_token(request)
    if auth_error:
        return auth_error

    cached = _cache.get("satdump_status")
    if cached:
        return web.json_response(cached)

    try:
        data = await asyncio.to_thread(_satdump_latest_status)
        payload = {
            "timestamp": dt.datetime.now().isoformat(),
            "status": data,
        }
        _cache.set("satdump_status", payload, ttl=10.0)
        return web.json_response(payload)
    except Exception as e:
        return json_error(str(e), 500)


def _satdump_latest_status() -> Dict[str, Any]:
    base = _BASE_PATH
    if not base.exists():
        return {"error": "Base path not found"}
    folders = sorted([p for p in base.iterdir() if p.is_dir()], reverse=True)
    if not folders:
        return {"error": "No passes found"}
    latest = folders[0]
    size_bytes = 0
    image_count = 0
    for root, _, files in os.walk(latest):
        for name in files:
            path = os.path.join(root, name)
            try:
                size_bytes += os.path.getsize(path)
                if name.lower().endswith(".png"):
                    image_count += 1
            except OSError:
                continue
    mtime = latest.stat().st_mtime
    age_minutes = (time.time() - mtime) / 60.0
    return {
        "pass_name": latest.name,
        "size_bytes": size_bytes,
        "size_mb": round(size_bytes / 1_000_000, 2),
        "image_count": image_count,
        "last_modified": dt.datetime.fromtimestamp(mtime).isoformat(),
        "age_minutes": round(age_minutes, 1),
        "is_recent": age_minutes < 30,
    }
