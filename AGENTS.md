# AFewBuds repository roles and source-of-truth policy

## Tester releases — do not overwrite during development
- **Mobile testers:** `FFDevelopment/afewbuds-beta` (https://ffdevelopment.github.io/afewbuds-beta/). Last verified tester source baseline: `0.16.0-mobile-beta.7`, source commit `866fc272a3a672210556dc85d6257ed98e5e1c0c`.
- **Windows/Linux testers:** `FFDevelopment/AFewBuds-Desktop-Beta`. Last verified tester source baseline: `0.16.0-beta.9`, source commit `4dfdb0d4d2bce60afdc18aa0b3d460d122a33d75`.
- Never publish experimental work to these tester repos without deliberate promotion and separate full validation. Preserve live accounts, updater, client session keys, saves and GitHub Pages service workers.

## Active development/testing — always build future changes here
- **Mobile development:** `FFDevelopment/afewbuds-cloud-test/main`, playable at https://ffdevelopment.github.io/afewbuds-cloud-test/. Its successful `Build mobile baseline` workflow regenerates gameplay packs and `Deploy cloud-test baseline` publishes them. Cloud Test is a *development* environment, not the tester release.
- **Windows development:** `FFDevelopment/afewbuds-3d-prototype/main`, validated by `Build desktop baseline` with Windows/Linux artifacts. The separate `Publish desktop development test (not public beta)` workflow publishes versioned developer-test releases from passing build artifacts.
- The development `main` branches were synchronized with the playable tester source baselines before integrating the shared property and item registries. Pre-change rollback refs: `archive/before-shared-core-main-mobile` and `archive/before-shared-core-main-desktop`.
- Shared gameplay rules must be mirrored and tested across the two development repos. Mobile and desktop retain different input, UI, build/export and authentication adapters.
- The shared PropertyRegistry and ItemRegistry use the **same GDScript** in both games. The mobile core-validation workflow compares them byte-for-byte against pinned tested desktop source; update the pins when changing shared sources.
- The universal property registry and item/equipment registry are **foundations**. Arbitrary new properties still need generalized computer, inventory, grow panel, worker, billing and interaction service adapters; do not claim all future buildings are fully playable yet.

## Save/data safety
- Keep legacy `apartment` and `house` IDs unchanged, with their furniture, inventory, utilities, employee assignments, property rent/ownership and career history.
- Version additions must be additive and idempotent. Do not reset player purchases, rename save files, clear website storage, or silently reassign equipment/stock between properties.
- Never switch connected cloud career/account namespaces merely to make a development build easier. For experimental gameplay, prefer isolated test accounts and backup saves.
- Run Godot import, movement, property/isolation, item registry, inventory, Reeves/progression and exported-build QA before calling a test build clean. Release to tester repos only after explicit decision and separate verification.

## Developer workflow
1. Start from current development `main`, or a feature branch created from it.
2. Edit the shared gameplay core in the desktop project and mirror it to the mobile pack builder. Keep platform-specific integration separate.
3. Validate both projects, including old save migrations and full exported/runtime builds.
4. Push to `cloud-test/main` and `afewbuds-3d-prototype/main` for developer playtesting.
5. Promote pinned verified commits to the two tester repositories only after successful playtesting.

Chapter 4 property acquisition/relocation and Chapter 5 opening are included. Chapter 5's complete narrative and finale remain unfinished. The current game includes interactive furniture placement and the rearranged phone; do not assume old 0.13/0.7 baselines.
