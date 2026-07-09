from __future__ import annotations

from typing import Any

from app.providers.homeassistant import HomeAssistantProvider
from app.utils.instrumentation import instrument_tool_call


def register_ha_tools(mcp: Any, provider: HomeAssistantProvider, logger: Any) -> None:
    @mcp.tool(name="ha.entities", description="List Home Assistant entities for the selected instance.")
    async def ha_entities(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.entities",
            parameters={"instance": instance},
            call=lambda: provider.entities(instance),
        )

    @mcp.tool(name="ha.states", description="List Home Assistant states for the selected instance.")
    async def ha_states(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.states",
            parameters={"instance": instance},
            call=lambda: provider.states(instance),
        )

    @mcp.tool(name="ha.turn_on", description="Turn on a Home Assistant entity.")
    async def ha_turn_on(
        instance: str,
        entity: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.turn_on",
            parameters={"instance": instance, "entity": entity},
            call=lambda: provider.turn_on(instance, entity),
        )

    @mcp.tool(name="ha.turn_off", description="Turn off a Home Assistant entity.")
    async def ha_turn_off(
        instance: str,
        entity: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.turn_off",
            parameters={"instance": instance, "entity": entity},
            call=lambda: provider.turn_off(instance, entity),
        )

    @mcp.tool(name="ha.toggle", description="Toggle a Home Assistant entity.")
    async def ha_toggle(
        instance: str,
        entity: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.toggle",
            parameters={"instance": instance, "entity": entity},
            call=lambda: provider.toggle(instance, entity),
        )

    @mcp.tool(name="ha.call_service", description="Call any Home Assistant service.")
    async def ha_call_service(
        instance: str,
        domain: str,
        service: str,
        data: dict[str, Any],
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.call_service",
            parameters={"instance": instance, "domain": domain, "service": service, "data": data},
            call=lambda: provider.call_service(instance, domain, service, data),
        )

    @mcp.tool(name="ha.scene", description="Activate a Home Assistant scene.")
    async def ha_scene(
        instance: str,
        scene: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.scene",
            parameters={"instance": instance, "scene": scene},
            call=lambda: provider.scene(instance, scene),
        )

    @mcp.tool(name="ha.script", description="Run a Home Assistant script.")
    async def ha_script(
        instance: str,
        script: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.script",
            parameters={"instance": instance, "script": script},
            call=lambda: provider.script(instance, script),
        )

    @mcp.tool(name="ha.get_state", description="Get current state for one Home Assistant entity.")
    async def ha_get_state(
        instance: str,
        entity: str,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.get_state",
            parameters={"instance": instance, "entity": entity},
            call=lambda: provider.get_state(instance, entity),
        )

    @mcp.tool(name="ha.history", description="Get Home Assistant history for an entity.")
    async def ha_history(
        instance: str,
        entity: str,
        hours: int = 24,
    ) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.history",
            parameters={"instance": instance, "entity": entity, "hours": hours},
            call=lambda: provider.history(instance, entity, hours),
        )

    @mcp.tool(name="ha.areas", description="List Home Assistant areas for the selected instance.")
    async def ha_areas(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.areas",
            parameters={"instance": instance},
            call=lambda: provider.areas(instance),
        )

    @mcp.tool(name="ha.devices", description="List Home Assistant devices for the selected instance.")
    async def ha_devices(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.devices",
            parameters={"instance": instance},
            call=lambda: provider.devices(instance),
        )

    @mcp.tool(name="ha.labels", description="List Home Assistant labels for the selected instance.")
    async def ha_labels(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.labels",
            parameters={"instance": instance},
            call=lambda: provider.labels(instance),
        )

    @mcp.tool(name="ha.services", description="List Home Assistant services for the selected instance.")
    async def ha_services(instance: str) -> dict[str, Any]:
        return await instrument_tool_call(
            logger=logger,
            tool_name="ha.services",
            parameters={"instance": instance},
            call=lambda: provider.services(instance),
        )
