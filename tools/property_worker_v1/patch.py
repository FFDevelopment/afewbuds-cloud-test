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
            data=src.encode("utf-8")
            seen.add(name)
        updated.append([name,data,flags])
    if seen!=set(HUNKS):
        raise AssertionError(f"missing worker patch targets: {set(HUNKS)-seen}")
    updated.append(["scripts/property_production_crew.gd",(HERE/"property_production_crew.gd").read_bytes(),0])
    return updated
