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
 world.physics_body.stop()
 world.physics_body.set_physics_process(false)
 game.camera.current=true
 game.camera.environment=world.outdoor_environment
 game.camera.global_position=Vector3(40.3,1.75,-7.35)
 game.camera.look_at(Vector3(43.0,-0.8,-10.85),Vector3.UP)
 await snapshot(game,"stair_angled")
 game.camera.global_position=Vector3(42.9,3.4,-10.95)
 game.camera.look_at(Vector3(42.9,-3.5,-10.95),Vector3.BACK)
 await snapshot(game,"stair_topdown")
 game.queue_free()
 await process_frame
 quit()
