Open the console directly from gameplay with the grave/backtick key. Isaac's
native pause menu and audio handling are used automatically.

## Keyboard and pause

- Close with backtick, Esc or the close button. Resume only when the console
  itself paused this same run. An already paused run stays paused.
- Coordinate Esc with Isaac Fixes 0.3.1 so a single press cannot both close
  the console and toggle the game pause again, regardless of mod load order.
- Ignore held-key repeats and modified shortcuts. Keep normal Esc behavior
  when the console is closed and leave other text fields alone.
- Disable opening and modifying commands during transitions or cinematics;
  keep native function-signature, player, run and pending-action checks.

## Full-window interface

- Fill the game window instead of using the old 760 x 390 panel limit.
- Follow window resizing, safe areas and the software keyboard. Use larger
  console text and controls on macOS / PlayCover.
- Retain command history, autocomplete, touch access, restart/rs, spawning,
  inventory and rewind. No other mod is required for the console to work.

Host checks cover UIKit and Mac key routing in both monitor orders, pause
ownership, same-run resume, fullscreen layout, commands and source contracts.
Native entry points are checked against the supported user-owned executable.
The test builds were installed in PlayCover; exhaustive physical iPhone,
LiveContainer and cutscene coverage is not claimed.

Use the PlayCover dylib for Mac and the ordinary iOS package/framework on
iPhone. Fully restart Isaac after updating. Saves and game files are not
included in these downloads.
