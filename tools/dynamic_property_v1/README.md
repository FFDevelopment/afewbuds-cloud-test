# AFewBuds dynamic property registry — mobile candidate

The canonical gameplay registry is
`FFDevelopment/afewbuds-3d-prototype/game/scripts/property_registry.gd`.
Its contents are mirrored in `tools/dynamic_property_v1/property_registry.gd`
and checked byte-for-byte by `.github/workflows/dynamic-property-v1.yml`.

The mobile candidate generator includes this module at
`res://scripts/property_registry.gd`, then enables compatibility-based
lookup from the existing furniture model.

**No player save reset or public publishing happens on this branch.**
The `apartment` and `house` IDs stay unchanged. The new
`location_state.property_registry` document supplements — does not replace —
stored furniture, inventories, utility balances, staff assignments and
property payments.

New property IDs may be generated without knowing their final names, but
the existing computers, worker navigation, grow panels and utilities still
have legacy house/apartment-specific implementation. New properties are not
fully playable until those systems are converted and tested.

See the corresponding shared-core development document in the desktop
prototype for rollout and migration requirements.
