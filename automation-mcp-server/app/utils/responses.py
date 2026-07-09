from __future__ import annotations

from typing import Any


def ok(data: Any = None) -> dict[str, Any]:
    return {"success": True, "data": data, "error": None}


def fail(error: str) -> dict[str, Any]:
    return {"success": False, "data": None, "error": error}
