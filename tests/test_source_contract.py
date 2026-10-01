#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
native = (ROOT / "src/IDCNativeBridge.mm").read_text()
engine = (ROOT / "src/IDCCommandEngine.m").read_text()
controller = (ROOT / "src/IDCConsoleController.m").read_text()
catalog = (ROOT / "src/IDCItemCatalog.m").read_text()
bootstrap = (ROOT / "src/IDCBootstrap.m").read_text()

assert "F4357753-A25F-30EE-BACF-63709F902895" in native
assert "MatchPrologue" in native
assert "Pause the run before using modifying commands" in native
assert "kAddCollectibleOffset = 0x500588" in native
assert "kRemoveCollectibleOffset = 0x5051e0" in native
assert "kGameSpawnOffset = 0x131080" in native
assert "kUseActiveItemOffset = 0x2ebe10" in native
assert "kGameSpawnPrologue" in native and "kUseActiveItemPrologue" in native
assert "giveitem" in engine and "remove" in engine
for command in ("spawnitem", "spawntrinket", "spawncard", "spawnrune", "spawnpill", "rewind"):
    assert command in engine
assert "pocketitems.xml" in catalog
assert "pilleffect" in catalog and '? @"pill"' in catalog
assert "suggestionsForInput" in engine
assert "IDCPassthroughView" in controller
assert "toggleKeyboard:" in controller
assert "colorWithWhite:0 alpha:0.78" in controller
assert "windowLevel" not in controller or "UIWindowLevelNormal" in controller
assert "com.Nicalis.Isaac-iOS" in bootstrap

for forbidden in ("MobileSubstrate", "substrate.h", "ElleKit", "/var/jb"):
    assert forbidden not in "\n".join((native, engine, controller, catalog, bootstrap))

print("source contract tests passed")
