from __future__ import annotations

from typing import Any

import jwt
from fastapi import Depends, FastAPI, HTTPException, Request, status

from app.config import AppConfig, load_config
from app.logging import configure_logging, get_logger
from app.models import HealthResponse
from app.providers.homeassistant import HomeAssistantProvider
from app.providers.homey import HomeyProvider
from app.tools.ha_tools import register_ha_tools
from app.tools.homey_tools import register_homey_tools

try:
    from mcp.server.fastmcp import FastMCP
except ImportError as exc:  # pragma: no cover
    raise RuntimeError("mcp Python SDK is required. Install dependencies from requirements.txt") from exc


def _build_mcp_asgi_app(mcp: FastMCP):
    for attr in ("streamable_http_app", "http_app", "sse_app"):
        maybe = getattr(mcp, attr, None)
        if callable(maybe):
            return maybe()
    raise RuntimeError("Cannot construct MCP ASGI app from installed mcp SDK version")


def _make_auth_dependency(cfg: AppConfig):
    async def _auth(request: Request) -> None:
        if not cfg.jwt.enabled:
            return

        auth = request.headers.get("Authorization", "")
        if not auth.startswith("Bearer "):
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

        token = auth[len("Bearer ") :].strip()
        if not token:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Missing bearer token")

        try:
            jwt.decode(
                token,
                cfg.jwt.secret_key,
                algorithms=[cfg.jwt.algorithm],
                audience=cfg.jwt.audience,
                issuer=cfg.jwt.issuer,
                options={"verify_aud": cfg.jwt.audience is not None, "verify_iss": cfg.jwt.issuer is not None},
            )
        except jwt.PyJWTError as exc:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token") from exc

    return _auth


def create_app() -> FastAPI:
    configure_logging()
    logger = get_logger("automation-mcp-server")

    cfg = load_config()
    auth_dependency = _make_auth_dependency(cfg)

    app = FastAPI(title="automation-mcp-server", version="1.0.0")

    homey_provider = HomeyProvider(cfg.homey) if cfg.homey and cfg.homey.enabled else None
    ha_provider = HomeAssistantProvider(cfg.homeassistant.instances)

    mcp = FastMCP("automation-mcp-server")
    register_homey_tools(mcp, homey_provider, logger)
    register_ha_tools(mcp, ha_provider, logger)

    @app.get("/health", response_model=HealthResponse)
    async def health() -> HealthResponse:
        return HealthResponse(service="automation-mcp-server", status="ok")

    @app.get("/meta")
    async def meta(_: Any = Depends(auth_dependency)) -> dict[str, Any]:
        return {
            "service": "automation-mcp-server",
            "homey_enabled": bool(homey_provider),
            "homeassistant_instances": sorted(cfg.homeassistant.instances.keys()),
            "jwt_enabled": cfg.jwt.enabled,
        }

    app.mount("/mcp", _build_mcp_asgi_app(mcp))

    logger.info(
        "server_started",
        service="automation-mcp-server",
        homey_enabled=bool(homey_provider),
        ha_instances=sorted(cfg.homeassistant.instances.keys()),
        jwt_enabled=cfg.jwt.enabled,
    )

    return app
