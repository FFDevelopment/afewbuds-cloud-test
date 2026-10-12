extends SceneTree
## Render-test the actual mobile game scene with the house basement stairs visible.
func _initialize()->void:call_deferred("run")
func snapshot(game:Node3D,tag:String)->void:
 for i in 4:await RenderingServer.frame_post_draw
 var img:Image=game.get_viewport().get_texture().get_image()
 img.resize(700,394,Image.INTERPOLATE_BILINEAR)
 var jpg:PackedByteArray=img.save_jpg_to_buffer(.72)
 var encoded:String=Marshalls.raw_to_base64(jpg)
 print("STAIR_JPEG_BEGIN ",tag," bytes=",jpg.size())
 for i in range(0,encoded.length(),4000):
  print("STAIR_JPEG_CHUNK ",tag," ",encoded.substr(i,4000))
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
 var count:int=0
 for n in world.get_children():
  if not n is MultiMeshInstance3D:continue
  var batch:MultiMeshInstance3D=n as MultiMeshInstance3D
  var mat:Material=batch.material_override
  if mat is ShaderMaterial and (mat as ShaderMaterial).get_shader_parameter("tint") is Color:
   var tint:Color=(mat as ShaderMaterial).get_shader_parameter("tint")
   if tint.is_equal_approx(Color("c3c3b9")):
    count=batch.multimesh.instance_count
 print("STAIR_TERRAIN_BATCH_SECTIONS=",count)
 if count!=4:
  push_error("Expected four separated exterior ground sections; got "+str(count))
  quit(1)
  return
 game.camera.global_position=Vector3(40.3,1.75,-7.35)
 game.camera.look_at(Vector3(43.0,-0.8,-10.85),Vector3.UP)
 await snapshot(game,"stair_angled")
 game.camera.global_position=Vector3(42.9,3.4,-10.95)
 game.camera.look_at(Vector3(42.9,-3.5,-10.95),Vector3.BACK)
 await snapshot(game,"stair_topdown")
 print("STAIR_RENDER_CAPTURE_PASS")
 game.queue_free()
 await process_frame
 quit()
