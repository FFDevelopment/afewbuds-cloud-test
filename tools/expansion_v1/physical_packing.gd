extends Node
## Work is staged locally; authoritative inventory changes only at trim/seal completion.
var host:Node3D
var inventory:Node
var active:=false
var mode:=""
var strain:=""
var amount:=0
var progress:=0
var tool_held:=false
var saved_camera:=Transform3D.IDENTITY
var saved_fov:=75.0
var saved_aspect:=1
var surface:Node3D
var targets:Array[Node3D]=[]
var selected:=0
var layer:CanvasLayer
var bar:PanelContainer
var hint:Label
var action:Button
var actions:BoxContainer
func setup(owner:Node3D,inv:Node) -> void:
 host=owner;inventory=inv;process_priority=100
 layer=CanvasLayer.new();layer.layer=32;add_child(layer)
 bar=PanelContainer.new();bar.add_theme_stylebox_override("panel",inventory.ui_style("111713","617651"));layer.add_child(bar)
 var list:=VBoxContainer.new();bar.add_child(list)
 hint=inventory.label("",list,18)
 actions=BoxContainer.new();list.add_child(actions)
 var row:BoxContainer=actions
 inventory.button("Previous object",func():selected=posmod(selected-1,targets.size());refresh(),row)
 action=inventory.button("Use object",use_selected,row,true)
 inventory.button("Next object",func():selected=posmod(selected+1,targets.size());refresh(),row)
 inventory.button("Leave bench",close,row)
 bar.hide()
func is_open() -> bool:return active
func start(item:String) -> void:
 var category:String=inventory.category(item)
 if category not in ["raw","trimmed"]:return
 var task:String="trim" if category=="raw" else "bag"
 if not host._tutorial_can_do(task):return
 var name:String=item.get_slice("|",1)
 if host.tutorial_active and name!=host.tutorial_harvest_strain:return
 var stock:Dictionary=host.untrimmed_inventory if category=="raw" else host.trimmed_inventory
 var available:int=int(stock.get(name,0))
 if available<=0:return
 mode=task;strain=name;amount=mini(available,10 if mode=="trim" else host._packing_batch_size());progress=0;tool_held=false;selected=0
 saved_camera=host.camera.global_transform;saved_fov=host.camera.fov;saved_aspect=host.camera.keep_aspect
 inventory.close();active=true;bar.show();Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
 surface=Node3D.new();host.add_child(surface)
 var apartment:bool=inventory.operation()=="apartment"
 surface.position=Vector3(3.56,1.28,1.29) if apartment else Vector3(39.6,1.175,-4.2)
 surface.rotation.y=-PI/2 if apartment else 0
 # Reuse the bench's actual world-space position rather than rendering a second UI scene.
 prop("Scissors" if mode=="trim" else "Scoop",Vector3(-.34,.025,.18),Vector3(.2,.025,.05),"b5c3c0")
 prop("Untrimmed batch" if mode=="trim" else "Bag on scale",Vector3(0,.06,0),Vector3(.23,.1,.19),"658c43" if mode=="trim" else "c8d7c9")
 prop("Trim tray" if mode=="trim" else "Heat sealer",Vector3(.34,.025,.16),Vector3(.24,.04,.16),"777e78")
 hold_camera()
 refresh()
func hold_camera() -> void:
 if not active or surface==null:return
 host.camera.global_position=surface.global_position+surface.basis*Vector3(0,.85,1.0);host.camera.look_at(surface.global_position);host.camera.fov=70;host.camera.keep_aspect=Camera3D.KEEP_WIDTH
func prop(title:String,pos:Vector3,size:Vector3,color:String) -> void:
 var mesh:=MeshInstance3D.new();mesh.mesh=BoxMesh.new();mesh.mesh.size=size;mesh.position=pos
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=.55;mesh.material_override=mat;mesh.set_meta("no_collision",true)
 mesh.set_meta("title",title);surface.add_child(mesh);targets.append(mesh)
 decorate(mesh,title)
 var text:=Label3D.new();text.text=title;text.font_size=20;text.pixel_size=.0014;text.position=Vector3(0,.12,0);text.billboard=BaseMaterial3D.BILLBOARD_ENABLED;mesh.add_child(text)
func use_selected() -> void:
 if not active or host.session_paused:return
 if mode=="trim":
  if selected==0:tool_held=true
  elif selected==1 and tool_held:
   progress=mini(progress+1,amount)
   targets[0].position=targets[1].position+Vector3(.1,.07,0)
   if progress>=amount:commit_trim();return
 else:
  if selected==0:tool_held=true
  elif selected==1 and tool_held:progress=mini(amount,progress+host._packing_drop_size());tool_held=false
  elif selected==2 and progress>=amount:commit_bag();return
 refresh()
func commit_trim() -> void:
 var available:int=int(host.untrimmed_inventory.get(strain,0))
 var moved:int=mini(amount,available)
 if moved<=0:close();return
 host.untrimmed_inventory[strain]=available-moved
 host._add_inventory(host.trimmed_inventory,strain,moved)
 host._increment_advancement_stat("grams_trimmed",moved);host._tutorial_record("trim",-1,strain)
 host._save_game();host.status_label.text="Trimmed %dg of %s."%[moved,strain]
 close()
