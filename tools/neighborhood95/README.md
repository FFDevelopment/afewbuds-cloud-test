# .95 supplied characters, fitted couch and apartment header

Malik v1.6 and Rod v1.4 replace the old runtime GLBs at their supplied physical scale (~2.35 units). Both keep the 56-bone rig and idle/walk/sit/bend clips. The included material-wrapper atlases are applied with the supplied roughness and double-sided settings, via runtime PNG loading. Visitors, production roles and assigned door-manager roles use the shared character cache.

Couch v1 replaces the apartment procedural couch, preserving its anchor and footprint while lowering the fitted seat to 0.46821849. Its included walnut texture is loaded privately rather than replacing shared room textures. Source bytes, uploaded manifests and provenance retained under assets; runtime adapter changes only the walnut loading path. Sit animations use floor-level roots and the supplied cushion positions; leaving sit resets bone poses before idle/walk to account for runtime GLTF import omitting constant reset tracks. Player sit/stand and existing staff behavior retained.

Apartment FrontWallHeader now uses the same painted-wall texture, tint, UV settings and roughness as adjacent wall segments.

All uploaded manifest hashes verified (8 couch, 33 Malik, 37 Rod files). Native tests verify actual imported rig/material/scale, skinned foot grounding, pelvis/cushion contact, standing reset, visitor/worker selection, couch markers and matching header texture. Native screenshot inspected; actual JS loader reconstructs the exact complete PCK with SHA-256-checked assets. CLI canonical admission unavailable in this environment; direct manifest integrity and engine evidence retained without a canonical certification claim.
