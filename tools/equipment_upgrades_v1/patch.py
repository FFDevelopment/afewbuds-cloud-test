"""Apply the desktop-verified equipment progression and tight placement deltas.
Patch late in the staged web build so map, platform and bench adapters remain intact.
Every hunk is validated before rewriting; source drift must stop the build.
"""
import json
from pathlib import Path
HERE=Path(__file__).resolve().parent
FILES={
    "scripts/property_furniture.gd": "property_hunks.json",
    "scripts/furniture_editor.gd": "editor_hunks.json",
}

def apply_entries(entries):
    patches={name:json.loads((HERE/file).read_text(encoding="utf-8")) for name,file in FILES.items()}
    updated=[]
    seen=set()
    for name,data,flags in entries:
        if name in patches:
            source=data.decode("utf-8")
            for index,hunk in enumerate(patches[name]):
                old=hunk["before"]
                new=hunk["after"]
                count=source.count(old)
                if count!=1:
                    raise AssertionError(f"equipment upgrades: {name} hunk {index} has {count} matches; aborting to avoid gameplay drift")
                source=source.replace(old,new,1)
            if name=="scripts/furniture_editor.gd":
                # Mobile touch layout needs the same state declaration as desktop.
                if "var controls_active:=false" not in source:
                    marker="var layout_mode:=false"
                    assert source.count(marker)==1,"Mobile edit state anchor changed"
                    source=source.replace(marker,"var controls_active:=false\\n"+marker,1)
                # Mobile layout adapter predates desktop's force-refresh argument.
                old="func refresh_layout() -> void:\n if not inside(layout_property):close();return\n"
                new="func refresh_layout(force:bool=false) -> void:\n if not inside(layout_property):close();return\n if controls_active and not force:return\n"
                assert source.count(old)==1,"Mobile layout signature changed"
                source=source.replace(old,new,1)
            data=source.encode("utf-8")
            seen.add(name)
        updated.append([name,data,flags])
    assert seen==set(FILES),f"Missing equipment scripts: {set(FILES)-seen}"
    return updated
