from app.utils.responses import fail, ok


def test_ok_response() -> None:
    result = ok({"x": 1})
    assert result["success"] is True
    assert result["error"] is None
    assert result["data"] == {"x": 1}


def test_fail_response() -> None:
    result = fail("boom")
    assert result["success"] is False
    assert result["data"] is None
    assert result["error"] == "boom"
