# Kobi NPC v1

Kobi uses the AFewBuds shared 56-bone skeleton at the same approximately 2.35-unit
height as Malik and Rod. Fuller torso, beard, pulled-back curly hair, plain white
crewneck, khaki trousers and original light sneakers follow the supplied artwork.
One mesh/material, 21,362 triangles, 2K color atlas, maximum four weights per vertex.
Idle, walk, bend-test and sit clips are included. These are the existing prototype
animation style; new dialogue, AI routines and recruitment rules are not added.

Cloud-test release `.98-kobi.1` replaces Kobi's generic visual when he appears as
an existing customer visitor, production worker or assigned apartment door manager.
His appearances follow existing save/progression rules; he is not always spawned
in the park. The outdoor review images are staging views for inspecting the model.

The runtime patch changes only `scripts/crew_phone.gd` and adds Kobi's GLB/PNG.
All 217 other entries, including the police/park repairs from `.97-police.3`, are
byte-identical. No save-schema changes. Kobi adds about 3.6 MB of uncompressed
startup assets; this is a file-size observation, not an FPS benchmark.

Validation: exact rig/inverse-bind/weight/normal/triangle contract; native Godot
rig and seated-fit checks; 37 integration checks for all three characters, visitor
and worker swaps, Kobi manager, and seated/standing/walking transitions; verified
browser pack reconstruction. Four native game renders reviewed.

Rebuild runtime from the repository root:
`python -B tools/kobi_v1/build.py --output-dir <new-scratch-directory>`
Then run `tools/kobi_v1/check.gd` inside the extracted candidate with Godot 4.7.2.
The extracted validation project uses a separate save namespace.

The downloadable source package contains `source/Kobi.blend`, the portable
`source/build_kobi.py`, the master-rig contract and the exported Godot assets.
Open `godot/project.godot` to review the four clips. To rebuild the model, run
Blender 4.1 in background mode with `--python source/build_kobi.py`; the builder
uses the included contract and writes the model, atlas and preview renders.
The GLB is the runtime animation authority; the Blender file is the editable mesh
and armature authoring scene. The static sit clip is assembled during GLB export.
