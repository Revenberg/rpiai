from __future__ import annotations

from typing import Any

import httpx

from app.config import HomeyConfig
from app.utils.responses import fail, ok


class HomeyProvider:
    def __init__(self, config: HomeyConfig) -> None:
        self.config = config

    async def _request(
        self,
        method: str,
        path: str,
        *,
        json_body: dict[str, Any] | None = None,
        params: dict[str, Any] | None = None,
    ) -> dict[str, Any]:
        headers = {
            "Authorization": f"Bearer {self.config.bearer_token}",
            "Content-Type": "application/json",
        }
        url = f"{str(self.config.base_url).rstrip('/')}/{path.lstrip('/')}"

        try:
            async with httpx.AsyncClient(timeout=self.config.timeout_seconds) as client:
                resp = await client.request(method=method.upper(), url=url, headers=headers, params=params, json=json_body)
            if resp.is_success:
                if resp.text.strip():
                    return ok(resp.json())
                return ok({})
            return fail(f"Homey error {resp.status_code}: {resp.text}")
        except httpx.HTTPError:
            return fail("Homey unreachable")

    async def devices(self) -> dict[str, Any]:
        return await self._request("GET", "/api/manager/devices/device")

    async def device(self, device_id: str) -> dict[str, Any]:
        return await self._request("GET", f"/api/manager/devices/device/{device_id}")

    async def turn_on(self, device: str) -> dict[str, Any]:
        return await self.set_capability(device, "onoff", True)

    async def turn_off(self, device: str) -> dict[str, Any]:
        return await self.set_capability(device, "onoff", False)

    async def toggle(self, device: str) -> dict[str, Any]:
        current = await self.device(device)
        if not current.get("success"):
            return current

        current_value = (
            current.get("data", {})
            .get("capabilitiesObj", {})
            .get("onoff", {})
            .get("value", False)
        )
        return await self.set_capability(device, "onoff", not bool(current_value))

    async def set_dim(self, device: str, value: float) -> dict[str, Any]:
        return await self.set_capability(device, "dim", value)

    async def set_temperature(self, device: str, value: float) -> dict[str, Any]:
        return await self.set_capability(device, "target_temperature", value)

    async def set_capability(self, device: str, capability: str, value: Any) -> dict[str, Any]:
        return await self._request(
            "PUT",
            f"/api/manager/devices/device/{device}/capability/{capability}",
            json_body={"value": value},
        )

    async def run_flow(self, flow_name: str) -> dict[str, Any]:
        flows = await self._request("GET", "/api/manager/flow/flow")
        if not flows.get("success"):
            return flows

        flow_map = flows.get("data", {})
        flow_id = None
        for fid, fval in flow_map.items():
            if str(fval.get("name", "")).lower() == flow_name.lower():
                flow_id = fid
                break

        if not flow_id:
            return fail(f"Flow not found: {flow_name}")

        return await self._request("POST", f"/api/manager/flow/flow/{flow_id}/trigger")

    async def flow_cards(self) -> dict[str, Any]:
        return await self._request("GET", "/api/manager/flow/flowcard")

    async def zones(self) -> dict[str, Any]:
        return await self._request("GET", "/api/manager/zones/zone")

    async def energy(self) -> dict[str, Any]:
        return await self._request("GET", "/api/manager/energy")

    async def get_variable(self, name: str) -> dict[str, Any]:
        variables = await self._request("GET", "/api/manager/logic/variable")
        if not variables.get("success"):
            return variables

        for _, var in variables.get("data", {}).items():
            if str(var.get("name", "")).lower() == name.lower():
                return ok(var)

        return fail(f"Variable not found: {name}")

    async def set_variable(self, name: str, value: Any) -> dict[str, Any]:
        variables = await self._request("GET", "/api/manager/logic/variable")
        if not variables.get("success"):
            return variables

        variable_id = None
        variable_type = None
        for vid, var in variables.get("data", {}).items():
            if str(var.get("name", "")).lower() == name.lower():
                variable_id = vid
                variable_type = var.get("type")
                break

        if not variable_id:
            return fail(f"Variable not found: {name}")

        payload: dict[str, Any] = {"id": variable_id}
        if variable_type:
            payload["type"] = variable_type
        payload["value"] = value

        return await self._request("PUT", f"/api/manager/logic/variable/{variable_id}", json_body=payload)
