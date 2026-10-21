## Added

- Press the physical grave/backtick key (`) to open or close the console during a paused run.
- Hardware keyboard support on iOS and a local keyboard event adapter for PlayCover/Mac Catalyst.
- Held-key repeat protection so one press toggles the console once.

## Input safety

- The shortcut does not type a backtick into the command field or steal input from other text fields.
- Modified shortcuts, unrelated keys, mouse/touch input, and controller events remain untouched.
- Existing native build validation and the paused-run requirement for modifying commands remain unchanged.

Restart Isaac after updating. On PlayCover, the installed dylib must target Mac Catalyst rather
than iOS; see the installation guide. No game application or save files are included.
