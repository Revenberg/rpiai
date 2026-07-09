from __future__ import annotations

from datetime import datetime, timedelta, timezone
from typing import Any

import httpx

from app.config import HAInstanceConfig
from app.utils.responses import fail, ok


class HomeAssistantProvider:
    def __init__(self, instances: dict[str, HAInstanceConfig]) -> None:
        self.instances = instances

    def _get_instance(self, instance: str) -> HAInstanceConfig | None:
        return self.instances.get(instance)

    async def _request(
        self,
        instance: str,
        method: str,
        path: str,
        *,
        params: dict[str, Any] | None = None,
        json_body: dict[str, Any] | list[Any] | None = None,
    ) -> dict[str, Any]:
        cfg = self._get_instance(instance)
        if not cfg:
            return fail(f"Unknown Home Assistant instance: {instance}")

        headers = {
            "Authorization": f"Bearer {cfg.token}",
            "Content-Type": "application/json",
        }
        url = f"{str(cfg.url).rstrip('/')}/{path.lstrip('/')}"

        try:
            async with httpx.AsyncClient(timeout=cfg.timeout_seconds) as client:
                resp = await client.request(method=method.upper(), url=url, headers=headers, params=params, json=json_body)
            if resp.is_success:
                if resp.text.strip():
                    return ok(resp.json())
                return ok({})
            return fail(f"Home Assistant error {resp.status_code}: {resp.text}")
        except httpx.HTTPError:
            return fail("Home Assistant unreachable")

    async def entities(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/states")

    async def states(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/states")

    async def turn_on(self, instance: str, entity: str) -> dict[str, Any]:
        domain = entity.split(".", 1)[0]
        return await self.call_service(instance, domain, "turn_on", {"entity_id": entity})

    async def turn_off(self, instance: str, entity: str) -> dict[str, Any]:
        domain = entity.split(".", 1)[0]
        return await self.call_service(instance, domain, "turn_off", {"entity_id": entity})

    async def toggle(self, instance: str, entity: str) -> dict[str, Any]:
        domain = entity.split(".", 1)[0]
        return await self.call_service(instance, domain, "toggle", {"entity_id": entity})

    async def call_service(self, instance: str, domain: str, service: str, data: dict[str, Any]) -> dict[str, Any]:
        return await self._request(instance, "POST", f"/api/services/{domain}/{service}", json_body=data)

    async def scene(self, instance: str, scene: str) -> dict[str, Any]:
        return await self.call_service(instance, "scene", "turn_on", {"entity_id": scene})

    async def script(self, instance: str, script: str) -> dict[str, Any]:
        return await self.call_service(instance, "script", "turn_on", {"entity_id": script})

    async def get_state(self, instance: str, entity: str) -> dict[str, Any]:
        return await self._request(instance, "GET", f"/api/states/{entity}")

    async def history(self, instance: str, entity: str, hours: int = 24) -> dict[str, Any]:
        end_time = datetime.now(timezone.utc)
        start_time = end_time - timedelta(hours=hours)
        path = f"/api/history/period/{start_time.isoformat()}"
        params = {
            "filter_entity_id": entity,
            "end_time": end_time.isoformat(),
        }
        return await self._request(instance, "GET", path, params=params)

    async def areas(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/config/area_registry/list")

    async def devices(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/config/device_registry/list")

    async def labels(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/config/label_registry/list")

    async def services(self, instance: str) -> dict[str, Any]:
        return await self._request(instance, "GET", "/api/services")
