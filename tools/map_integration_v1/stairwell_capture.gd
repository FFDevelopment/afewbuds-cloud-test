extends SceneTree
## Visual binary search for the neighborhood mesh masking the house basement stairs.
func _initialize()->void:call_deferred("run")
func snapshot(game:Node3D,tag:String)->void:
 var img:Image=await grab(game)
 var jpeg:PackedByteArray=img.save_jpg_to_buffer(.73)
 var b64:String=Marshalls.raw_to_base64(jpeg)
 print("STAIR_JPEG_BEGIN ",tag," bytes=",jpeg.size())
 for i in range(0,b64.length(),4000):print("STAIR_JPEG_CHUNK ",tag," ",b64.substr(i,4000))
 print("STAIR_JPEG_END ",tag)
func grab(game:Node3D)->Image:
 for i in 3:await RenderingServer.frame_post_draw
 var img:Image=game.get_viewport().get_texture().get_image()
 img.resize(700,394,Image.INTERPOLATE_BILINEAR)
 return img
func vector_signature(img:Image)->PackedFloat32Array:
 var sig:=PackedFloat32Array()
 for p in [Vector2i(310,155),Vector2i(395,160),Vector2i(300,222),Vector2i(405,220),Vector2i(340,120),Vector2i(430,115)]:
  var c:Color=img.get_pixelv(p)
  sig.append(c.r);sig.append(c.g);sig.append(c.b)
 return sig
func metric(a:PackedFloat32Array,b:PackedFloat32Array)->float:
 var result:=0.0
 for i in a.size():result+=absf(a[i]-b[i])
 return result
func describe(n:Node3D)->String:
 return str(n.get_path())+" class="+str(n.get_class())+" children="+str(n.get_child_count())
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
 game.camera.global_position=Vector3(42.9,3.4,-10.95)
 game.camera.look_at(Vector3(42.9,-3.5,-10.95),Vector3.BACK)
 var baseline:PackedFloat32Array=vector_signature(await grab(game))
 await snapshot(game,"baseline")
 var meshes:Array[Node3D]=[]
 for n in world.get_children():
  if n is Node3D and not n is MeshInstance3D and not n is Light3D and n.visible:meshes.append(n)
 print("STAIR_BINARY_BEGIN world_direct_groups=",meshes.size())
 for n in meshes:n.visible=false
 var invisible:PackedFloat32Array=vector_signature(await grab(game))
 print("STAIR_BINARY_DIRECT_DELTA=",metric(baseline,invisible))
 await snapshot(game,"hide_world_direct_groups")
 for n in meshes:n.visible=true
 var candidates:=meshes.duplicate()
 if metric(baseline,invisible)>.25:
  for iteration in 17:
   if candidates.size()<=1:break
   var half:int=int(candidates.size()*.5)
   var left:Array[Node3D]=candidates.slice(0,half)
   var right:Array[Node3D]=candidates.slice(half)
   for n in meshes:n.visible=true
   for n in left:n.visible=false
   var result:PackedFloat32Array=vector_signature(await grab(game))
   var del:float=metric(baseline,result)
   var score:float=metric(result,invisible)
   var changed:bool=del > metric(baseline,invisible)*.30
   print("STAIR_BINARY iteration=",iteration," group=",left.size()," of=",candidates.size()," delta=",del," no_world_dist=",score," chose_left=",changed)
   candidates=left if changed else right
  if candidates.size()==1:
   print("STAIR_BINARY_SUSPECT ",describe(candidates[0]))
   for n in meshes:n.visible=true
   candidates[0].visible=false
   await snapshot(game,"suspect_hidden")
 else:
  print("STAIR_BINARY_NOT_DIRECT")
 print("STAIR_BINARY_COMPLETE")
 game.queue_free()
 await process_frame
 quit()
