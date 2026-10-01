# Isaac Debug Console iOS

An in-game debug console for the native iOS release of *The Binding of Isaac: Rebirth +
Repentance*. It provides a compact UIKit console, live command suggestions, command history,
and native run-inspection, inventory, room-spawn, and rewind commands.

This is an independent project inspired by the console experience provided by
[REPENTOGON](https://github.com/TeamREPENTOGON/REPENTOGON). It does not contain or copy
REPENTOGON code and is not affiliated with its developers, Nicalis, Edmund McMillen, Apple,
or Valve.

## Interface

Pause an active run. A **Console** button appears in the lower-left corner. The overlay does
not create another window, so touches outside the panel continue to reach Isaac. Start typing
to see suggestions; tap a suggestion to complete it. The keyboard button in the command row
hides the software keyboard and brings it back without closing the console.

Available commands:

- `help [command]` — list commands or show usage
- `status` — bridge, executable, run, and catalog status
- `seed` — current native run seed
- `room` — current room type
- `position` / `pos` — player type and coordinates
- `inventory` / `inv` — owned collectible IDs, names, and counts
- `items <name|id>` / `find` — search the game's collectible catalog
- `trinkets [name|id]` — list or search trinkets
- `cards [name|id]` — list or search cards
- `runes [name|id]` — list or search runes and soul stones
- `pilleffects [name|id]` / `pills` — list or search pill effects
- `giveitem <cID|name>` / `g` — add a collectible through Isaac's native player function
- `remove <cID|name>` / `r` — remove one collectible through Isaac's native player function
- `spawn <type.variant.subtype>` / `s` — spawn a native entity beside the player
- `spawnpickup <variant.subtype>` / `pickup` — spawn a pickup (`EntityType 5`)
- `spawnitem <cID|name>` / `si` — spawn a collectible pedestal
- `spawntrinket <tID|name>` / `st` — spawn a trinket
- `spawncard <ID|name>` / `sc` — spawn a card
- `spawnrune <ID|1-10|name>` / `sr` — spawn a rune or soul stone
- `spawnpill <color|effect> [horse]` / `sp` — spawn a normal or horse pill
- `rewind` / `hourglass` — invoke Isaac's real Glowing Hourglass rewind logic
- `history`, `clear`, `version`, `close`

The empty suggestion list contains every command and is scrollable. Item, trinket, card, rune,
and pill-effect suggestions come from the XML catalogs bundled with the installed game. A pill
effect can be spawned only when that effect is assigned to one of the current run's thirteen
normal pill colors. Use a numeric color from 1 through 14 to spawn a specific visual color;
append `horse` for a horse pill. For example:

```text
spawnitem sacred heart
spawncard 1
spawnrune jera
spawnpill effect 2
spawnpill 7 horse
spawn 5.100.1
rewind
```

Every modifying command is allowed only while a run is paused. Native addresses, the Isaac
Mach-O UUID, the player RTTI/vtable, and each function prologue are validated before a native
call.

## Compatibility

The portable dylib links only Apple system frameworks and runs inside Isaac's process. It has
no Substrate, ElleKit, root, daemon, or `/var/jb` dependency. Jailbreak injection is only one
optional loader.

Native mutation is currently supported for the inspected Isaac arm64 executable UUID:
`F4357753-A25F-30EE-BACF-63709F902895`. On another game build the console fails closed: it
reports the unsupported UUID and does not call guessed native functions.

## Build

Requirements: macOS, Xcode iPhoneOS SDK, `dpkg-deb`, and `ripgrep` for the dependency audit.

```sh
make release
```

Outputs:

- `dist/IsaacDebugConsole.dylib` — portable arm64 dylib for embedded loading
- `dist/IsaacDebugConsole-rootless.deb` — rootless ElleKit package
- `dist/IsaacDebugConsole-LiveContainer.framework.zip` — LiveContainer framework
- `dist/IsaacDebugConsole-Embedded.zip` — files for an embedded-IPA workflow

For an embedded build, place the dylib under the app's `Frameworks` directory, add
`@executable_path/Frameworks/IsaacDebugConsole.dylib` as an `LC_LOAD_DYLIB`, and re-sign the
entire app in inside-out order. No private entitlement, JIT, or unsigned executable memory is
used.

## Safety and limitations

Debug commands can change a run and its save state. Back up the Isaac application container
before using mutation commands. `rewind` deliberately has the same room-state implications as
using Glowing Hourglass and is not an undo button for arbitrary console commands. Generic entity
spawning is constrained to native entity types 2 through 1000, but invalid game-level
type/variant combinations can still behave unexpectedly. Catalog names are derived at runtime
from Isaac's bundled `items.xml` and `pocketitems.xml`; no copyrighted game database is
redistributed.

See [docs/NATIVE_LAYOUT.md](docs/NATIVE_LAYOUT.md) for the verified executable layout.

## License

MIT
