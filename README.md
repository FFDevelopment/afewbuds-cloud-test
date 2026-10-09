# AFewBuds cloud test — playable mobile baseline

This repository's `main` branch is aligned with the gameplay source of **AFewBuds Mobile Beta 0.16.0-mobile-beta.7**.

- Pinned public-beta source commit: `866fc272a3a672210556dc85d6257ed98e5e1c0c`
- Public mobile PWA: https://ffdevelopment.github.io/afewbuds-beta/
- Cloud-test playable site: https://ffdevelopment.github.io/afewbuds-cloud-test/
- `main` is the current playable **mobile source baseline**. Its own generated test-game version strings can differ from the public-beta release number; game logic is reconstructed from the same source.
- The universal property registry is under development at `feature/dynamic-property-registry-v1`. It is deliberately **not on `main` or in the public beta**.
- The previous main baseline is preserved at `archive/pre-mobile-beta7-main-baseline`.

On pushes to `main`, the mobile candidate is reconstructed with Godot 4.7.2 and tested for movement, progression, property isolation, Reeves, inventory and equipment. Only after a successful run are generated runtime assets committed and the cloud-test site deployed. This pipeline does not publish to `afewbuds-beta`; public beta releases use their own pin-and-validate workflow.

The mobile web/PWA maintains touch controls, mobile HUD, account/session handling and its own updater. Desktop retains a separate Godot export and controls. Shared gameplay patches are developed and validated on both platforms before public releases.

**Player-protection rule:** never rename save paths or account keys, overwrite a confirmed career, reset purchases, remove property state or clear application storage during development synchronization.
