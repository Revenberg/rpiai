from typing import Any

from app.providers.monitor import MonitorProvider
from app.utils.instrumentation import instrument_tool_call


def register_monitor_tools(mcp: Any, provider: MonitorProvider | None, logger: Any) -> None:
    @mcp.tool(name="monitor.host", description="Get Raspberry Pi CPU and memory summary.")
    async def monitor_host():
        if not provider:
            return {"success": False, "data": None, "error": "Monitor disabled"}
        return await instrument_tool_call(
            logger=logger,
            tool_name="monitor.host",
            parameters={},
            call=provider.host_summary,
        )

    @mcp.tool(name="monitor.containers", description="List Docker containers with CPU and memory usage.")
    async def monitor_containers():
        if not provider:
            return {"success": False, "data": None, "error": "Monitor disabled"}
        return await instrument_tool_call(
            logger=logger,
            tool_name="monitor.containers",
            parameters={},
            call=provider.containers,
        )
