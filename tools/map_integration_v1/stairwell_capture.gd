extends SceneTree
func _initialize()->void:call_deferred("run")
func snapshot(game:Node3D, tag:String)->void:
 for i in 7:await RenderingServer.frame_post_draw
 var img:Image=game.get_viewport().get_texture().get_image()
 if img==null or img.get_width()<16 or img.get_height()<16:
  print("STAIR_CAPTURE_FAILED ",tag," ",str(img))
  return
 img.resize(700,394,Image.INTERPOLATE_BILINEAR)
 var jpg:PackedByteArray=img.save_jpg_to_buffer(0.75)
 var encoded:String=Marshalls.raw_to_base64(jpg)
 print("STAIR_JPEG_BEGIN ",tag," w=",img.get_width()," h=",img.get_height()," bytes=",jpg.size())
 for idx in range(0,encoded.length(),4000):
  print("STAIR_JPEG_CHUNK ",tag," ",encoded.substr(idx,4000))
 print("STAIR_JPEG_END ",tag)
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
 game.pause_overlay.hide()
 game.tutorial_panel.hide()
 game.daily_report_panel.hide()
 game.phone_panel.hide()
 world.set_process(false)
 game.set_process(false)
 world.physics_body.stop()
 world.physics_body.set_physics_process(false)
 game.camera.current=true
 game.camera.environment=world.outdoor_environment
 game.camera.global_position=Vector3(40.3,1.75,-7.35)
 game.camera.look_at(Vector3(43.0,-0.8,-10.85),Vector3.UP)
 game.camera.global_position=Vector3(42.9,3.4,-10.95)
 game.camera.look_at(Vector3(42.9,-3.5,-10.95),Vector3.BACK)
 await snapshot(game,"baseline")
 var shader_mats:Array[ShaderMaterial]=[]
 for item in game.find_children("*","MeshInstance3D",true,false):
  var n:MeshInstance3D=item as MeshInstance3D
  var mat:Material=n.material_override
  if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("finish")==4 and mat not in shader_mats:
   shader_mats.append(mat)
 var tint_before:Array[Color]=[]
 for mat in shader_mats:
  tint_before.append(mat.get_shader_parameter("tint"))
  mat.set_shader_parameter("tint",Color.MAGENTA)
 print("STAIR_RENDER_PASS gravel_materials=",shader_mats.size())
 await snapshot(game,"pink_gravel")
 for i in shader_mats.size():shader_mats[i].set_shader_parameter("tint",tint_before[i])
 var basement:Node3D=game.get_node("BasementExpansion")
 var lower_floor:Array[MeshInstance3D]=[]
 for item in basement.get_children():
  if not item is MeshInstance3D:continue
  var n:MeshInstance3D=item as MeshInstance3D
  var b:AABB=n.global_transform*n.get_aabb()
  if b.position.y< -3.95 and b.size.x>10 and b.size.z>10:
   lower_floor.append(n)
   n.visible=false
 print("STAIR_RENDER_PASS lower_floor_meshes=",lower_floor.size())
 await snapshot(game,"no_lower_floor")
 for n in lower_floor:n.visible=true
 world.visible=false
 await snapshot(game,"no_neighborhood")
 world.visible=true
 var all_ground:Array[MeshInstance3D]=[]
 for item in basement.get_children():
  if not item is MeshInstance3D:continue
  var n:MeshInstance3D=item as MeshInstance3D
  var b:AABB=n.global_transform*n.get_aabb()
  if b.size.y<=.4 and b.size.x>1.8 and b.size.z>1.0 and b.position.y> -4.2 and b.position.y<.1:
   all_ground.append(n)
   n.visible=false
 print("STAIR_RENDER_PASS structural_floor_meshes=",all_ground.size())
 await snapshot(game,"no_basement_floor_panels")
 for n in all_ground:n.visible=true
 game.queue_free()
 await process_frame
 quit()
