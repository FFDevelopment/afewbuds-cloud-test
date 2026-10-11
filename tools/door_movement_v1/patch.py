"""Patch house door movement into the assembled mobile Godot source without changing saves."""
import json,re
from pathlib import Path
HERE=Path(__file__).parent
SPEC=json.loads((HERE/"functions.json").read_text())
def replace_function(source,name,body):
    match=list(re.finditer(r"^func "+re.escape(name)+r"\([^\n]*\)[ \t]*(?:->[\t ]*[^\n:]+)?:\n.*?(?=^func |^var |^const |\Z)",source,re.M|re.S))
    if len(match)!=1:raise AssertionError("Missing or duplicate door movement function: "+name)
    a=match[0]
    return source[:a.start()]+body.rstrip()+"\n\n"+source[a.end():]
def insert_function(source,name,body):
    if re.search(r"^func "+re.escape(name)+r"\(",source,re.M):raise AssertionError("Duplicate door movement function: "+name)
    marker="func generic_manager_instance("
    at=source.find(marker)
    if at<=0 or source[at-1]!="\n":raise AssertionError("Missing crew phone helper anchor")
    return source[:at]+body.rstrip()+"\n\n"+source[at:]
def apply_entries(entries):
    output=[]
    patched=False
    for path,data,flags in entries:
        if path=="scripts/crew_phone.gd":
            if patched:raise AssertionError("Duplicate crew phone output")
            patched=True
            source=data.decode()
            old="var manager_node: Node3D"
            if source.count(old)!=1:raise AssertionError("Missing door manager field")
            source=source.replace(old,old+"\nvar house_approach_cache:Dictionary={}",1)
            for name,body in SPEC["modified"].items():
                source=replace_function(source,name,body)
            anchor="func generic_manager_instance("
            if source.count(anchor)!=1:raise AssertionError("Missing generic manager anchor")
            source=source.replace(anchor,SPEC["constants"].strip()+"\n\n"+anchor,1)
            for name,body in SPEC["added"].items():
                source=insert_function(source,name,body)
            data=source.encode()
        output.append([path,data,flags])
    if not patched:raise AssertionError("Missing assembled crew phone")
    return output