func commit_bag() -> void:
 var available:int=int(host.trimmed_inventory.get(strain,0))
 # A worker may change stock while we work. Never seal a partial stale batch.
 if available<amount:host.status_label.text="Stock changed. Refill the bag from the remaining batch.";close();return
 host.trimmed_inventory[strain]=available-amount
 host._add_inventory(host.bagged_inventory,strain,amount)
 host._increment_advancement_stat("bags_sealed");host._tutorial_record("bag",-1,strain)
 host._save_game();host.status_label.text="Sealed %dg of %s."%[amount,strain]
 if host.bagging_level>=3 and not host.tutorial_active and int(host.trimmed_inventory.get(strain,0))>0:
  amount=mini(int(host.trimmed_inventory[strain]),host._packing_batch_size());progress=0;tool_held=false;selected=0;refresh()
 else:close()
func refresh() -> void:
 if not active:return
 var help:="Pick up the scissors, then work across the batch." if mode=="trim" else "Pick up the scoop, fill the bag on the scale, then use the sealer."
 hint.text="%s - %dg / %dg\n%s"%[strain,progress,amount,help]
 action.text="Use "+str(targets[selected].get_meta("title"))
 for i in range(targets.size()):
  var mesh:MeshInstance3D=targets[i]
  mesh.material_override.emission_enabled=i==selected
  mesh.material_override.emission=Color("46613d")
func close(reopen:bool=true) -> void:
 if not active:return
 active=false;bar.hide();host.camera.global_transform=saved_camera;host.camera.fov=saved_fov;host.camera.keep_aspect=saved_aspect
 if surface!=null:surface.queue_free();surface=null
 targets.clear();mode="";strain="";progress=0;amount=0;tool_held=false
 host._sync_packing_bench_visuals(true)
 if reopen and not host.session_paused:inventory.return_to_packing()
func _process(_delta:float) -> void:
 if not active:return
 if host.session_paused:close(false);return
 hold_camera()
 var screen:Vector2=host.get_viewport().get_visible_rect().size
 actions.vertical=screen.x<650
 bar.size=Vector2(minf(screen.x-24,700),300 if actions.vertical else 150);bar.position=Vector2((screen.x-bar.size.x)/2,screen.y-bar.size.y-12)
func _unhandled_input(event:InputEvent) -> void:
 if not active:return
 var point:=Vector2.ZERO
 var tap:=false
 if event is InputEventScreenTouch and event.pressed:point=event.position;tap=true
 elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:point=event.position;tap=true
 if tap:
  var best:=65.0;var found:=-1
  for i in range(targets.size()):
   var distance:float=host.camera.unproject_position(targets[i].global_position).distance_to(point)
   if distance<best:best=distance;found=i
  if found>=0:selected=found;use_selected();get_viewport().set_input_as_handled()
 elif event is InputEventJoypadButton and event.pressed:
  if event.button_index in [JOY_BUTTON_DPAD_LEFT,JOY_BUTTON_DPAD_RIGHT]:selected=posmod(selected+(-1 if event.button_index==JOY_BUTTON_DPAD_LEFT else 1),targets.size());refresh()
  elif event.button_index==JOY_BUTTON_A:use_selected()
  elif event.button_index==JOY_BUTTON_B:close()
  get_viewport().set_input_as_handled()

func detail(parent:Node3D,shape:Mesh,pos:Vector3,color:String,rotation:Vector3=Vector3.ZERO) -> MeshInstance3D:
 var node:=MeshInstance3D.new();node.mesh=shape;node.position=pos;node.rotation=rotation;node.set_meta("no_collision",true)
 var mat:=StandardMaterial3D.new();mat.albedo_color=Color(color);mat.roughness=.6;node.material_override=mat;parent.add_child(node);return node
func decorate(mesh:MeshInstance3D,title:String) -> void:
 if title=="Scissors":
  mesh.mesh.size=Vector3(.17,.008,.025)
  var blade:=BoxMesh.new();blade.size=Vector3(.17,.008,.025)
  detail(mesh,blade,Vector3(0,.009,0),"c4cbcb",Vector3(0,.32,0))
  for z in [-.035,.035]:
   var ring:=TorusMesh.new();ring.inner_radius=.019;ring.outer_radius=.029;ring.rings=12;ring.ring_segments=8
   detail(mesh,ring,Vector3(-.095,0,z),"293c31")
 elif title=="Untrimmed batch":
  mesh.mesh=SphereMesh.new();mesh.mesh.radius=.06;mesh.mesh.height=.1
  for i in range(5):
   var bud:=SphereMesh.new();bud.radius=.035;bud.height=.065;bud.radial_segments=10;bud.rings=6
   detail(mesh,bud,Vector3(sin(i*2.4)*.075,.01,cos(i*2.4)*.07),"739350" if i%2==0 else "496932")
 elif title=="Scoop":
  mesh.mesh.size=Vector3(.15,.015,.025)
  var bowl:=SphereMesh.new();bowl.radius=.047;bowl.height=.025
  detail(mesh,bowl,Vector3(.095,0,0),"c0c8bf")
 elif title=="Bag on scale":
  mesh.mesh.size=Vector3(.23,.06,.22)
  var bag:=BoxMesh.new();bag.size=Vector3(.11,.13,.035)
  detail(mesh,bag,Vector3(0,.08,0),"c5d3bd")
  var seal:=BoxMesh.new();seal.size=Vector3(.12,.012,.04)
  detail(mesh,seal,Vector3(0,.15,0),"618259")
 elif title=="Heat sealer":
  var lid:=BoxMesh.new();lid.size=Vector3(.24,.025,.05)
  detail(mesh,lid,Vector3(0,.05,-.045),"b1b9ac",Vector3(.25,0,0))
