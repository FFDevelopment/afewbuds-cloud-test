"""Mobile parity adapter for per-property door staff and customer taste learning.
Uses validated desktop function bodies and fails the build on missing hooks.
"""
import json,re
from pathlib import Path
SPECS=json.loads(Path(__file__).with_name("functions.json").read_text())
def replace_function(source,name,body):
    pattern=re.compile(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^\n:]+)?:\n.*?(?=^func |\Z)",re.M|re.S)
    matches=list(pattern.finditer(source))
    if len(matches)!=1:raise AssertionError("Door staffing function missing or duplicated: "+name)
    m=matches[0]
    return source[:m.start()]+body.rstrip()+"\n\n"+source[m.end():]
def add_function(source,name,body,anchor):
    if re.search(r"^func "+re.escape(name)+r"\(",source,re.M):
        raise AssertionError("Door staff added function already exists: "+name)
    start=source.find("func "+anchor+"(")
    if start<0 or (start and source[start-1]!="\n"):
        raise AssertionError("Door staffing anchor missing: "+anchor)
    return source[:start]+body.rstrip()+"\n\n"+source[start:]
ANCHORS={"main.gd":{"_customer_favorite":"_dealer_sell_one","_record_customer_strain_experience":"_dealer_sell_one","_dealer_product_amount":"_dealer_sell_one","_dealer_best_offer":"_dealer_sell_one","_substitute_acceptance_chance_for":"_show_substitutes"},"crew_phone.gd":{"recruit_door":"invite","generic_manager_instance":"character_instance"}}
def apply_entries(entries):
    result=[]
    seen=set()
    for path,data,flags in entries:
        key=path.rsplit("/",1)[-1]
        if key not in SPECS["modified"]:result.append([path,data,flags]);continue
        if not path.startswith("scripts/"):result.append([path,data,flags]);continue
        if key in seen:raise AssertionError("Duplicated script in pack: "+key)
        seen.add(key)
        source=data.decode("utf-8")
        for name,body in SPECS["modified"][key].items():
            source=replace_function(source,name,body)
        for name,body in SPECS["added"].get(key,{}).items():
            source=add_function(source,name,body,ANCHORS[key][name])
        result.append([path,source.encode("utf-8"),flags])
    missing=set(SPECS["modified"])-seen
    if missing:raise AssertionError("Door staff pack scripts missing: "+str(missing))
    return result
