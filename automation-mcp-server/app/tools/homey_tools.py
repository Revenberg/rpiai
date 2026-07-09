from __future__ import annotations

from typing import Annotated, Any

from pydantic import Field

from app.providers.homey import HomeyProvider
from app.utils.instrumentation import instrument_tool_call
from app.utils.responses import fail


def register_homey_tools(mcp: Any, provider: HomeyProvider | None, logger: Any) -> None:
    @mcp.tool(name="homey.devices", description="List all Homey devices.")
    async def homey_devices() -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.devices",
            parameters={},
            call=provider.devices,
        )

    @mcp.tool(name="homey.device", description="Get a Homey device by device ID.")
    async def homey_device(
        device_id: Annotated[str, Field(description="Homey device ID")],
    ) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.device",
            parameters={"device_id": device_id},
            call=lambda: provider.device(device_id),
        )

    @mcp.tool(name="homey.turn_on", description="Turn a Homey device on.")
    async def homey_turn_on(device: Annotated[str, Field(description="Homey device ID")]) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.turn_on",
            parameters={"device": device},
            call=lambda: provider.turn_on(device),
        )

    @mcp.tool(name="homey.turn_off", description="Turn a Homey device off.")
    async def homey_turn_off(device: Annotated[str, Field(description="Homey device ID")]) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.turn_off",
            parameters={"device": device},
            call=lambda: provider.turn_off(device),
        )

    @mcp.tool(name="homey.toggle", description="Toggle a Homey device.")
    async def homey_toggle(device: Annotated[str, Field(description="Homey device ID")]) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.toggle",
            parameters={"device": device},
            call=lambda: provider.toggle(device),
        )

    @mcp.tool(name="homey.set_dim", description="Set Homey dim level for a device.")
    async def homey_set_dim(
        device: Annotated[str, Field(description="Homey device ID")],
        value: Annotated[float, Field(ge=0.0, le=1.0, description="Dim value between 0.0 and 1.0")],
    ) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.set_dim",
            parameters={"device": device, "value": value},
            call=lambda: provider.set_dim(device, value),
        )

    @mcp.tool(name="homey.set_temperature", description="Set target temperature on a Homey thermostat device.")
    async def homey_set_temperature(
        device: Annotated[str, Field(description="Homey device ID")],
        value: Annotated[float, Field(description="Target temperature value")],
    ) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.set_temperature",
            parameters={"device": device, "value": value},
            call=lambda: provider.set_temperature(device, value),
        )

    @mcp.tool(name="homey.set_capability", description="Set any capability value on a Homey device.")
    async def homey_set_capability(
        device: Annotated[str, Field(description="Homey device ID")],
        capability: Annotated[str, Field(description="Capability name")],
        value: Annotated[Any, Field(description="Capability value")],
    ) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.set_capability",
            parameters={"device": device, "capability": capability, "value": value},
            call=lambda: provider.set_capability(device, capability, value),
        )

    @mcp.tool(name="homey.run_flow", description="Run a Homey flow by flow name.")
    async def homey_run_flow(flow_name: Annotated[str, Field(description="Homey flow name")]) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.run_flow",
            parameters={"flow_name": flow_name},
            call=lambda: provider.run_flow(flow_name),
        )

    @mcp.tool(name="homey.flow_cards", description="List Homey flow cards.")
    async def homey_flow_cards() -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.flow_cards",
            parameters={},
            call=provider.flow_cards,
        )

    @mcp.tool(name="homey.zones", description="List Homey zones.")
    async def homey_zones() -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.zones",
            parameters={},
            call=provider.zones,
        )

    @mcp.tool(name="homey.energy", description="Get Homey energy information.")
    async def homey_energy() -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.energy",
            parameters={},
            call=provider.energy,
        )

    @mcp.tool(name="homey.get_variable", description="Get a Homey logic variable by name.")
    async def homey_get_variable(name: Annotated[str, Field(description="Homey variable name")]) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.get_variable",
            parameters={"name": name},
            call=lambda: provider.get_variable(name),
        )

    @mcp.tool(name="homey.set_variable", description="Set a Homey logic variable by name.")
    async def homey_set_variable(
        name: Annotated[str, Field(description="Homey variable name")],
        value: Annotated[Any, Field(description="Variable value")],
    ) -> dict[str, Any]:
        if not provider:
            return fail("Homey disabled")
        return await instrument_tool_call(
            logger=logger,
            tool_name="homey.set_variable",
            parameters={"name": name, "value": value},
            call=lambda: provider.set_variable(name, value),
        )
