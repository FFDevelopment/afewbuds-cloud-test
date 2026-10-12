"""Pair the desktop walk-around selection fix with the mobile control adapter.

Keep phone touch/ray input unchanged. Only filter installed furniture by its
owning floor and its actual wall-mounted bounding box.
"""
def apply_entries(entries):
    result=[]
    found=False
    for path,data,flags in entries:
        if path!="scripts/furniture_editor.gd":
            result.append([path,data,flags])
            continue
        source=data.decode("utf-8")
        def replace_once(before,after):
            nonlocal source
            count=source.count(before)
            if count!=1:raise AssertionError(f"Mobile mounted selection source drift: {count} matches for {before[:80]!r}")
            source=source.replace(before,after,1)
        replace_once(
            'layout_mode=true;layout_property=property_id;portfolio_property=property_id;panel.hide();layout_panel.show()',
            'layout_mode=true;layout_property=property_id;portfolio_property=property_id;property=property_id;panel.hide();layout_panel.show()')
        replace_once(
            'func refresh_layout(force:bool=false) -> void:\n',
            '''# Layout uses the currently viewed property and level, not the last edit.
# Mounted watering/air units sit above the floor and remain selectable.
func layout_floor()->float:
 return -3.8 if layout_property=="house" and host.has_node("BasementExpansion") and host.camera.global_position.y<-.5 else 0.0
func layout_same_floor(id:String,base_y:float)->bool:
 var floor_y:float=layout_floor()
 if model.wall_mountable(id) and base_y>=floor_y+.50 and base_y<=floor_y+2.75:return true
 return absf(base_y-floor_y)<=.8
func refresh_layout(force:bool=false) -> void:
''')
        replace_once(
            '''  # Furniture on another floor must not intercept walk-around selection.
  if absf(float(e.position[1])-placement_floor())>0.8:continue
  var size:Vector3=model.size_of(id,int(e.get("yaw",0)))
  var box:=AABB(Vector3(e.position[0]-size.x*.5,e.position[1],e.position[2]-size.z*.5),size)''',
            '''  # Raised wall equipment belongs to the viewed floor; never target across floors.
  if not layout_same_floor(id,float(e.position[1])):continue
  var at:=Vector3(float(e.position[0]),float(e.position[1]),float(e.position[2]))
  var box:AABB=model.occupied_box(id,at,int(e.get("yaw",0)))''')
        result.append([path,source.encode("utf-8"),flags])
        found=True
    assert found,"Mobile furniture editor is missing from staged pack"
    return result
