"""Apply audited house room placement bounds after mobile-specific adapters.
Ownership coordinates and save schema remain untouched. Each replacement
is checked exactly once to catch upstream source drift before public release.
"""
import json
from pathlib import Path
HERE=Path(__file__).parent
SPECS=json.loads((HERE/"hunks.json").read_text(encoding="utf-8"))
def apply_entries(entries):
    out=[]
    seen=set()
    for name,bytes_,flags in entries:
        if name in SPECS:
            source=bytes_.decode("utf-8")
            for i,h in enumerate(SPECS[name]):
                count=source.count(h["before"])
                if count!=1:
                    raise AssertionError(f"House room bounds source drift: {name} hunk {i} matches={count}")
                source=source.replace(h["before"],h["after"],1)
            bytes_=source.encode("utf-8")
            seen.add(name)
        out.append([name,bytes_,flags])
    if seen != set(SPECS):
        raise AssertionError(f"Missing house room files: {set(SPECS)-seen}")
    return out
