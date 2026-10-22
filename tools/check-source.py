#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
native = (ROOT / "src/IDCNativeBridge.mm").read_text()
engine = (ROOT / "src/IDCCommandEngine.m").read_text()
controller = (ROOT / "src/IDCConsoleController.m").read_text()
catalog = (ROOT / "src/IDCItemCatalog.m").read_text()
bootstrap = (ROOT / "src/IDCBootstrap.m").read_text()
hotkey = (ROOT / "src/IDCHotkey.m").read_text()

assert "F4357753-A25F-30EE-BACF-63709F902895" in native
assert "MatchPrologue" in native
assert "Pause the run before using modifying commands" in native
assert "kAddCollectibleOffset = 0x500588" in native
assert "kRemoveCollectibleOffset = 0x5051e0" in native
assert "kGameSpawnOffset = 0x88fcbc" in native
assert "kGameEntityFactoryOffset = 0x1cf430" in native
assert "readSpawnContextAddress" in native
assert "factory == UINTPTR_MAX" in native
assert "reinterpret_cast<void *>(game)" in native
assert "(unsigned int)subtype, seed, 0" in native
assert "kUseActiveItemOffset = 0x580a28" in native
assert "kGlowingHourglassCollectible, 0, -1, 0" in native
assert "kGameSpawnPrologue" in native and "kUseActiveItemPrologue" in native
assert "giveitem" in engine and "remove" in engine
for command in ("spawnitem", "spawntrinket", "spawncard", "spawnrune", "spawnpill", "rewind", "restart"):
    assert command in engine
assert "pocketitems.xml" in catalog
assert "pilleffect" in catalog and '? @"pill"' in catalog
assert "suggestionsForInput" in engine
assert "IDCPassthroughView" in controller
assert "toggleKeyboard:" in controller
assert "colorWithWhite:0 alpha:0.78" in controller
assert "windowLevel" not in controller or "UIWindowLevelNormal" in controller
assert "com.Nicalis.Isaac-iOS" in bootstrap
assert "UIKeyboardHIDUsageKeyboardGraveAccentAndTilde" in hotkey
assert "UIPressesEvent" in hotkey
assert "addLocalMonitorForEventsMatchingMask:" in hotkey
assert "isARepeat" in hotkey and "keyHeld" in hotkey
assert "UIKeyboardHIDUsageKeyboardEscape" in hotkey and "escapeConsumed" in hotkey
assert "closeFromKeyboard" in controller
assert "com.emp0ry.isaacconsole.closeForEscape" in controller
assert "gOriginalSendEvent(application, selector, event)" in hotkey
assert "hasOtherTextInput:" in controller and "toggleFromKeyboard" in controller
assert "beginConsolePause" in controller and "endConsolePause" in controller
assert "snapshot.presentationVisible" in controller
assert "IDCFullPanel" in controller
assert "MIN(760" not in controller and "MIN(390" not in controller
assert "_consolePause.CanResume" in native and "state.pause==1" in native
assert "PauseSignaturesMatch" in native and "IsaacPresentation::Capture" in native
assert '@"aliases": @[@"rs"]' in engine
assert "RestartSignaturesMatch" in native and "image+0x672568" in native
assert "WritableMemory" in native and "pending ||" in native
version = next(line.split(":", 1)[1].strip() for line in (ROOT / "package/control").read_text().splitlines() if line.startswith("Version:"))
assert f'@"{version}"' in engine and f"Isaac Debug Console iOS {version}" in controller
notes = (ROOT / f"docs/RELEASE_NOTES_v{version}.md").read_text()
assert not notes.startswith("# ")

for forbidden in ("MobileSubstrate", "substrate.h", "ElleKit", "/var/jb"):
    assert forbidden not in "\n".join((native, engine, controller, catalog, bootstrap))

print("source contract tests passed")
