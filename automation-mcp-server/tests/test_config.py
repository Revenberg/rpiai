from __future__ import annotations

from pathlib import Path

from app.config import AppConfig, load_config


SAMPLE = """
homey:
  enabled: true
  base_url: https://example.homey.local
  bearer_token: token123

homeassistant:
  instances:
    home:
      url: http://192.168.1.10:8123
      token: abc
"""


def test_load_config_from_yaml(tmp_path: Path, monkeypatch) -> None:
    cfg_file = tmp_path / "config.yaml"
    cfg_file.write_text(SAMPLE, encoding="utf-8")

    monkeypatch.setenv("CONFIG_PATH", str(cfg_file))
    load_config.cache_clear()

    cfg = load_config()
    assert isinstance(cfg, AppConfig)
    assert cfg.homey is not None
    assert cfg.homey.enabled is True
    assert "home" in cfg.homeassistant.instances
