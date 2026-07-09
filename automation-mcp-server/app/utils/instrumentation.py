from __future__ import annotations

import time
from collections.abc import Awaitable, Callable
from typing import Any


async def instrument_tool_call(
    *,
    logger: Any,
    tool_name: str,
    parameters: dict[str, Any],
    call: Callable[[], Awaitable[dict[str, Any]]],
) -> dict[str, Any]:
    started = time.perf_counter()
    result = await call()
    duration_ms = round((time.perf_counter() - started) * 1000, 2)

    if result.get("success"):
        logger.info(
            "tool_call",
            tool=tool_name,
            parameters=parameters,
            duration_ms=duration_ms,
            result="success",
        )
    else:
        logger.warning(
            "tool_call",
            tool=tool_name,
            parameters=parameters,
            duration_ms=duration_ms,
            result="failure",
            error=result.get("error", "unknown error"),
        )

    return result
