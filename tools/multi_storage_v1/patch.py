"""Apply property-wide storage ledger updates to the mobile gameplay adapters.

Desktop core source is the shared specification. Hunk context must match
exactly: never silently lose phone-touch, input, account or cloud adaptations.
"""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
FILES={"scripts/main.gd":"main_hunks.json","scripts/location_ops.gd":"location_hunks.json"}
def apply_entries(entries):
    seen=set()
    result=[]
    for name,data,flags in entries:
        if name in FILES:
            source=data.decode("utf-8")
            for index,hunk in enumerate(json.loads((HERE/FILES[name]).read_text())):
                before=hunk["before"]
                count=source.count(before)
                if count!=1:
                    raise AssertionError(f"multi-storage mobile source drift: {name}, hunk {index}, matches={count}, old_line={hunk.get('oldLine')}, anchor={before[:150]!r}")
                source=source.replace(before,hunk["after"],1)
            data=source.encode("utf-8")
            seen.add(name)
        result.append([name,data,flags])
    assert seen==set(FILES),f"Multi-storage patch missing targets: {set(FILES)-seen}"
    return result
