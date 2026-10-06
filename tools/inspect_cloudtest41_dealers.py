from pathlib import Path
import struct,re

P=Path("index-cloudtest10.pck")
b=P.read_bytes()
fb=struct.unpack_from("<Q",b,24)[0]
do=struct.unpack_from("<Q",b,32)[0]
n=struct.unpack_from("<I",b,do)[0]
p=do+4
wanted={"scripts/main.gd","scripts/personal_inventory.gd","scripts/touch_scroll.gd","scripts/storage_vault.gd","scripts/plant_growth.gd","scripts/offline_plant_care.gd"}
found={}
for _ in range(n):
    q=struct.unpack_from("<I",b,p)[0]; p+=4
    name=b[p:p+q].rstrip(b"\0").decode("utf-8"); p+=q
    off=struct.unpack_from("<Q",b,p)[0]; p+=8
    size=struct.unpack_from("<Q",b,p)[0]; p+=8
    p+=20
    if name in wanted:
        found[name]=b[fb+off:fb+off+size].decode("utf-8","replace").rstrip(" \n\0")
for name,text in found.items():
    Path("debug-"+name.split("/")[-1]+".txt").write_text(text+"\n")
main=found.get("scripts/main.gd","")
def fn(name):
    m=re.search(r"^func "+re.escape(name)+r"\([^\n]*\)(?: -> [^:]+)?:\n.*?(?=^func |\Z)",main,re.M|re.S)
    return m.group(0).rstrip() if m else "<MISSING>"
names=[
"_dealer_tick","_run_dealer_sale","_dealer_sale","_simulate_dealer","_total_dealer_count",
"_prepare_daily_report","_show_daily_report","_settle_daily_report","_build_employees_app",
"_build_upgrades_app","_purchase_upgrade","_storage_capacity","_available_storage_space",
"_add_to_storage","_store_packaged_product","_production_worker_process","_process_production_worker",
"_production_worker_tick","_finish_direct_station_approach","_build_storage_area","_build_living_furniture",
"_save_game","_load_game","_available_amount","_has_listed_stock"
]
out=[]
for x in names:
    out+=["===== "+x+" =====",fn(x),""]
# capture dealer-related vars/constants and likely functions list
out+=["===== DEALER/LOCKER SYMBOLS ====="]
for i,line in enumerate(main.splitlines(),1):
    low=line.lower()
    if any(k in low for k in ["dealer_","dealer ","locker","personal_inventory","production_worker","storage_level","storage_capacity"]):
        if i < 1200 or "func " in line or "const " in line or "var " in line:
            out.append(f"{i}: {line}")
out+=["===== STORAGE VAULT SCRIPT =====", found.get("scripts/storage_vault.gd","<MISSING>"), "", "===== PLANT GROWTH SCRIPT =====", found.get("scripts/plant_growth.gd","<MISSING>"), "", "===== OFFLINE PLANT CARE SCRIPT =====", found.get("scripts/offline_plant_care.gd","<MISSING>"), ""]
Path("debug-dealer-audit.txt").write_text("\n".join(out)+"\n")
print("found",sorted(found))

# trigger inspector
# inspect cloudtest51 layout runtime
# inspect cloudtest53 scale runtime

# inspect storage vault anchor for cloudtest54

# capture storage vault script in audit

# inspect cloudtest54 for room layout and kitchen55

# inspect cloudtest55 kitchen for cloudtest56 frame clearance

# inspect cloudtest58 advancement/story runtime for progression overhaul

# inspect cloudtest59 roadmap sizing for cloudtest60 phone width fix

# inspect cloudtest61 watering and utility billing for water-bill foundation

# inspect plant care water routes for cloudtest62 utility billing
