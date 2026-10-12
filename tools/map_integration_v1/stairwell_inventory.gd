extends SceneTree
# Temporary diagnosis of mobile basement visual meshes.
func _initialize()->void:call_deferred("run")
func run()->void:
 var game:Node3D=load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in 18:await process_frame
 if not game.has_node("BasementExpansion"):game._install_map_update()
 for i in 6:await process_frame
 var basement:Node=game.get_node("BasementExpansion")
 var opening:Rect2=basement.HOLE
 print("STAIR_DEBUG_BEGIN opening=",opening," cut_count=",basement.cut_count)
 var all_nodes:Array[Node]=game.find_children("*","MeshInstance3D",true,false)
 var relevant:int=0
 var active:int=0
 var by_level:Array[String]=[]
 for thing in all_nodes:
  var n:MeshInstance3D=thing as MeshInstance3D
  if n==null or n.mesh==null:continue
  var b:AABB=n.global_transform*n.get_aabb()
  var footprint:=Rect2(Vector2(b.position.x,b.position.z),Vector2(b.size.x,b.size.z))
  if not footprint.intersects(opening.grow(.15)):continue
  relevant+=1
  var shown:bool=n.is_visible_in_tree() and ((n.layers & game.camera.cull_mask)!=0)
  if shown:active+=1
  var mat:Material=n.material_override
  if mat==null and n.mesh.get_surface_count()>0:mat=n.mesh.surface_get_material(0)
  var description:="null" if mat==null else mat.get_class()
  if mat is ShaderMaterial:
   var sm:ShaderMaterial=mat as ShaderMaterial
   description+=" finish="+str(sm.get_shader_parameter("finish"))+" tint="+str(sm.get_shader_parameter("tint"))
  elif mat is StandardMaterial3D:
   description+=" color="+str((mat as StandardMaterial3D).albedo_color)
  if b.end.y < -4.1 or b.position.y > 2.5:continue
  by_level.append("STAIR_ENTRY shown="+str(shown)+" name="+str(n.name)+" path="+str(n.get_path())+" bounds="+str(b)+" layers="+str(n.layers)+" material="+description)
 by_level.sort()
 for line in by_level:print(line)
 print("STAIR_DEBUG_END count=",relevant," drawn=",active)
 game.queue_free()
 await process_frame
 quit()
