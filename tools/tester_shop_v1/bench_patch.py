"""Apply benchmarked equipment appearance restoration only AFTER base map hunks.
The original map patch has exact context matches; patching earlier breaks it.
"""
from pathlib import Path
HERE=Path(__file__).parent

def one(src,old,replacement,context):
    n=src.count(old)
    assert n==1,f"tester bench {context}: expected one anchor, found {n}"
    return src.replace(old,replacement,1)

def apply_entries(entries):
    helper=(HERE/"bench_helper.gdfrag").read_text()
    result=[]
    matched=set()
    for name,data,flags in entries:
        if name=="scripts/equipment_world.gd":
            source=data.decode()
            source=one(source,"func clone_legacy(root:Node3D,id:String,e:Dictionary) -> bool:\n",
                      helper+"func clone_legacy(root:Node3D,id:String,e:Dictionary) -> bool:\n","approved model helper")
            old="and not clone_cabinet(root,id,e) and not clone_legacy(root,id,e):editor.build_prop(root,id,e.sku)"
            source=one(source,old,
                     "and not clone_cabinet(root,id,e) and not clone_packing(root,id,e) and not clone_legacy(root,id,e):editor.build_prop(root,id,e.sku)",
                     "placed bench")
            source=one(source,'var legacy:Node3D=root.get_node_or_null("PackingBenchLooseBuds")',
                     'var legacy:Node3D=root.find_child("PackingBenchLooseBuds",true,false)',"nested bench props")
            data=source.encode()
            matched.add(name)
        elif name=="scripts/furniture_editor.gd":
            source=data.decode()
            old="and not equipment_world.clone_cabinet(preview_model,selected,e) and not equipment_world.clone_legacy(preview_model,selected,e):build_prop(preview_model,selected,e.sku)"
            replacement="and not equipment_world.clone_cabinet(preview_model,selected,e) and not equipment_world.clone_packing(preview_model,selected,e) and not equipment_world.clone_legacy(preview_model,selected,e):build_prop(preview_model,selected,e.sku)"
            source=one(source,old,replacement,"placement preview")
            source=one(source,
                '  var size:Vector3=model.size_of(id,int(e.get("yaw",0)))\n  var box:=AABB(Vector3(e.position[0]-size.x*.5,e.position[1],e.position[2]-size.z*.5),size)',
                '  # Ignore furniture on the opposite house floor during look selection.\n  if absf(float(e.position[1])-placement_floor())>0.8:continue\n  var size:Vector3=model.size_of(id,int(e.get("yaw",0)))\n  var box:=AABB(Vector3(e.position[0]-size.x*.5,e.position[1],e.position[2]-size.z*.5),size)',
                "floor-aware house furniture targeting")
            data=source.encode()
            matched.add(name)
        result.append([name,data,flags])
    assert matched=={"scripts/equipment_world.gd","scripts/furniture_editor.gd"},matched
    return result
