# Isaac Debug Console for iOS

A native in-game debug console for **The Binding of Isaac: Rebirth + Repentance on iOS**.
It adds a touch-friendly UIKit console with live suggestions and useful run, inventory, spawn,
and room-state commands without requiring Isaac's desktop Lua mod API.

The same ARM64 dylib supports rootless jailbreak injection, LiveContainer private apps, and
direct app-bundle embedding. The core dylib uses only Apple system frameworks; ElleKit is used
only by the optional jailbreak package as a loader.

<img width="1434" height="660" alt="IMG_6484" src="https://github.com/user-attachments/assets/0a87235b-fcad-4f1b-916a-debff5253cb6" />

## Download

Download the current build from [GitHub Releases](https://github.com/emp0ry/IsaacDebugConsoleiOS/releases/latest).

| Installation | Release file |
| --- | --- |
| Rootless jailbreak with ElleKit | `IsaacDebugConsole-rootless.deb` |
| LiveContainer private app | `IsaacDebugConsole-LiveContainer.framework.zip` |
| Embedded/non-jailbroken app | `IsaacDebugConsole-Embedded.zip` |
| Advanced/manual setup | `IsaacDebugConsole-Full-Build.zip` |

A standalone `IsaacDebugConsole.dylib` and `SHA256SUMS` are also included. No Isaac IPA,
game executable, save data, DLC, or copyrighted game database is distributed.

## Interface

Pause an active run and a **Console** button appears in the lower-left corner. It automatically
hides during gameplay and outside a run. The overlay contains:

- Live command and catalog suggestions
- Tap-to-complete results
- Scrollable command output
- Session command history with up/down controls
- A separate keyboard hide/show arrow
- A **Run** button and Return-key execution

The overlay is attached to Isaac's existing window rather than creating a second app window.
Touches outside the console continue to reach the game.

## Commands

| Command | Description |
| --- | --- |
| `help [command]` | List commands or show detailed usage |
| `status` | Show executable, native bridge, run, and catalog status |
| `seed` | Show the current native run seed |
| `room` | Show the current native room type |
| `position` / `pos` | Show player type and coordinates |
| `inventory` / `inv` | List owned collectibles with names and counts |
| `items <name\|id>` / `find` | Search collectibles |
| `trinkets [name\|id]` | List or search trinkets |
| `cards [name\|id]` | List or search cards |
| `runes [name\|id]` | List or search runes and Soul Stones |
| `pilleffects [name\|id]` / `pills` | List or search pill effects |
| `giveitem <cID\|name>` / `g` | Give a collectible through Isaac's native player function |
| `remove <cID\|name>` / `r` | Remove one collectible |
| `spawn <type.variant.subtype>` / `s` | Spawn a supported native entity beside the player |
| `spawnpickup <variant.subtype>` / `pickup` | Spawn a pickup |
| `spawnitem <cID\|name>` / `si` | Spawn a collectible pedestal |
| `spawntrinket <tID\|name>` / `st` | Spawn a trinket |
| `spawncard <ID\|name>` / `sc` | Spawn a card |
| `spawnrune <ID\|1-10\|name>` / `sr` | Spawn a rune or Soul Stone |
| `spawnpill <color\|effect> [horse]` / `sp` | Spawn a normal or horse pill |
| `rewind` / `hourglass` | Run Isaac's native Glowing Hourglass rewind effect |
| `history`, `clear`, `version`, `close` | Console utilities |

Examples:

```text
spawnitem sacred heart
spawntrinket curved horn
spawncard 1
spawnrune jera
spawnpill effect 2
spawnpill 7 horse
spawn 5.100.1
rewind
```

Catalog names are read at runtime from the XML files inside the installed game. Pill effects are
resolved through the current run's native pill pool, so an effect can be spawned only when the
run has assigned it a pill color.

## Compatibility

| Property | Supported value |
| --- | --- |
| Bundle identifier | `com.Nicalis.Isaac-iOS` |
| Architecture | ARM64 |
| iOS game version | `1.4` |
| Embedded game string | `Repentance v1.7.9b.J754` |
| Mach-O UUID | `F4357753-A25F-30EE-BACF-63709F902895` |
| Minimum deployment target | iOS 15.0 |

Native layouts can change between Isaac builds. An unknown executable UUID fails closed: the UI
can report the mismatch, but native modifying commands remain disabled instead of calling guessed
addresses. The supported build validates the player RTTI/vtable and every native function prologue
before mutation.

## Installation

Back up Isaac's application data before using debug commands or changing an installation.

### Rootless jailbreak

Install `IsaacDebugConsole-rootless.deb` with a package manager, or from a shell:

```sh
dpkg -i IsaacDebugConsole-rootless.deb
```

Restart Isaac afterward. The package filters injection to `com.Nicalis.Isaac-iOS`.

### LiveContainer private app

1. Extract `IsaacDebugConsole-LiveContainer.framework.zip` in Files.
2. In LiveContainer, create an app-specific tweak folder such as `IsaacConsole`.
3. Choose **Import Tweak** and select `IsaacDebugConsole.framework`.
4. Long-press Isaac, open **Settings**, and select that folder under **Tweak Folder**.
5. Keep **Don't Inject TweakLoader** and **Don't Load TweakLoader** disabled.
6. If requested, use **Force Sign** for the imported framework.

Isaac must be configured as a private app. Do not install the framework as a global tweak.

### Embedded/non-jailbroken app

Place `IsaacDebugConsole.dylib` in the app's `Frameworks` directory and add this load command to
Isaac's main executable:

```text
@executable_path/Frameworks/IsaacDebugConsole.dylib
```

Re-sign the complete application bundle in inside-out order. The dylib requires no JIT,
unsigned executable memory, private entitlement, daemon, SSH service, or jailbreak filesystem.
See [Installation](docs/INSTALL.md) for the packaging and signing details.

## Safety

Every modifying command requires a paused active run. Native entry points, game state, player
objects, and spawn context are checked before calls are made. Generic `spawn` is deliberately
limited to entity types 2 through 9 and 1000.

Debug commands still change the current run and may affect saved progress. `rewind` uses the real
Glowing Hourglass path; it is not an undo system for arbitrary console commands. Unknown or invalid
game-level type/variant combinations may be rejected by Isaac or behave unexpectedly.

## Build from source

Requirements:

- macOS with Xcode and an iPhoneOS SDK
- Python 3
- `dpkg-deb`
- `ripgrep`

Build and verify every public format:

```sh
make release
```

Release files are written to `dist/`. `make audit` checks the dylib's linked libraries and rejects
jailbreak-only dependencies.

## How it works

The project finds the supported Isaac image by Mach-O UUID and resolves the player through native
C++ RTTI and vtable validation. Read-only commands use bounded snapshots of the active Game, room,
player, inventory, seed, and item-pool state. Mutation commands invoke reverse-verified native game
functions only after the executable and function prologues match.

Spawns use the current Repentance `Game::Spawn` ABI and validated Game-owned spawn context. Rewind
uses the current `Entity_Player::UseActiveItem` implementation with collectible 422 (Glowing
Hourglass). Verified details are documented in [Native layout](docs/NATIVE_LAYOUT.md).

## Credits and legal

Inspired by the desktop debug-console experience and
[REPENTOGON](https://github.com/TeamREPENTOGON/REPENTOGON). This project contains no REPENTOGON
code and is not affiliated with its developers, Nicalis, Edmund McMillen, Apple, or Valve.

No game application, DLC, purchase bypass, save file, or game asset database is included. The
project source is available under the [MIT License](LICENSE).
