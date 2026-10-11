"""Release-critical house packaging and basement corrections.
Run after geometry and staff patches. Never override unrecognized mobile source.
"""
import json
from pathlib import Path
HERE=Path(__file__).parent
HUNKS=json.loads((HERE/"hunks.json").read_text(encoding="utf-8"))
def apply_entries(entries):
    result=[]
    matched=set()
    for path,data,flags in entries:
        if path in HUNKS:
            source=data.decode("utf-8")
            for i,change in enumerate(HUNKS[path]):
                old=change["before"]
                count=source.count(old)
                if count!=1:
                    raise AssertionError(f"House packing parity drift: {path}, hunk {i}, source line {change['line']}, matches={count}, anchor={old[:110]!r}")
                source=source.replace(old,change["after"],1)
            data=source.encode("utf-8")
            matched.add(path)
        result.append([path,data,flags])
    assert matched==set(HUNKS),f"Missing house packing runtime scripts: {set(HUNKS)-matched}"
    return result
