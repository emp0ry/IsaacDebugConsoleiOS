# Supported native layout

The mutation bridge is deliberately fail-closed. It enables native commands only for the
Isaac arm64 executable with Mach-O UUID `F4357753-A25F-30EE-BACF-63709F902895`.

Verified runtime values:

- game singleton pointer RVA: `0xAC3B90`
- current room: `Game + 0x21550`
- run seed: `Game + 0x25D44`
- pause state: `Game + 0x10DFD8`
- item pool: `Game + 0x242C0`
- pill-effect array: `ItemPool + 0xA2C`
- player collectible table pointer: `Player + 0x1AB8`
- entity identity (`type`, `variant`, `subtype`): `Entity + 0x38`
- entity position: `Entity + 0x310`
- `Game::Spawn` RVA: `0x131080`
- `Entity_Player::AddCollectible` RVA: `0x500588`
- `Entity_Player::RemoveCollectible` RVA: `0x5051E0`
- `Entity_Player::UseActiveItem` RVA: `0x2EBE10`

Every native function entry point is checked against its expected ARM64 prologue before each
mutation. Room entities are created through `Game::Spawn`; rewind calls the game's own active
item path with collectible 422 (Glowing Hourglass). The player pointer is resolved by
RTTI/vtable validation instead of assuming a fixed player-vector offset. Unsupported executables
retain the UI and diagnostic status, but mutation remains disabled.
