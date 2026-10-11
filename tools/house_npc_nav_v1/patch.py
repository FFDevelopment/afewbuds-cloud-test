"""Mirror shared house worker/door worker route changes after the full mobile game is assembled.
Do not alter account adapters, browser controls, or existing save keys.
"""
import json,re
from pathlib import Path
HERE=Path(__file__).parent
SPECS=json.loads((HERE/"functions.json").read_text())
def replace_function(source,name,body):
    pattern=re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^\n:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)
    found=list(pattern.finditer(source))
    if len(found)!=1:raise AssertionError("House nav missing or duplicated: "+name)
    match=found[0]
    return source[:match.start()]+body.rstrip()+"\n\n"+source[match.end():]
def add_function(source,name,body,anchor):
    if re.search(r"^func "+re.escape(name)+r"\(",source,re.M):
        raise AssertionError("House nav duplicate: "+name)
    tag="func "+anchor+"("
    index=source.find(tag)
    if index<0 or (index>0 and source[index-1]!="\n"):raise AssertionError("House nav anchor missing: "+anchor)
    return source[:index]+body.rstrip()+"\n\n"+source[index:]
def apply_entries(entries):
    result=[]
    patched=set()
    for path,data,flags in entries:
        key=path.rsplit("/",1)[-1]
        if path.startswith("scripts/") and key in SPECS["modified"]:
            if key in patched:raise AssertionError("Duplicate house nav script "+key)
            patched.add(key)
            source=data.decode()
            if key=="main.gd":
                old='var house_control_state: Dictionary = {}'
                if source.count(old)!=1:raise AssertionError("House nav state declaration drift")
                source=source.replace(old,old+'\nvar house_npc_navigation: RefCounted',1)
            for name,body in SPECS["modified"][key].items():
                source=replace_function(source,name,body)
            for name,body in SPECS["added"].get(key,{}).items():
                source=add_function(source,name,body,"_production_worker_navigation_target")
            data=source.encode()
        result.append([path,data,flags])
    if patched!=set(SPECS["modified"]):raise AssertionError("House nav pack missing "+str(set(SPECS["modified"])-patched))
    result.append(["scripts/house_npc_navigation.gd",(HERE/"house_npc_navigation.gd").read_bytes(),0])
    return result
