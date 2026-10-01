# Isaac Debug Console iOS

An in-game debug console for the native iOS release of *The Binding of Isaac: Rebirth +
Repentance*. It provides a compact UIKit console, live command suggestions, command history,
and a small set of native run-inspection and item commands.

This is an independent project inspired by the console experience provided by
[REPENTOGON](https://github.com/TeamREPENTOGON/REPENTOGON). It does not contain or copy
REPENTOGON code and is not affiliated with its developers, Nicalis, Edmund McMillen, Apple,
or Valve.

## Interface

Pause an active run. A **Console** button appears in the lower-left corner. The overlay does
not create another window, so touches outside the panel continue to reach Isaac. Start typing
to see suggestions; tap a suggestion to complete it.

Available commands:

- `help [command]` — list commands or show usage
- `status` — bridge, executable, run, and catalog status
- `seed` — current native run seed
- `room` — current room type
- `position` / `pos` — player type and coordinates
- `inventory` / `inv` — owned collectible IDs, names, and counts
- `items <name|id>` / `find` — search the game's collectible catalog
- `giveitem <cID|name>` / `g` — add a collectible through Isaac's native player function
- `remove <cID|name>` / `r` — remove one collectible through Isaac's native player function
- `history`, `clear`, `version`, `close`

`giveitem` and `remove` are allowed only while a run is paused. Native addresses, the Isaac
Mach-O UUID, the player RTTI/vtable, and function prologues are validated before a mutation.

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
before using mutation commands. The first release intentionally implements a small verified
command set rather than pretending that the desktop Lua/REPENTOGON command surface exists on
iOS. Item names are derived from Isaac's bundled `items.xml`, so no copyrighted game database
is redistributed.

See [docs/NATIVE_LAYOUT.md](docs/NATIVE_LAYOUT.md) for the verified executable layout.

## License

MIT
