"""Apply the tested house wall-face placement correction AFTER all mobile platform adapters.
Assert every hunk to avoid silently corrupting property ownership or UI scripts.
"""
import json
from pathlib import Path
HERE=Path(__file__).parent
SPECS=json.loads((HERE/"hunks.json").read_text(encoding="utf-8"))
def apply_entries(entries):
    done=set()
    result=[]
    for name,data,flags in entries:
        if name in SPECS:
            source=data.decode("utf-8")
            for index,h in enumerate(SPECS[name]):
                found=source.count(h["before"])
                if found!=1:
                    raise AssertionError(f"House Bench III wall-fit source drift: {name} hunk {index} matches={found}")
                source=source.replace(h["before"],h["after"],1)
            data=source.encode("utf-8")
            done.add(name)
        result.append([name,data,flags])
    if done!=set(SPECS):raise AssertionError(f"Missing wall-fit script(s): {set(SPECS)-done}")
    return result
