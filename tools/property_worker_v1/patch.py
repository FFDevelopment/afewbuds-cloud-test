"""Apply desktop gameplay changes only after mobile movement, map and input adapters.
All source splices are asserted: never silently replace platform-specific code.
"""
import json
from pathlib import Path
HERE=Path(__file__).parent
HUNKS=json.loads((HERE/"gameplay_hunks.json").read_text(encoding="utf-8"))
def apply_entries(entries):
    seen=set()
    updated=[]
    for name,data,flags in entries:
        if name in HUNKS:
            src=data.decode("utf-8")
            for i,h in enumerate(HUNKS[name]):
                before=h["before"]
                count=src.count(before)
                if count!=1:
                    raise AssertionError(f"production/fit drift: {name}, hunk {i}, source line {h['line']}, matches={count}, preceding={before[:130]!r}")
                src=src.replace(before,h["after"],1)
            if name=="scripts/crew_phone.gd":
                # Mobile's worker animation/visitor implementation differs from
                # desktop; retain its visitor body and replace ONLY the worker
                # rig prelude with the independently scoped implementation.
                prefix="func update_malik() -> void:\n"
                visitor="\tvar visitor: String="
                start=src.find(prefix)
                if start<0:raise AssertionError("Mobile worker update entrypoint missing")
                end=src.find(visitor,start+len(prefix))
                if end<0:raise AssertionError("Mobile visitor boundary missing: cannot safely patch rigs")
                replacement=(HERE/"rig_patch.gdfrag").read_text(encoding="utf-8")
                src=src[:start]+replacement+src[end:]
            data=src.encode("utf-8")
            seen.add(name)
        updated.append([name,data,flags])
    if seen!=set(HUNKS):
        raise AssertionError(f"missing worker patch targets: {set(HUNKS)-seen}")
    updated.append(["scripts/property_production_crew.gd",(HERE/"property_production_crew.gd").read_bytes(),0])
    return updated
