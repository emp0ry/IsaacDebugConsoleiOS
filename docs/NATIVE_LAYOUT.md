# Supported native layout

The mutation bridge is deliberately fail-closed. It enables native commands only for the
Isaac arm64 executable with Mach-O UUID `F4357753-A25F-30EE-BACF-63709F902895`.

Verified runtime values:

- game singleton pointer RVA: `0xAC3B90`
- current room: `Game + 0x21550`
- run seed: `Game + 0x25D44`
- pause state: `Game + 0x10DFD8`
- player collectible table pointer: `Player + 0x1AB8`
- `Entity_Player::AddCollectible` RVA: `0x500588`
- `Entity_Player::RemoveCollectible` RVA: `0x5051E0`

Both native function entry points are checked against their expected ARM64 prologues before
each mutation. The player pointer is resolved by RTTI/vtable validation instead of assuming a
fixed player-vector offset. Unsupported executables retain the UI and diagnostic status, but
mutation remains disabled.
