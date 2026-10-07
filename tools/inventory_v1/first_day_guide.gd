extends Node
var host:Node3D
var inventory:Node
var state:Dictionary
var card:PanelContainer
var text:Label
var start_position:=Vector3.ZERO
const STEPS:=["move","phone","backpack","harvest","order_seed","order_fertilizer","collect","plant","water","fertilize","trim","bag","carry_product","store","computer","sale"]
const TITLES:=["Find your feet","Open your phone","Check your backpack","Harvest the ready plant","Order seeds at Central Market","Order a fertilizer pack","Collect your paid orders","Plant a carried seed","Water the new plant","Use carried fertilizer","Trim your harvest","Pack the trimmed product","Take packaged product","Try your storage","Visit your computer","Make your first sale"]
func setup(owner:Node3D,controller:Node) -> void:
 host=owner;inventory=controller
 var fresh:bool=not host.loaded_existing_game
 if not host.location_state.get("first_day_guide",{}) is Dictionary:host.location_state["first_day_guide"]={}
 if not host.location_state.has("first_day_guide"):host.location_state["first_day_guide"]={}
 state=host.location_state.first_day_guide
 if state.is_empty():state.merge({"version":2,"active":false,"step":0,"events":{},"completed":false})
 state["step"]=clampi(int(state.get("step",0)),0,STEPS.size())
 host.tutorial_active=false;host.tutorial_seen=true
 host.tutorial_panel.hide()
 card=PanelContainer.new();inventory.layer.add_child(card)
 card.add_theme_stylebox_override("panel",inventory.ui_style("122018","729b51",12))
 card.mouse_filter=Control.MOUSE_FILTER_IGNORE
 text=inventory.label("",card,16);text.mouse_filter=Control.MOUSE_FILTER_IGNORE
 card.hide();start_position=host.camera.global_position
 if fresh and not bool(state.completed):host.tutorial_panel.show()
func controls() -> String:
 var input:Node=get_tree().root.get_node_or_null("DesktopInput")
 if input==null:return "Move with the left joystick; drag the view to look. Tap the bottom-right interaction button. Push the movement stick fully forward to sprint."
 return "Move with the left stick; right stick to look. L3 toggles forward sprint. %s: interact; %s: phone; %s: backpack. D-pad navigates menus; A/Cross selects." % [input.label("interact"),input.label("phone"),input.label("backpack")] if input.controller_active else "Use %s/%s/%s/%s to move and the mouse to look. Hold %s while moving forward to sprint. %s: interact; %s: phone; %s: backpack." % [input.label("forward"),input.label("left"),input.label("backward"),input.label("right"),input.label("sprint"),input.label("interact"),input.label("phone"),input.label("backpack")]
func hint(index:int) -> String:
 var input:Node=get_tree().root.get_node_or_null("DesktopInput")
 var grab:String="Hold the scissors or bud with your finger and drag" if input==null else ("Hold A/Cross and move the left stick" if input.controller_active else "Hold the left mouse button and drag")
 var hints:Array[String]=[
  controls(),
  "Open the Phone icon. Story tracks your milestones, Real Estate manages properties, and Help resumes this guide.",
  "Open Backpack. You start with 35 lb capacity. Cash has no weight; market upgrades increase the limit.",
  "Walk through the apartment's interior door into the grow room. Interact with the ready plant and choose Harvest. Your harvest goes to the packing bench.",
  "Leave through the apartment front door and enter Central Market nearby. At checkout choose Seeds, then order a base strain you can afford. Genetics-only strains must be bred.",
  "At the market choose Supplies and order a pack of 5 fertilizer for $45. The pack weighs 5 lb and waits in Order Pickup.",
  "Open Order Pickup and choose Collect All. It takes only what fits by backpack weight. Remaining paid items stay at the market for later.",
  "Return to an empty pot in your grow room. Interact and choose a seed. A carried seed is used first; you do not have to deposit it.",
  "Interact with the seedling and choose Water. Water usage is charged to this property's bill.",
  "Choose Fertilize on the growing plant. One carried fertilizer is used before stored supplies. You cannot fertilize a ready, dead or already fully boosted plant.",
  "Open the packing bench and select untrimmed product, then Trim by hand. "+grab+" across each bud.",
  "Select trimmed product at the bench, then Bag by hand. "+grab+"; release over the bag. Seal at the target weight. Better benches handle more per drop without increasing sale value.",
  "At the packing bench select packaged product, choose an amount, and Take. Product weighs exactly 1g per gram; check your remaining backpack space.",
  "Open Storage and choose Add Stock. Store some packaged product. Take it back when needed; reserved orders remain protected. Keep some in your backpack for a sale.",
  "Use the property computer for products, genetics, staff and equipment. Swipe or scroll long pages; Back and Close remain visible. The phone's Real Estate app handles property agreements.",
  "Your day is running again. Carry packaged product or list stored stock at the computer. When a customer knocks, check the peephole, answer, then Sell or offer a substitute. Carried product is used first."
 ]
 return hints[clampi(index,0,hints.size()-1)]
