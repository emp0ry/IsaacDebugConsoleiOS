# Isaac Debug Console iOS v0.3.0

First public release of the native Isaac debug console for iOS.

## Highlights

- Touch-friendly in-game UIKit console shown while an active run is paused
- Live command suggestions, catalog lookup, history, and keyboard controls
- Native run status, seed, room, position, and inventory inspection
- Give and remove collectible commands
- Native spawning for collectibles, trinkets, cards, runes, Soul Stones, and pills
- Pill-effect lookup through the current run's native ItemPool mapping
- Glowing Hourglass-based `rewind` using the verified current Repentance function and ABI
- Portable dylib with no jailbreak-runtime dependency
- Rootless ElleKit, LiveContainer private-app, and embedded app-bundle packages
- Fail-closed UUID, RTTI/vtable, function-prologue, Game, room, and spawn-context validation

## Compatibility

This release targets the native iOS 1.4 ARM64 executable with embedded game string
`Repentance v1.7.9b.J754` and Mach-O UUID
`F4357753-A25F-30EE-BACF-63709F902895`.

No Isaac IPA, game executable, DLC, save data, or copyrighted game database is included.
