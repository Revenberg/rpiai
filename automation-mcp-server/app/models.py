from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class ToolResult(BaseModel):
    success: bool = Field(..., description="Indicates whether the tool call succeeded.")
    data: Any | None = Field(default=None, description="Tool output payload.")
    error: str | None = Field(default=None, description="Human-readable error when success=false.")


class HealthResponse(BaseModel):
    service: str
    status: str