func start() -> void:
 state.active=true;host.tutorial_panel.hide();host.tutorial_active=false;host.tutorial_seen=true
 if int(state.step)>=STEPS.size():state.step=0;state.events={};state.completed=false
 start_position=host.camera.global_position
 host._sync_simulation_pause();host._save_game()
func skip() -> void:
 state.active=false;host.tutorial_panel.hide();host.tutorial_active=false;host.tutorial_seen=true
 host._sync_simulation_pause();host._save_game();host._schedule_next_customer(true)
func record(event:String) -> void:
 if not bool(state.get("active",false)):return
 state.events[event]=true
 var previous:int=int(state.step)
 while int(state.step)<STEPS.size() and bool(state.events.get(STEPS[int(state.step)],false)):state.step=int(state.step)+1
 if int(state.step)>=STEPS.size():state.active=false;state.completed=true;host.status_label.text="First day complete. Your operation is yours to build."
 if previous!=int(state.step):
  host._sync_simulation_pause();host._save_game()
  if not host._guide_protects_plants():host._schedule_next_customer(true)
func skip_step() -> void:
 if int(state.step)<STEPS.size():record(STEPS[int(state.step)])
func _process(_delta:float) -> void:
 if host.tutorial_panel.visible:
  var viewport:Vector2=host.get_viewport().get_visible_rect().size
  var factor:float=maxf(1.0,viewport.x/maxf(1.0,host.get_window().size.x))
  host.tutorial_panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
  host.tutorial_panel.scale=Vector2.ONE*factor
  host.tutorial_panel.size=Vector2(minf(540,viewport.x/factor-24),minf(620,viewport.y/factor-36))
  host.tutorial_panel.position=(viewport-host.tutorial_panel.size*factor)/2
 if bool(state.get("active",false)):
  if host.camera.global_position.distance_to(start_position)>2.5:record("move")
  if host.phone_open:record("phone")
  if inventory.is_open() and inventory.container_id.is_empty():record("backpack")
  if host.neighborhood.location_ops.management_allowed() and host.neighborhood.location_ops.is_open():record("computer")
 var shown:bool=bool(state.get("active",false)) and int(state.step)<STEPS.size() and not host._any_modal_open() and not host.session_paused
 card.visible=shown
 if not shown:return
 var size:Vector2=host.get_viewport().get_visible_rect().size
 var scale_factor:float=maxf(1.0,size.x/maxf(1.0,host.get_window().size.x))
 card.scale=Vector2.ONE*scale_factor
 card.position=Vector2(12,164)*scale_factor
 card.size=Vector2(minf(340,size.x/scale_factor-24),0)
 text.text="FIRST DAY  %d/%d - %s\n%s\nPhone > Help: details or skip" % [int(state.step)+1,STEPS.size(),TITLES[int(state.step)],hint(int(state.step))]
func populate_help(parent:Node) -> void:
 inventory.label("YOUR FIRST DAY",parent,24)
 inventory.label(controls(),parent,18)
 var resume:Button=inventory.button("RESUME GUIDE" if int(state.step)>0 and not bool(state.completed) else "START GUIDE",func():start();host._toggle_phone(),parent,true)
 if bool(state.active):
  inventory.button("SKIP THIS STEP",func():skip_step();host._refresh_phone(),parent)
  inventory.button("STOP GUIDE",func():skip();host._refresh_phone(),parent)
 for i in STEPS.size():
  inventory.label("%d. %s" % [i+1,TITLES[i]],parent,20)
  inventory.label(hint(i),parent,17)
 inventory.label("Pausing stops the day and visitors. Outside the guide, existing plants can grow while away; on-duty workers use property supplies. Rent continues for each held lease, while utilities accrue where equipment is used.",parent,17)
