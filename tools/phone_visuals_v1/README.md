# In-game phone visual parity

This layer ports the approved AFewBuds phone preview into the live Godot UI.
It runs after the property phone gameplay patches and preserves mobile pause,
touch scrolling, authentication, inventory and property action adapters.

`phone_visuals.gd` is shared byte-for-byte with desktop `game/scripts/phone_visuals.gd`.
`visuals.patch.json` contains context-checked desktop changes to main and location
operations. The mobile layout adapter delegates handset sizing to the shared
390 × 805 logical canvas instead of stretching the panel across the viewport.

Home uses a three-column grid, live property/crew/bill information, and Help,
Settings and Save & Session shortcuts. Stock stays inside its selected property.
The bottom back action closes the handset from Home and follows existing back
navigation on other screens. Mobile retains its pause shortcut.

Visual QA: run desktop `prototype/phone_visual_capture.gd` with a real rendering
backend and an isolated XDG_DATA_HOME. Pass an output directory after `--`.
The same script supports the mobile candidate and captures at 720 × 1280.
