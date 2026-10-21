## Added

- `restart` and alias `rs`: queue one native fresh run with the same character
  and difficulty. Console closes after a successful request.
- Both commands appear in help and autocomplete. `help rs` shows the alias;
  invalid arguments are rejected without changing the run.
- A signed `IsaacDebugConsole-PlayCover.dylib` download for the iOS game in PlayCover.

## Native behavior

Restart requires a paused active run and verified native entry points. It uses
the game's fresh-run queue and native owning Seeds constructor/destructor, not
the R Key collectible. Acquired items are not kept. Native seed rules, Eden-token
checks, restricted-run checks and pending-transition guards remain in place.
This command does not require Isaac Drop to be installed.

Hardware grave/backtick toggling, keyboard arrows, spawning, rewind and the
existing touch console remain available. Use the PlayCover library on Mac;
use the regular library/framework for iPhone. Restart Isaac after updating.

Host command checks cover restart/rs dispatch, help, suggestions, errors,
argument rejection and closing only after success. The native restart path was
previously gameplay-confirmed through Isaac Drop; console-command gameplay
verification is still pending. Release builds verify source contracts,
signatures, dependencies and checksums. No game files or saves are distributed.
