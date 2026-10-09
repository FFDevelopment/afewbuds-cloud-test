# Public release destinations

- Main public mobile: `FFDevelopment/afewbuds-beta`, https://ffdevelopment.github.io/afewbuds-beta/. Preserve its updater and existing save/session keys.
- Main public desktop distribution: `FFDevelopment/AFewBuds-Desktop-Beta`.
- This repository is for development and testing. Promote validated candidates to the public repositories. Never clear another app's service workers, caches, or saves.

# Paired desktop and mobile baseline

The user requires desktop and mobile 3D to stay current together.

- Desktop: `FFDevelopment/afewbuds-3d-prototype`, development baseline branch `main`.
- Mobile: `FFDevelopment/afewbuds-cloud-test`, development baseline branch `main`; test build published at the cloud-test root. `/mobile-3d-movement/` is a compatibility copy of that same build.
- Apply shared gameplay, progression, stamina, phone and compatible save changes to both. Preserve platform-specific input, layout, account adapters, collisions and packaging.
- Validate both implementations and published builds before reporting a paired release complete. Platform-specific fixes need not bump the unaffected platform.
- Desktop baseline is 0.13.2-preview, including the verified leaderboard upload-number fix. Mobile baseline is 0.7.9-beta.19-cloudtest.99-mobile3d.12.
- Chapter 4 can finish through property relocation and first entry. Chapter 5 has an opening/title, not a complete mission chain or finale.
- Interactive furniture editing and the proposed phone reorganization remain pending.
- Archived workflows are historical references, not current release entry points. Retain pinned packs/assets/build helpers needed to reproduce the mobile runtime.
