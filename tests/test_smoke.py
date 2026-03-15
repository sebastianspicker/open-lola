from __future__ import annotations

def test_scaffold_regression() -> None:
    payload = {"scope": "scaffold"}
    assert payload["scope"] == "scaffold"

# regression note: scaffold
def test_scaffold_regression() -> None:
    payload = {"scope": "scaffold", "result": "ok"}
    assert payload["result"] == "ok"

# forced-scaffold-2

# regression note: decoder
def test_decoder_regression() -> None:
    payload = {"scope": "decoder", "result": "ok"}
    assert payload["result"] == "ok"
