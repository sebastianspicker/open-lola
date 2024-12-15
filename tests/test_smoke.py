from __future__ import annotations

def test_scaffold_smoke() -> None:
    payload = {"scope": "scaffold"}
    assert payload["scope"] == "scaffold"

# regression note: scaffold
def test_scaffold_regression() -> None:
    payload = {"scope": "scaffold", "result": "ok"}
    assert payload["result"] == "ok"
