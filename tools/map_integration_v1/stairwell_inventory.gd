extends SceneTree
## Read-only inventory of actively rendered geometry above the house stairwell.
func _initialize()->void:call_deferred("run")
func run()->void:
 var game:Node3D=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 20:await process_frame
 var world:Node3D=game.neighborhood
 world.active=true
 world.visible=true
 game.session_paused=false
 game.tutorial_active=false
 game.daily_report_pending=false
 if not game.has_node("BasementExpansion"):game._install_map_update()
 var basement:Node=game.get_node("BasementExpansion")
 if world.physics_body!=null:
  world.physics_body.stop()
  world.physics_body.global_position=Vector3(43.8,0.03,-7.9)
 game.camera.global_position=Vector3(40.3,1.55,-7.35)
 game.camera.look_at(Vector3(43,-0.7,-10.75))
 for i in 6:await process_frame
 var hole:Rect2=basement.HOLE
 var center:=hole.get_center()
 print("STAIR_VIEW house=",world.active," neighborhood_visible=",world.visible," neighborhood_transform=",world.global_transform," hole=",hole," cut_count=",basement.cut_count)
 var count:=0
 var center_materials:Array[String]=[]
 var all_nodes:Array[Node]=root.find_children("*","MeshInstance3D",true,false)
 for v in all_nodes:
  var n:MeshInstance3D=v as MeshInstance3D
  if n==null or n.mesh==null:continue
  var bb:=n.global_transform*n.get_aabb()
  var fp:=Rect2(Vector2(bb.position.x,bb.position.z),Vector2(bb.size.x,bb.size.z))
  var in_hole:bool=fp.intersects(hole)
  var huge:bool=bb.size.x>8.0 and bb.size.z>8.0 and bb.position.y<1.0 and bb.end.y> -5.0
  if not in_hole and not huge:continue
  var rendered:bool=n.is_visible_in_tree() and ((n.layers & game.camera.cull_mask)!=0)
  var material:Material=n.material_override
  if material==null and n.mesh.get_surface_count()>0:material=n.mesh.surface_get_material(0)
  var mat_desc:="null" if material==null else material.get_class()
  if material is ShaderMaterial:
   var m:ShaderMaterial=material as ShaderMaterial
   mat_desc+=" finish="+str(m.get_shader_parameter("finish"))+" tint="+str(m.get_shader_parameter("tint"))
  elif material is StandardMaterial3D:
   var m:StandardMaterial3D=material as StandardMaterial3D
   mat_desc+=" color="+str(m.albedo_color)
  var item:="shown="+str(rendered)+" name="+str(n.name)+" bounds="+str(bb)+" layers="+str(n.layers)+" material="+mat_desc+" parent="+str(n.get_parent().name)
  if huge:print("STAIR_HUGE ",item)
  if in_hole and fp.has_point(center) and bb.position.y<1 and bb.end.y> -5:
   center_materials.append("STAIR_CENTER "+item)
   count+=1
 for s in center_materials:print(s)
 var checked:int=0
 for node in world.get_children():
  if not node is MultiMeshInstance3D:continue
  var scatter:MultiMeshInstance3D=node as MultiMeshInstance3D
  var mm:MultiMesh=scatter.multimesh
  if mm==null or mm.mesh==null:continue
  checked+=1
  var bb:AABB=mm.mesh.get_aabb()
  var material:Material=mm.mesh.surface_get_material(0) if mm.mesh.get_surface_count()>0 else null
  var overlap_count:int=0
  var examples:Array[String]=[]
  for idx in mm.instance_count:
   var t:Transform3D=scatter.global_transform*mm.get_instance_transform(idx)
   var world_bounds:AABB=t*bb
   var footprint:=Rect2(Vector2(world_bounds.position.x,world_bounds.position.z),Vector2(world_bounds.size.x,world_bounds.size.z))
   if footprint.intersects(hole) and world_bounds.position.y < .5 and world_bounds.end.y> -1.0:
    overlap_count+=1
    if examples.size()<8:examples.append(str(idx)+":"+str(t.origin)+"/"+str(world_bounds.size))
  print("STAIR_MULTIMESH path=",scatter.get_path()," count=",mm.instance_count," visible=",mm.visible_instance_count," base_bounds=",bb," world_bounds=",scatter.get_aabb()," material=",str(material)," overlaps=",overlap_count," sample=",examples)
  if mm.instance_count==1:
   var transform:Transform3D=mm.get_instance_transform(0)
   print("STAIR_SINGLE_MESH node_transform=",scatter.global_transform," local_instance=",transform," derived_world_bounds=",scatter.global_transform*transform*bb)
   var override_material:Material=scatter.material_override
   print("STAIR_SINGLE_MATERIAL class=",str(override_material.get_class()) if override_material else "<null>"," id=",str(override_material))
   if override_material is ShaderMaterial:
    var sm:ShaderMaterial=override_material as ShaderMaterial
    print("STAIR_SINGLE_SHADER path=",str(sm.shader.resource_path)," finish=",str(sm.get_shader_parameter("finish"))," tint=",str(sm.get_shader_parameter("tint")))
   var source:String=world.get_script().source_code
   var cursor:int=source.find("MultiMesh")
   while cursor>=0:
    print("STAIR_MULTIMESH_SOURCE ",source.substr(maxi(0,cursor-500),min(1150,source.length()-maxi(0,cursor-500))))
    cursor=source.find("MultiMesh",cursor+9)

 print("STAIR_MULTIMESH_DIAG_COMPLETE count=",checked)
 print("STAIR_RENDER_DIAG_COMPLETE center_count=",count," meshes=",all_nodes.size())
 game.queue_free()
 await process_frame
 quit()
