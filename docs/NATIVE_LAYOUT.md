# Supported native layout

The mutation bridge is deliberately fail-closed. It enables native commands only for the
Isaac arm64 executable with Mach-O UUID `F4357753-A25F-30EE-BACF-63709F902895`.

Verified runtime values:

- game singleton pointer RVA: `0xAC3B90`
- current room: `Game + 0x21550`
- run seed: `Game + 0x25D44`
- pause state: `Game + 0x10DFD8`
- item pool: `Game + 0x242C0`
- entity factory: `Game + 0x1CF430`
- pill-effect array: `ItemPool + 0xA2C`
- player collectible table pointer: `Player + 0x1AB8`
- entity identity (`type`, `variant`, `subtype`): `Entity + 0x38`
- entity position: `Entity + 0x310`
- `Game::Spawn` RVA: `0x88FCBC`
- `Entity_Player::AddCollectible` RVA: `0x500588`
- `Entity_Player::RemoveCollectible` RVA: `0x5051E0`
- `Entity_Player::UseActiveItem` RVA: `0x580A28`
- manager singleton pointer RVA: `0xAC2428`
- native fresh-run queue RVA: `0x672568`
- Seeds copy constructor / destructor RVAs: `0x56FC54` / `0x56FCD4`

Every native function entry point is checked against its expected ARM64 prologue before each
mutation. Room entities are created through the current Repentance `Game::Spawn` path with the
same nine-argument ARM64 ABI used by the game's own call sites. The active Game object, entity
factory, and current room are validated before the call. Rewind calls the game's own active item
path with collectible 422 (Glowing Hourglass), use flags `0`, active slot `-1`, and
custom data `0`. The player pointer is resolved by
RTTI/vtable validation instead of assuming a fixed player-vector offset. Unsupported executables
retain the UI and diagnostic status, but mutation remains disabled.

Restart follows the native hold-restart completion branch (fade mode 5),
including native counter updates and an owning 0x70-byte Seeds copy. It queues
the transition for Manager::Update instead of destroying the Game from a UIKit
callback. The command accepts only the normal paused-run state, validates all
called signatures, and rejects a pending transition or unsupported context.
