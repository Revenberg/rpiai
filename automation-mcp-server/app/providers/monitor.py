from __future__ import annotations

from typing import Any

import httpx

from app.config import MonitorConfig
from app.utils.responses import fail, ok


class MonitorProvider:
    def __init__(self, config: MonitorConfig) -> None:
        self.config = config

    async def _get(self, path: str) -> dict[str, Any]:
        url = f"{str(self.config.base_url).rstrip('/')}/{path.lstrip('/')}"
        try:
            async with httpx.AsyncClient(timeout=self.config.timeout_seconds) as client:
                resp = await client.get(url)
            if not resp.is_success:
                return fail(f"Monitor error {resp.status_code}: {resp.text}")
            return ok(resp.json())
        except httpx.HTTPError:
            return fail("Monitor unreachable")

    async def host_summary(self) -> dict[str, Any]:
        quicklook = await self._get("quicklook")
        if not quicklook.get("success"):
            return quicklook

        data = quicklook.get("data") or {}
        result = {
            "cpu_percent": data.get("cpu") or data.get("cpu_percent"),
            "mem_percent": data.get("mem") or data.get("mem_percent"),
            "uptime_seconds": data.get("uptime_seconds") or data.get("uptime"),
            "load_min5": data.get("load") or data.get("load_min5"),
            "ip_address": data.get("ip") or data.get("public_ip") or data.get("private_ip"),
        }
        return ok(result)

    async def containers(self) -> dict[str, Any]:
        docker_stats = await self._get("docker")
        if not docker_stats.get("success"):
            return docker_stats

        rows = docker_stats.get("data") or []
        items: list[dict[str, Any]] = []
        for row in rows:
            items.append(
                {
                    "name": row.get("name") or row.get("Names"),
                    "status": row.get("status") or row.get("State"),
                    "cpu_percent": row.get("cpu_percent") or row.get("cpu") or row.get("CPUPerc"),
                    "mem_percent": row.get("memory_percent") or row.get("mem_percent") or row.get("MemPerc"),
                    "mem_usage": row.get("memory_usage") or row.get("MemUsage"),
                }
            )

        return ok(items)
