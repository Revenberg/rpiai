from __future__ import annotations

import os
from functools import lru_cache
from pathlib import Path

import yaml
from pydantic import BaseModel, Field, HttpUrl


class JwtConfig(BaseModel):
    enabled: bool = False
    secret_key: str = ""
    algorithm: str = "HS256"
    audience: str | None = None
    issuer: str | None = None


class HomeyConfig(BaseModel):
    enabled: bool = True
    base_url: HttpUrl
    bearer_token: str
    timeout_seconds: float = 15.0


class HAInstanceConfig(BaseModel):
    url: HttpUrl
    token: str
    timeout_seconds: float = 15.0


class HomeAssistantConfig(BaseModel):
    instances: dict[str, HAInstanceConfig] = Field(default_factory=dict)


class ServerConfig(BaseModel):
    host: str = "0.0.0.0"
    port: int = 8080


class AppConfig(BaseModel):
    homey: HomeyConfig | None = None
    homeassistant: HomeAssistantConfig = Field(default_factory=HomeAssistantConfig)
    jwt: JwtConfig = Field(default_factory=JwtConfig)
    server: ServerConfig = Field(default_factory=ServerConfig)


@lru_cache(maxsize=1)
def load_config() -> AppConfig:
    config_path = Path(os.environ.get("CONFIG_PATH", "config.yaml"))
    if not config_path.exists():
        raise FileNotFoundError(f"Config file not found: {config_path}")

    raw = yaml.safe_load(config_path.read_text(encoding="utf-8")) or {}
    return AppConfig.model_validate(raw)
