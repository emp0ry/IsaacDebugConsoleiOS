#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
native = (ROOT / "src/IDCNativeBridge.mm").read_text()
engine = (ROOT / "src/IDCCommandEngine.m").read_text()
controller = (ROOT / "src/IDCConsoleController.m").read_text()
bootstrap = (ROOT / "src/IDCBootstrap.m").read_text()

assert "F4357753-A25F-30EE-BACF-63709F902895" in native
assert "MatchPrologue" in native
assert "Pause the run before using modifying commands" in native
assert "kAddCollectibleOffset = 0x500588" in native
assert "kRemoveCollectibleOffset = 0x5051e0" in native
assert "giveitem" in engine and "remove" in engine
assert "suggestionsForInput" in engine
assert "IDCPassthroughView" in controller
assert "windowLevel" not in controller or "UIWindowLevelNormal" in controller
assert "com.Nicalis.Isaac-iOS" in bootstrap

for forbidden in ("MobileSubstrate", "substrate.h", "ElleKit", "/var/jb"):
    assert forbidden not in "\n".join((native, engine, controller, bootstrap))

print("source contract tests passed")
