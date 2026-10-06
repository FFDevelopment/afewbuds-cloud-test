Cloud Test .66: texture and doorway fix

Uses the existing .65 atlas, split into nine separate GPU textures before mipmap generation, with mirrored repetition to avoid tile-edge jumps and atlas bleed. Corner buildings are set back beyond the street intersections.

The exterior now shares the apartment coordinate space. The apartment shell has a real doorway and a hollow ground floor containing the existing rooms. The door remains open or closed until toggled; no camera repositioning occurs on exit. Walking back into the entry returns the existing station controls. Door state is session-only and resets closed on reload. Career saves and Chapter 4 are unchanged.

Verified native Godot rendering, connected walking routes, both sides of the door, closed-door collision, swing clearance, modal controls, property gate and quieter notification volumes.
