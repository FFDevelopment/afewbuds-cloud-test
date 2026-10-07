"""Build an isolated cloud-test runtime that uses a CharacterBody3D for phone/web walking."""
from pathlib import Path
import argparse,base64,difflib,hashlib,importlib.util,json,re
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def module(name,path):
    spec=importlib.util.spec_from_file_location(name,path)
    m=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m

east=module('east_builder',ROOT/'tools/east_expansion_v1/build.py')

def patch_neighborhood(source:str) -> str:
    source=source.replace(
        'var couch_stand := Vector3.ZERO\n',
        '''var couch_stand := Vector3.ZERO
var physics_body: CharacterBody3D
var physics_obstacle_root: Node3D
var physics_door_body: StaticBody3D
var physics_door_shape: CollisionShape3D
var physics_obstacle_signature := ""
var stamina_bar: ProgressBar
var stamina_text: Label
var physics_ready := false
const PHYSICS_MAP:=Rect2(-32,-36,233,75)
''',1)
    assert 'var physics_body: CharacterBody3D' in source

    source=source.replace(
        '\t_build_block()\n\tweather=',
        '\t_build_block()\n\t_build_physics_walk()\n\tweather=',1)
    assert source.count('_build_physics_walk()')>=1

    physics_helpers=r'''
func _build_physics_walk() -> void:
	if physics_body!=null:return
	physics_body=load("res://scripts/mobile_physics_player.gd").new()
	physics_body.name="MobilePhysicsPlayer"
	add_child(physics_body)
	physics_obstacle_root=Node3D.new()
	physics_obstacle_root.name="MobilePhysicsObstacles"
	add_child(physics_obstacle_root)
	var ground:=StaticBody3D.new()
	ground.name="MobilePhysicsGround"
	ground.collision_layer=1
	ground.collision_mask=4
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(PHYSICS_MAP.size.x,.10,PHYSICS_MAP.size.y)
	collision.shape=box
	collision.position=Vector3(PHYSICS_MAP.get_center().x,-.05,PHYSICS_MAP.get_center().y)
	ground.add_child(collision)
	add_child(ground)
	physics_door_body=StaticBody3D.new()
	physics_door_body.name="MobilePhysicsApartmentDoor"
	physics_door_body.collision_layer=1
	physics_door_body.collision_mask=4
	physics_door_shape=CollisionShape3D.new()
	var door_box:=BoxShape3D.new()
	door_box.size=Vector3(1.88,2.96,.14)
	physics_door_shape.shape=door_box
	physics_door_shape.position=Vector3(0,1.48,5.84)
	physics_door_body.add_child(physics_door_shape)
	add_child(physics_door_body)
	_set_physics_door_closed(not door_open)
	_sync_physics_from_camera()
	physics_ready=true

func _set_physics_door_closed(solid:bool) -> void:
	if physics_door_shape!=null:physics_door_shape.set_deferred("disabled",not solid)

func _physics_rect(source:Rect2,shrink:float) -> void:
	if physics_obstacle_root==null:return
	var rect:=source.grow(-shrink)
	if rect.size.x<=.03 or rect.size.y<=.03:return
	var body:=StaticBody3D.new()
	body.collision_layer=1
	body.collision_mask=4
	var collision:=CollisionShape3D.new()
	var box:=BoxShape3D.new()
	box.size=Vector3(rect.size.x,2.70,rect.size.y)
	collision.shape=box
	collision.position=Vector3(rect.get_center().x,1.35,rect.get_center().y)
	body.add_child(collision)
	physics_obstacle_root.add_child(body)

func _apartment_shell_rect(rect:Rect2) -> bool:
	var c:=rect.get_center()
	return c.distance_to(Vector2(0,-2.1))<.35 and rect.size.x>10.0 and rect.size.y>16.0

func _physics_signature() -> String:
	# Rect arrays are deterministic for a given world state. Avoid rebuilding
	# dozens of StaticBody3D nodes every collision scan when nothing changed.
	return str(obstacles)+"|"+str(map_obstacles)+"|"+str(interior_obstacles)

func _rebuild_physics_obstacles(force:bool=false) -> void:
	if physics_obstacle_root==null:return
	var signature:=_physics_signature()
	if not force and signature==physics_obstacle_signature:return
	physics_obstacle_signature=signature
	for child in physics_obstacle_root.get_children():child.free()
	for rect in obstacles:
		if _apartment_shell_rect(rect):continue
		_physics_rect(rect,ScalePolicy.BODY_RADIUS)
	for rect in map_obstacles:_physics_rect(rect,ScalePolicy.BODY_RADIUS)
	for rect in interior_obstacles:_physics_rect(rect,.20)

func _sync_physics_from_camera() -> void:
	if physics_body==null:return
	physics_body.global_position=host.camera.global_position-Vector3.UP*WALK_EYE_HEIGHT
	physics_body.velocity=Vector3.ZERO

func _sync_camera_from_physics() -> void:
	if physics_body==null:return
	host.camera.global_position=physics_body.global_position+Vector3.UP*WALK_EYE_HEIGHT

func _stop_physics_walk() -> void:
	if physics_body!=null:physics_body.stop()

func _update_stamina_hud() -> void:
	if stamina_bar==null or stamina_text==null or physics_body==null:return
	stamina_bar.value=physics_body.stamina
	var show_bar:bool=active and (physics_body.is_sprinting or physics_body.stamina<physics_body.STAMINA_MAX-.1)
	stamina_bar.visible=show_bar
	stamina_text.visible=show_bar
	if show_bar:
		stamina_text.text="SPRINTING" if physics_body.is_sprinting else ("EXHAUSTED" if physics_body.exhausted else "STAMINA")

'''
    assert 'func _build_controls() -> void:' in source
    source=source.replace('func _build_controls() -> void:',physics_helpers+'func _build_controls() -> void:',1)

    source=source.replace(
        '\tcontrols.add_child(action)\n\tcontrols.hide()\n\tmobile_hud=load("res://scripts/mobile_hud.gd").new();mobile_hud.setup(self)\n',
        '''\tcontrols.add_child(action)
\tstamina_bar=ProgressBar.new()
\tstamina_bar.name="SprintStamina"
\tstamina_bar.min_value=0
\tstamina_bar.max_value=100
\tstamina_bar.value=100
\tstamina_bar.show_percentage=false
\tstamina_bar.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tstamina_bar.anchor_left=.5
\tstamina_bar.anchor_right=.5
\tstamina_bar.anchor_top=1.0
\tstamina_bar.anchor_bottom=1.0
\tstamina_bar.offset_left=-108
\tstamina_bar.offset_right=108
\tstamina_bar.offset_top=-76
\tstamina_bar.offset_bottom=-56
\tvar stamina_bg:=StyleBoxFlat.new()
\tstamina_bg.bg_color=Color("102019")
\tstamina_bg.border_color=Color("4c7257")
\tstamina_bg.set_border_width_all(2)
\tstamina_bg.set_corner_radius_all(8)
\tvar stamina_fill:=StyleBoxFlat.new()
\tstamina_fill.bg_color=Color("7fcf88")
\tstamina_fill.set_corner_radius_all(6)
\tstamina_bar.add_theme_stylebox_override("background",stamina_bg)
\tstamina_bar.add_theme_stylebox_override("fill",stamina_fill)
\tcontrols.add_child(stamina_bar)
\tstamina_text=Label.new()
\tstamina_text.mouse_filter=Control.MOUSE_FILTER_IGNORE
\tstamina_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
\tstamina_text.add_theme_font_size_override("font_size",13)
\tstamina_text.add_theme_color_override("font_color",Color("e8f4e7"))
\tstamina_text.anchor_left=.5
\tstamina_text.anchor_right=.5
\tstamina_text.anchor_top=1.0
\tstamina_text.anchor_bottom=1.0
\tstamina_text.offset_left=-108
\tstamina_text.offset_right=108
\tstamina_text.offset_top=-101
\tstamina_text.offset_bottom=-78
\tcontrols.add_child(stamina_text)
\tstamina_bar.hide()
\tstamina_text.hide()
\tcontrols.hide()
\tmobile_hud=load("res://scripts/mobile_hud.gd").new();mobile_hud.setup(self)
''',1)

    source=source.replace(
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n',
        '\thost.camera.position.y=WALK_EYE_HEIGHT\n\thost.camera.fov=78.0\n\t_sync_physics_from_camera()\n\tphysics_body.enabled=true\n',1)

    source=source.replace(
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n',
        'func end_walk() -> void:\n\tif not active: return\n\tactive=false\n\t_stop_physics_walk()\n',1)

    source=source.replace(
        '\t\t_collect_map_colliders(self)\n\t\tcollision_timer=0.3\n',
        '\t\t_collect_map_colliders(self)\n\t\t_rebuild_physics_obstacles()\n\t\tcollision_timer=0.3\n',1)

    # The visual door may be rotated open, but the legacy scanner turns its
    # axis-aligned bounds back into a blocker. Exclude it and use one dedicated
    # physics leaf that is solid only while the apartment door is closed.
    source=source.replace(
        'if node==door_pivot and (door_busy or door_pass_through):return',
        'if node==door_pivot:return',1)
    source=source.replace(
        'func _collect_map_colliders(node: Node) -> void:\n',
        'func _collect_map_colliders(node: Node) -> void:\n\tif node==physics_obstacle_root or node==physics_body or node==physics_door_body or node==police_station:return\n',1)
    source=source.replace(
        '\tdoor_busy=true;door_pass_through=true;collision_timer=0.0\n\tdoor_open=not door_open\n',
        '\tdoor_busy=true;door_pass_through=true;collision_timer=0.0\n\t_set_physics_door_closed(false)\n\tdoor_open=not door_open\n',1)
    source=source.replace(
        '\ttween.finished.connect(func():door_busy=false;_refresh_apartment_door_collision())',
        '\ttween.finished.connect(func():door_busy=false;_refresh_apartment_door_collision();_set_physics_door_closed(not door_open))',1)

    source=source.replace(
        '\tif blocked:\n\t\tpointer=-99\n\t\tpad.release()\n\t\treturn\n',
        '\tif blocked:\n\t\tpointer=-99\n\t\tpad.release()\n\t\t_stop_physics_walk()\n\t\treturn\n',1)

    start=source.index('\tvar turn:=float(Input.is_physical_key_pressed(KEY_LEFT))')
    end=source.index('\thost.view_label.text="Apartment" if _indoors(host.camera.position) else "Neighborhood"',start)
    movement=r'''	var turn:=float(Input.is_physical_key_pressed(KEY_LEFT))-float(Input.is_physical_key_pressed(KEY_RIGHT))
	host.camera.rotation.y+=turn*delta*1.65
	var movement: Vector2=pad.value
	movement+=Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))-float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	movement=movement.limit_length(1.0)
	if bench_seating.seated>=0:
		if movement.length()>0.15:
			if bench_seating.stand():_sync_physics_from_camera()
		if bench_seating.seated>=0:movement=Vector2.ZERO
	if couch_seated:
		if movement.length()>0.15:_toggle_couch()
		else:movement=Vector2.ZERO
	if not couch_seated and bench_seating.seated<0:
		var mobile_sprint:bool=pad.value.length()>=.92 and pad.value.y<=-.72
		var keyboard_sprint:bool=Input.is_physical_key_pressed(KEY_SHIFT) and movement.y<-.35
		physics_body.drive(movement,host.camera.rotation.y,mobile_sprint or keyboard_sprint)
		_sync_camera_from_physics()
	_update_stamina_hud()
'''
    source=source[:start]+movement+source[end:]

    source=source.replace(
        'host.status_label.text="Relaxing on the couch. Move to stand up." if couch_seated else "Back on your feet."\n',
        'host.status_label.text="Relaxing on the couch. Move to stand up." if couch_seated else "Back on your feet."\n\tif physics_ready and not couch_seated:_sync_physics_from_camera()\n',1)

    source=source.replace(
        'host.status_label.text="Walk through the open doorway. You can close the door from either side."',
        'host.status_label.text="3D PHYSICS TEST Â· Use the left stick to walk and drag the world to look."',1)

    # After relocation the house entrance is a normal owned/rented front door,
    # not a permanent property-preview trigger.
    source=source.replace(
        'elif not map_door.opened and not property_opportunity.touring:',
        'elif not map_door.opened and not property_opportunity.touring and not bool(host.property_opportunity_state.get("relocated",false)):',1)
    source=source.replace(
        'if id=="HouseEntrance" and not door.opened and not property_opportunity.touring:',
        'if id=="HouseEntrance" and not door.opened and not property_opportunity.touring and not bool(host.property_opportunity_state.get("relocated",false)):',1)

    source=source.replace(
        'func _toggle_door() -> void:\n\tif transitioning or door_busy:return\n',
        'func _toggle_door() -> void:\n\tif transitioning or door_busy:return\n\tif location_ops!=null and not location_ops.apartment_lease_active():\n\t\thost.status_label.text="Apartment lease released. The door is locked."\n\t\treturn\n',1)
    source=source.replace(
        '\tif target.begins_with("housecontrol_"): action.text=house_controls.title(target.trim_prefix("housecontrol_"))\n',
        '\tif target=="apartment" and location_ops!=null and not location_ops.apartment_lease_active():action.text="APARTMENT | LEASE RELEASED"\n\tif target.begins_with("housecontrol_"): action.text=house_controls.title(target.trim_prefix("housecontrol_"))\n',1)

    for required in [
        'MobilePhysicsPlayer','_rebuild_physics_obstacles()','physics_body.drive',
        'MobilePhysicsApartmentDoor','_set_physics_door_closed(false)',
        'physics_obstacle_signature','_physics_signature()',
        'if node==door_pivot:return','node==physics_obstacle_root','node==police_station',
        'physics_body.drive(movement,host.camera.rotation.y,mobile_sprint or keyboard_sprint)',
        'SprintStamina','_update_stamina_hud()',
        '3D PHYSICS TEST','_sync_physics_from_camera()'
    ]:
        assert required in source,required
    return source


def _replace_func(source:str,name:str,replacement:str) -> str:
    pattern=re.compile(r'^func '+re.escape(name)+r'\([^\n]*\)(?: -> [^:\n]+)?:\n.*?(?=^func |\Z)',re.M|re.S)
    match=pattern.search(source)
    assert match is not None,name
    return source[:match.start()]+replacement.rstrip()+"\n\n"+source[match.end():]

def patch_progression_main(source:str) -> str:
    source=source.replace('var restore_y: int = phone_scroll.scroll_vertical','var restore_y: int = 0 if phone_current_app == "texts" else phone_scroll.scroll_vertical',1)
    # Heat: routine attention builds more slowly, while staying live and
    # deliberately cooling the operation is materially faster than logging off.
    replacements={
        'const HEAT_DECAY_OPEN_PER_GAME_MINUTE: float = 0.0010':'const HEAT_DECAY_OPEN_PER_GAME_MINUTE: float = 0.0120',
        'const HEAT_DECAY_QUIET_PER_GAME_MINUTE: float = 0.0040':'const HEAT_DECAY_QUIET_PER_GAME_MINUTE: float = 0.0160',
        'const HEAT_DECAY_AWAY_PER_GAME_MINUTE: float = 0.0180':'const HEAT_DECAY_AWAY_PER_GAME_MINUTE: float = 0.0240\nconst HEAT_ROUTINE_GAIN_MULTIPLIER: float = 0.70',
        'var paused_heat_rate: float = 100.0 / (72.0 * 60.0)':'var paused_heat_rate: float = 100.0 / (180.0 * 60.0)',
        'var chance: float = clampf(0.18 + heat / 300.0, 0.18, 0.55)':'var chance: float = clampf(0.12 + heat / 400.0, 0.12, 0.40)',
        'rate *= 0.65':'rate *= 0.80',
        'Heat measures how much attention your operation is drawing. Fast sales, dealers, customer traffic and complaints raise it. Quiet time lowers it.':'Heat measures how much attention your operation is drawing. Routine sales and traffic build attention more gradually now. Staying in-game and going quiet cools Heat faster than logging off.',
        'Lay low at the property computer or text assigned crew through Contacts.':'Lay low at the property computer or text assigned crew through Contacts. Active in-game cooldown is intentionally faster than offline cooldown.'
    }
    for old,new in replacements.items():
        assert old in source,old
        source=source.replace(old,new,1)

    source=_replace_func(source,'_add_heat',r'''func _add_heat(amount: float, cause: String, show_feedback: bool = false) -> void:
	if amount <= 0.0 or not _story_chapter_two_complete():
		return
	if cause in ["Dealer activity", "Door sale", "Customer traffic", "Customer complaint", "Doorstep complaint"]:
		amount *= HEAT_ROUTINE_GAIN_MULTIPLIER
	if _reeves_protection_active():
		amount *= REEVES_PROTECTION_HEAT_MULTIPLIER
	var old_heat: float = heat
	heat = clampf(heat + amount, 0.0, 100.0)
	heat_peak = maxf(heat_peak, heat)
	last_heat_cause = cause
	var old_stage: int = _heat_stage_index(old_heat)
	var new_stage: int = _heat_stage_index(heat)
	if new_stage > old_stage:
		_trigger_heat_threshold_event(new_stage)
	elif show_feedback and status_label != null:
		status_label.text = "%s  |  Heat +%.1f (%s)." % [cause, heat - old_heat, _heat_stage_name()]
	if heat >= 100.0 and not critical_staff_event_active:
		_handle_critical_heat_staff()
	_check_reeves_trigger()
	if phone_open and phone_current_app in ["home", "heat", "business", "bills", "employees", "upgrades", "stats"]:
		_refresh_phone()''')

    source=_replace_func(source,'_track_power_usage',r'''func _track_power_usage(elapsed_game_minutes: float) -> void:
	if elapsed_game_minutes <= 0.0:
		return
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.track_power_usage(elapsed_game_minutes)
		return
	current_day_power_cost += _current_power_rate_per_game_minute() * elapsed_game_minutes''')

    source=_replace_func(source,'_finalize_daily_power_bill',r'''func _finalize_daily_power_bill(show_feedback: bool) -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.finalize_power_bills(show_feedback)
		return
	var bill: int = maxi(0, int(ceil(current_day_power_cost)))
	last_power_bill = bill
	power_bill_due = mini(POWER_BILL_MAX_BALANCE, power_bill_due + bill)
	lifetime_power_cost += bill
	current_day_power_cost = 0.0''')

    source=_replace_func(source,'_charge_water_use',r'''func _charge_water_use(count: int = 1) -> void:
	if count <= 0:
		return
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.charge_water_use(count)
		return
	current_day_water_uses += count
	current_day_water_cost += WATER_COST_PER_WATERING * float(count)''')

    source=_replace_func(source,'_finalize_daily_water_bill',r'''func _finalize_daily_water_bill(show_feedback: bool) -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.finalize_water_bills(show_feedback)
		return
	var bill: int = maxi(0, int(ceil(current_day_water_cost)))
	last_water_bill = bill
	if bill > 0:
		water_bill_due = mini(WATER_BILL_MAX_BALANCE, water_bill_due + bill)
		lifetime_water_cost += bill
	current_day_water_cost = 0.0
	current_day_water_uses = 0''')

    source=_replace_func(source,'_pay_water_bill',r'''func _pay_water_bill() -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		for property in ["apartment","house"]:
			var due:int=neighborhood.location_ops.property_utility_due(property,"water")
			if due>0 and cash>=due:
				neighborhood.location_ops.pay_property_utility(property,"water")
		return
	if water_bill_due<=0:return''')

    source=_replace_func(source,'_pay_power_bill',r'''func _pay_power_bill() -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		for property in ["apartment","house"]:
			var due:int=neighborhood.location_ops.property_utility_due(property,"power")
			if due>0 and cash>=due:
				neighborhood.location_ops.pay_property_utility(property,"power")
		return
	if power_bill_due<=0:return''')

    # Branching roadmap choices. Claimed history is never removed. Once one
    # Reeves payment outcome is chosen, its incompatible unclaimed objective
    # disappears from the active roadmap.
    assert 'var advancement_claimed: Dictionary = {}' in source
    source=source.replace('var advancement_claimed: Dictionary = {}','var advancement_claimed: Dictionary = {}\nvar advancement_choice_state: Dictionary = {}',1)
    source=source.replace(
        '{"id": "reeves_payments", "category": "Heat", "tier": 4, "title": "Keep Your End", "description": "Make 3 on-time Reeves payments.", "metric": "reeves_payments", "target": 3,',
        '{"id": "reeves_payments", "category": "Heat", "tier": 4, "title": "Keep Your End", "description": "Make 3 on-time Reeves payments.", "metric": "reeves_payments", "target": 3, "choice_group": "reeves_payment_outcome", "choice_value": "pay",',1)
    source=source.replace(
        '{"id": "reeves_miss", "category": "Heat", "tier": 4, "title": "Lose His Protection", "description": "Miss a Reeves payment and trigger enforcement risk.", "metric": "reeves_missed_payments", "target": 1,',
        '{"id": "reeves_miss", "category": "Heat", "tier": 4, "title": "Lose His Protection", "description": "Miss a Reeves payment and trigger enforcement risk.", "metric": "reeves_missed_payments", "target": 1, "choice_group": "reeves_payment_outcome", "choice_value": "miss",',1)

    old_c4='{"id": "c4_expansion_ready", "category": "Expansion", "tier": 5, "title": "Expansion Ready", "description": "Prove the operation is mature enough to support a larger property.", "state": "chapter_four_complete", "target": 1, "reward_cash": 0, "reward_xp": 500, "reward_rep": 25, "reward_unlock": "PROPERTY OPPORTUNITY"},'
    new_c4='{"id": "c4_expansion_ready", "category": "Expansion", "tier": 5, "title": "Expansion Ready", "description": "Prove the operation is mature enough to support a larger property.", "state": "chapter_four_operation_ready", "target": 1, "reward_cash": 0, "reward_xp": 500, "reward_rep": 25, "reward_unlock": "PROPERTY OPPORTUNITY"},\n\t{"id": "c4_new_base", "category": "Expansion", "tier": 6, "title": "Choose Your Next Base", "description": "Secure the house, relocate AFewBuds and enter the new operation.", "state": "chapter_four_complete", "target": 1, "reward_cash": 0, "reward_xp": 600, "reward_rep": 30, "reward_unlock": "CHAPTER 5 + HOUSE OPERATION"},'
    assert old_c4 in source
    source=source.replace(old_c4,new_c4,1)

    value_anchor='\tif state_name == "chapter_four_complete":\n\t\treturn 1 if _story_chapter_four_complete() else 0'
    value_repl='\tif state_name == "chapter_four_operation_ready":\n\t\treturn 1 if _story_chapter_four_operation_complete() else 0\n'+value_anchor
    assert value_anchor in source
    source=source.replace(value_anchor,value_repl,1)

    source=_replace_func(source,'_story_chapter_four_complete',r'''func _story_chapter_four_complete() -> bool:
	return _story_chapter_four_operation_complete() 		and bool(property_opportunity_state.get("relocated", false)) 		and bool(property_opportunity_state.get("first_entry", false))''')

    source=_replace_func(source,'_chapter_four_target_story_stage',r'''func _chapter_four_target_story_stage() -> int:
	if not _story_chapter_three_complete():
		return 0
	var target: int = 1
	if _story_chapter_four_apartment_complete():
		target = 2
	if _story_chapter_four_distribution_complete():
		target = 3
	if _story_chapter_four_crew_complete():
		target = 4
	if _story_chapter_four_demand_complete():
		target = 5
	if _story_chapter_four_operation_complete():
		target = 6
	if _story_chapter_four_complete():
		target = 7
	return target''')

    source=_replace_func(source,'_sync_chapter_four_story',r'''func _sync_chapter_four_story() -> bool:
	var target_stage: int = _chapter_four_target_story_stage()
	if target_stage <= chapter_four_story_stage:
		if _story_chapter_four_operation_complete() and not property_offer_unlocked:
			property_offer_unlocked = true
			return true
		return false

	var changed: bool = false
	while chapter_four_story_stage < target_stage:
		chapter_four_story_stage += 1
		changed = true
		match chapter_four_story_stage:
			1:
				_chapter_four_append_story_text("You made it through all that pressure and this apartment is starting to feel real small. Keep building the operation, but start thinking bigger.")
			2:
				_chapter_four_append_story_text("Three tents and that new bench? Every wall in that place has a job now. You are officially out of room.")
			3:
				_chapter_four_append_story_text("Dealer Storage is maxed and the crew is moving product. This is bigger than people coming to your door now.")
			4:
				_chapter_four_append_story_text("You are running a crew now, not just doing everything yourself. The apartment is becoming the bottleneck.")
			5:
				_chapter_four_append_story_text("The numbers do not lie. Too many customers, too much product, too much traffic for one apartment. Finish proving the operation can handle a real move.")
			6:
				property_offer_unlocked = true
				_chapter_four_append_story_text("I got a line on a house that can actually fit this operation. You can rent it, lease it to own, or buy it outright. Go inspect it and decide how you want to secure it.")
			7:
				_chapter_four_append_story_text("You made the move. The house is the AFewBuds operation now. Chapter 4 is done. Chapter 5 starts here â€” build something bigger.")
	return changed''')

    # Real Estate is a top-level phone app for multi-property management.
    source=source.replace(
        '\t\t"leaderboard":\n\t\t\tphone_title.text = "Leaderboard"\n\t\t\t_build_leaderboard_app()\n',
        '\t\t"leaderboard":\n\t\t\tphone_title.text = "Leaderboard"\n\t\t\t_build_leaderboard_app()\n\t\t"realestate":\n\t\t\tphone_title.text = "Real Estate"\n\t\t\t_build_real_estate_app()\n',1)
    source=source.replace(
        '\t_add_phone_app_tile(grid, "", "Illegal Businesses", "Storefront status, bills & stats", "budshop")\n',
        '\t_add_phone_app_tile(grid, "", "Illegal Businesses", "Storefront status, bills & stats", "budshop")\n\t_add_phone_app_tile(grid, "", "Real Estate", "Properties, leases & payments", "realestate")\n',1)
    real_estate_func=r'''func _build_real_estate_app() -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.real_estate_ui(phone_list)
		return
	var fallback:=Label.new()
	fallback.text="Real Estate data is unavailable."
	fallback.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	phone_list.add_child(fallback)

'''
    source=source.replace('func _build_account_app() -> void:',real_estate_func+'func _build_account_app() -> void:',1)

    source=source.replace('phone_title.text = "Apartment Â· Employees"','phone_title.text = ("%s Â· Employees" % (neighborhood.location_ops.active_property().capitalize() if neighborhood!=null and neighborhood.location_ops!=null else "Operation"))',1)
    source=source.replace('phone_title.text = "Apartment Â· Equipment"','phone_title.text = ("%s Â· Equipment" % (neighborhood.location_ops.active_property().capitalize() if neighborhood!=null and neighborhood.location_ops!=null else "Operation"))',1)
    source=source.replace('phone_title.text = "Apartment Â· Inventory"','phone_title.text = ("%s Â· Inventory" % (neighborhood.location_ops.active_property().capitalize() if neighborhood!=null and neighborhood.location_ops!=null else "Operation"))',1)
    source=source.replace('phone_title.text = "Apartment Â· Genetics"','phone_title.text = ("%s Â· Genetics" % (neighborhood.location_ops.active_property().capitalize() if neighborhood!=null and neighborhood.location_ops!=null else "Operation"))',1)

    source=_replace_func(source,'_build_budshop_app',r'''func _build_budshop_app() -> void:
	var card:=PanelContainer.new()
	card.add_theme_stylebox_override("panel",_style_box(Color("152029"),Color("33434f"),16,1))
	phone_list.add_child(card)
	var box:=VBoxContainer.new()
	card.add_child(box)
	var property_name:String="Operation"
	if neighborhood!=null and neighborhood.location_ops!=null:
		property_name=neighborhood.location_ops.active_property().capitalize()
	var status:=Label.new()
	status.text="%s\nStorefront: %s" % [property_name.to_upper(),"LAYING LOW" if lay_low_active else ("OPEN" if business_open else "AWAY")]
	status.add_theme_font_size_override("font_size",20)
	status.modulate=Color("8ed6a3") if business_open and not lay_low_active else Color("e1b07a")
	box.add_child(status)
	var note:=Label.new()
	note.text="Manage the active operation at its property computer. Property leases, ownership and access are in Real Estate."
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	box.add_child(note)
	var grid:GridContainer=_phone_category_grid()
	_add_phone_app_tile(grid,"","Bills","Property utilities & balances","bills")
	_add_phone_app_tile(grid,"","Heat","%s | %d/100" % [_heat_stage_name(),int(round(heat))],"heat")
	_add_phone_app_tile(grid,"","Stats","Progress & revenue","stats")''')

    source=_replace_func(source,'_build_business_app',r'''func _build_business_app() -> void:
	var active_name:String="Operation"
	var property_due:int=0
	var utility_due:int=power_bill_due+water_bill_due
	if neighborhood!=null and neighborhood.location_ops!=null:
		active_name=neighborhood.location_ops.active_property().capitalize()
		property_due=neighborhood.location_ops.balance()
		utility_due=neighborhood.location_ops.utility_total_due()
	var property_note:=Label.new()
	property_note.text="%s Â· Active operation\nUse Real Estate for property ownership/leases and Bills for balances." % active_name.to_upper()
	property_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	phone_list.add_child(property_note)
	var summary:=Label.new()
	summary.text="GROWER LEVEL %d   |   XP %d / %d\nBrand Level %d   |   Reputation %d\nStorefront: %s" % [grower_level,grower_xp,_xp_needed_for_next_level(),brand_level,reputation,"OPEN" if business_open else "AWAY"]
	summary.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	summary.add_theme_font_size_override("font_size",19)
	phone_list.add_child(summary)
	var grid:GridContainer=_phone_category_grid()
	_add_phone_app_tile(grid,"","Bills","$%d outstanding" % (property_due+utility_due+dealer_balance_due),"bills")
	if neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.rendering_management:
		neighborhood.location_ops.business_extras()''')

    source=_replace_func(source,'_build_bills_app',r'''func _build_bills_app() -> void:
	if neighborhood!=null and neighborhood.location_ops!=null:
		neighborhood.location_ops.property_bills_ui(phone_list)
	var dealer_card:=PanelContainer.new()
	phone_list.add_child(dealer_card)
	var dealer_box:=VBoxContainer.new()
	dealer_card.add_child(dealer_box)
	var dealer_detail:=Label.new()
	dealer_detail.text="DEALER BALANCE\nOutstanding: $%d\nCash held for nightly drop-off: $%d" % [dealer_balance_due,dealer_cash_held]
	dealer_detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	dealer_box.add_child(dealer_detail)
	if dealer_balance_due>0:
		var pay_dealers:=Button.new()
		pay_dealers.text="PAY DEALER BALANCE  |  $%d" % dealer_balance_due
		pay_dealers.disabled=cash<dealer_balance_due
		pay_dealers.custom_minimum_size.y=50
		pay_dealers.pressed.connect(_pay_dealer_balance)
		dealer_box.add_child(pay_dealers)''')

    source=_replace_func(source,'_advancement_story_label',r'''func _advancement_story_label() -> String:
	if not _story_chapter_one_complete():
		return "CHAPTER 1 - STARTING SMALL"
	if not _story_chapter_two_complete():
		return "CHAPTER 2 - BUILDING A NAME"
	if not _story_chapter_three_complete():
		return "CHAPTER 3 - GETTING NOTICED"
	if not _story_chapter_four_complete():
		return "CHAPTER 4 - OUTGROWING THE APARTMENT"
	return "CHAPTER 5 - BUILDING AN OPERATION"''')

    assert 'chapter_title.text = "STORY\\nCHAPTER 4 COMPLETE\\nEXPANSION OPPORTUNITY UNLOCKED"' in source
    source=source.replace('chapter_title.text = "STORY\\nCHAPTER 4 COMPLETE\\nEXPANSION OPPORTUNITY UNLOCKED"','chapter_title.text = "STORY\\nCHAPTER 5 - BUILDING AN OPERATION"',1)

    objective='\t\t\t_story_checkmark(_story_chapter_four_operation_complete(), "Proven Operation - Grower 10 + 3 hybrid batches + 250g moved into storage")'
    objective_repl='\t\t\t_story_checkmark(_story_chapter_four_operation_complete(), "Proven Operation - Grower 10 + 3 hybrid batches + 250g moved into storage"),\n\t\t\t_story_checkmark(bool(property_opportunity_state.get("inspection_complete", false)), "Inspect the house - tour all 6 rooms"),\n\t\t\t_story_checkmark(bool(property_opportunity_state.get("agreement_signed", false)), "Choose your next base - sign Rent, Lease to Own or Purchase"),\n\t\t\t_story_checkmark(bool(property_opportunity_state.get("relocated", false)), "Move Operation - confirm relocation to the house"),\n\t\t\t_story_checkmark(bool(property_opportunity_state.get("first_entry", false)), "Start Chapter 5 - enter the new house operation")'
    assert objective in source
    source=source.replace(objective,objective_repl,1)

    # Apply retirement filtering to the catalog loops that already exist in
    # the packed runtime. Preserve each loop's original indentation; a naive
    # substring replace can match inside deeper-indented loops and break GDScript.
    loop_pattern=re.compile(r'^(?P<indent>\\t+)for (?P<var>[A-Za-z_][A-Za-z0-9_]*): Dictionary in advancement_catalog:\\n',re.M)
    def add_retired_filter(match):
        indent=match.group('indent');var=match.group('var')
        return f'{indent}for {var}: Dictionary in advancement_catalog:\\n{indent}\\tif _advancement_is_retired({var}):\\n{indent}\\t\\tcontinue\\n'
    source=loop_pattern.sub(add_retired_filter,source)

    helper=r'''func _advancement_choice_group(advancement_id: String) -> String:
	for candidate: Dictionary in advancement_catalog:
		if str(candidate.get("id", "")) == advancement_id:
			return str(candidate.get("choice_group", ""))
	return ""

func _advancement_choice_value(advancement_id: String) -> String:
	for candidate: Dictionary in advancement_catalog:
		if str(candidate.get("id", "")) == advancement_id:
			return str(candidate.get("choice_value", ""))
	return ""

func _advancement_is_retired(entry: Dictionary) -> bool:
	var advancement_id: String = str(entry.get("id", ""))
	if bool(advancement_claimed.get(advancement_id, false)):
		return false
	var group: String = str(entry.get("choice_group", ""))
	var value: String = str(entry.get("choice_value", ""))
	if group.is_empty() or value.is_empty():
		return false
	var selected: String = str(advancement_choice_state.get(group, ""))
	return selected not in ["", "legacy_both", value]

func _lock_advancement_choice(advancement_id: String) -> void:
	var group: String = _advancement_choice_group(advancement_id)
	var value: String = _advancement_choice_value(advancement_id)
	if group.is_empty() or value.is_empty() or advancement_choice_state.has(group):
		return
	advancement_choice_state[group] = value

func _migrate_advancement_choices() -> void:
	if advancement_choice_state.has("reeves_payment_outcome"):
		return
	var paid: bool = bool(advancement_claimed.get("reeves_payments", false)) or int(advancement_stats.get("reeves_payments", 0)) > 0
	var missed: bool = bool(advancement_claimed.get("reeves_miss", false)) or int(advancement_stats.get("reeves_missed_payments", 0)) > 0
	if paid and missed:
		advancement_choice_state["reeves_payment_outcome"] = "legacy_both"
	elif missed:
		advancement_choice_state["reeves_payment_outcome"] = "miss"
	elif paid:
		advancement_choice_state["reeves_payment_outcome"] = "pay"

func _advancement_active_count() -> int:
	var count: int = 0
	for entry: Dictionary in advancement_catalog:
		if not _advancement_is_retired(entry):
			count += 1
	return count

'''
    marker='func _advancement_ready_count() -> int:'
    assert marker in source
    source=source.replace(marker,helper+marker,1)

    source=_replace_func(source,'_increment_advancement_stat',r'''func _increment_advancement_stat(metric_name: String, amount: int = 1) -> void:
	if metric_name.is_empty() or amount <= 0:
		return
	if metric_name == "reeves_payments":
		_lock_advancement_choice("reeves_payments")
	elif metric_name == "reeves_missed_payments":
		_lock_advancement_choice("reeves_miss")
	advancement_stats[metric_name] = int(advancement_stats.get(metric_name, 0)) + amount''')

    source=_replace_func(source,'_advancement_is_ready',r'''func _advancement_is_ready(entry: Dictionary) -> bool:
	if _advancement_is_retired(entry):
		return false
	if _advancement_value(entry) < int(entry.get("target", 1)):
		return false
	for requirement_variant: Variant in entry.get("requires", []):
		if not (requirement_variant is Dictionary):
			return false
		var requirement: Dictionary = requirement_variant as Dictionary
		if _advancement_value(requirement) < int(requirement.get("target", 1)):
			return false
	return true''')

    source=source.replace('advancement_catalog.size()','_advancement_active_count()')

    # Persist and migrate branch choice state.
    assert '"advancement_claimed": advancement_claimed,' in source
    source=source.replace('"advancement_claimed": advancement_claimed,','"advancement_claimed": advancement_claimed,\n\t\t"advancement_choice_state": advancement_choice_state,',1)
    load_anchor='\tif loaded_advancement_claimed is Dictionary:\n\t\tadvancement_claimed = loaded_advancement_claimed as Dictionary\n\tchapter_four_story_stage = clampi(int(data.get("chapter_four_story_stage", chapter_four_story_stage)), 0, 6)'
    load_repl='\tif loaded_advancement_claimed is Dictionary:\n\t\tadvancement_claimed = loaded_advancement_claimed as Dictionary\n\tvar loaded_advancement_choices: Variant = data.get("advancement_choice_state", {})\n\tif loaded_advancement_choices is Dictionary:\n\t\tadvancement_choice_state = (loaded_advancement_choices as Dictionary).duplicate(true)\n\t_migrate_advancement_choices()\n\tchapter_four_story_stage = clampi(int(data.get("chapter_four_story_stage", chapter_four_story_stage)), 0, 7)'
    assert load_anchor in source
    source=source.replace(load_anchor,load_repl,1)

    # Help copy follows the new active-property and Heat rules.
    source=source.replace('Phone -> Illegal Businesses -> Bills or apartment computer -> Bills includes apartment rent: $600 every 14 game days, with a three-day grace period.',
                          'Phone -> Real Estate manages every property separately. Moving to the house keeps the apartment lease active by default, so its $600/14-day rent continues until you explicitly release that lease. Electric and water are tracked per property and accrue only where utilities are actually being used. Released properties disappear from normal operation management and can be rented again later through Real Estate. House Rent and Lease-to-Own use 7-day payment cycles.')
    source=source.replace('No new seeds, harvesting, trimming, bagging or selling occur while away; equipment auto-refill remains live-only.',
                          'No new seeds, harvesting, trimming, bagging or selling occur while away; equipment auto-refill remains live-only. Offline Heat cooling is intentionally slower than staying in-game and going quiet.')

    # Static guarantees for this progression patch.
    for required in [
        'HEAT_ROUTINE_GAIN_MULTIPLIER',
        '100.0 / (180.0 * 60.0)',
        '"c4_new_base"',
        '"chapter_four_operation_ready"',
        'advancement_choice_state',
        '_advancement_is_retired',
        'CHAPTER 5 - BUILDING AN OPERATION',
        'property_opportunity_state.get("first_entry", false)'
    ]:
        assert required in source,required
    return source

def patch_station(source:str) -> str:
    if 'func build_physics() -> void:' in source:
        return source
    # Floor slabs are structural thickness, so lower walls must terminate at
    # the slab underside rather than continuing through to its top surface.
    source=source.replace(
        'var xs:Array[float]=[0,span];var ys:Array[float]=[0,STORY]',
        'var wall_height:float=STORY\n\tif floor_index==0 and id.begins_with("Stair"):wall_height=STORY-.20\n\telif floor_index==1:wall_height=STORY-.23\n\tvar xs:Array[float]=[0,span];var ys:Array[float]=[0,wall_height]',1)
    # The final tread meets the top landing cleanly; its decorative nosing was
    # the only stair trim extending above/through the upstairs floor edge.
    source=source.replace(
        '\t\tpart("StairNosing",21.5,h+.009,20.5-i*.35,Vector3(4.6,.018,.035),"bfc4c1",false)',
        '\t\tif i<19:part("StairNosing",21.5,h+.009,20.5-i*.35,Vector3(4.6,.018,.035),"bfc4c1",false)',1)
    source=source.replace(
        '\tflush()\n\nfunc ground_rooms() -> void:',
        '\tflush()\n\tbuild_physics()\n\nfunc ground_rooms() -> void:',1)
    physics=r'''
func build_physics() -> void:
	if has_node("StationStructure"):return
	var body:=StaticBody3D.new()
	body.name="StationStructure"
	body.collision_layer=1
	body.collision_mask=4
	add_child(body)
	for bounds in colliders:add_box_collision(body,bounds)
	for entry in parts:
		if entry.id in ["GroundFloor","UpperFloorWest","UpperFloorNorth","UpperFloorSouth","TopLanding","Roof"]:
			add_box_collision(body,entry.bounds)
	# Continuous ramp under the visible treads: the same capsule walks both
	# floors without camera-height teleporting or per-step collision chatter.
	var ramp:=ConvexPolygonShape3D.new()
	var vertices:=PackedVector3Array()
	for x in [19.2,23.8]:
		vertices.append(point(x,-.1,20.5));vertices.append(point(x,0,20.5))
		vertices.append(point(x,-.1,13.5));vertices.append(point(x,STORY,13.5))
	ramp.points=vertices
	var ramp_shape:=CollisionShape3D.new()
	ramp_shape.name="StairRamp"
	ramp_shape.shape=ramp
	body.add_child(ramp_shape)

func add_box_collision(body:StaticBody3D,bounds:AABB) -> void:
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=bounds.size
	collision.shape=shape
	collision.position=bounds.get_center()
	body.add_child(collision)

'''
    source=source.replace('func covers(at:Vector3) -> bool:',physics+'func covers(at:Vector3) -> bool:',1)
    assert 'StationStructure' in source and 'StairRamp' in source
    return source

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--output-dir',required=True)
    args=ap.parse_args()
    out=Path(args.output_dir).resolve()
    out.mkdir(parents=True,exist_ok=True)

    baseline=east.fit.read_recipe(ROOT/'runtime/kobi-v1.patch.json')
    expected='bbc788e5d4dd19b59af7dd2824f34943361d901d08ae5b5c25f8e7c6b9a75410'
    assert hashlib.sha256(baseline).hexdigest()==expected
    fb,entries=east.pack.parse(baseline)
    before={n:b for n,b,f in entries}

    main_script=patch_progression_main(before['scripts/main.gd'].decode())
    main_script=main_script.replace('brand_label.text = "AFewBuds"', 'if neighborhood != null and neighborhood.mobile_hud != null:\n\t\t\tneighborhood.mobile_hud.update_location()\n\t\telse: brand_label.text = load("res://scripts/districts.gd").heading(camera.position)')
    neighborhood=patch_neighborhood(before['scripts/neighborhood.gd'].decode())
    station=patch_station((ROOT/'tools/police_station_v1/station.gd').read_text())
    door=(HERE/'interior_door_physics.gd').read_bytes()
    property_opportunity=(ROOT/'tools/progression_v1/property_opportunity.gd').read_bytes()
    location_ops=(ROOT/'tools/progression_v1/location_ops.gd').read_bytes()
    crew=before['scripts/crew_phone.gd'].decode()
    assert 'host.phone_scroll.scroll_vertical=int(host.phone_scroll.get_v_scroll_bar().max_value)' in crew
    crew=crew.replace('host.phone_scroll.scroll_vertical=int(host.phone_scroll.get_v_scroll_bar().max_value)','host.phone_scroll.scroll_vertical=0')
    crew=crew.replace('for i in range(host.phone_text_messages.size()):','for i in range(host.phone_text_messages.size()-1,-1,-1):')
    replacements={
        'scripts/main.gd':main_script.encode(),
        'scripts/neighborhood.gd':neighborhood.encode(),
        'scripts/police_station.gd':station.encode(),
        'scripts/interior_door.gd':door,
        'scripts/property_opportunity.gd':property_opportunity,
        'scripts/location_ops.gd':location_ops,
        'scripts/crew_phone.gd':crew.encode(),
        'scripts/mobile_hud.gd':(HERE/'mobile_hud.gd').read_bytes(),
    }
    updated=[]
    for n,b,f in entries:
        updated.append([n,replacements.get(n,b),f])
    updated.append(['scripts/mobile_physics_player.gd',(HERE/'mobile_physics_player.gd').read_bytes(),0])

    updated.append(['scripts/districts.gd',(HERE/'districts.gd').read_bytes(),0])

    built=east.pack.rebuild(baseline,fb,updated)
    after={n:b for n,b,f in east.pack.parse(built)[1]}
    changed=[n for n in before if before[n]!=after[n]]
    expected_changed={'scripts/mobile_hud.gd','scripts/crew_phone.gd','scripts/interior_door.gd','scripts/location_ops.gd','scripts/main.gd','scripts/neighborhood.gd','scripts/police_station.gd','scripts/property_opportunity.gd'}
    assert set(changed)==expected_changed,changed
    assert 'scripts/mobile_physics_player.gd' in after

    (out/'candidate.pck').write_bytes(built)
    east.fit.extract(updated,out/'candidate','AFB Mobile 3D Movement Candidate')

    base=(ROOT/'index-cloudtest10.pck').read_bytes()
    source={n:(o,s) for n,o,s in east.directory(base)}
    segments=[]
    def add(data):
        if data:segments.append(['data',base64.b64encode(data).decode()])
    def copy(offset,size):
        if size:segments.append(['copy',offset,size])
    add(built[:fb]);cursor=fb
    assets=[
        'assets/characters/Kobi.glb','assets/characters/Kobi_BaseColor.png',
        'assets/characters/Malik.glb','assets/characters/Rod.glb',
        'assets/characters/Malik_BaseColor.png','assets/characters/Rod_BaseColor.png',
        'assets/furniture/walnut.png'
    ]
    for name,offset,size in east.directory(built):
        if offset>cursor:
            assert not any(built[cursor:offset]);segments.append(['zero',offset-cursor])
        data=built[offset:offset+size]
        if name in assets:
            segments.append(['asset',name+'?v=mobile-3d-v1',size,hashlib.sha256(data).hexdigest()])
        elif name in source:
            oldoff,oldsize=source[name];previous=base[oldoff:oldoff+oldsize]
            if data==previous:
                copy(oldoff,oldsize)
            elif name=='scripts/main.gd':
                a=previous.splitlines(keepends=True);b=data.splitlines(keepends=True);offsets=[0]
                for line in a:offsets.append(offsets[-1]+len(line))
                for op,l,r,x,y in difflib.SequenceMatcher(None,a,b,autojunk=False).get_opcodes():
                    if op=='equal':copy(oldoff+offsets[l],offsets[r]-offsets[l])
                    elif op in ['replace','insert']:add(b''.join(b[x:y]))
            else:
                add(data)
        else:
            add(data)
        cursor=offset+size
    add(built[cursor:])

    recipe={
        'format':'afb-pack-delta-1',
        'base_url':'index-cloudtest10.pck?build=63',
        'base_size':len(base),
        'base_sha256':hashlib.sha256(base).hexdigest(),
        'target_size':len(built),
        'target_sha256':hashlib.sha256(built).hexdigest(),
        'segments':segments
    }
    recipe_path=ROOT/'runtime/mobile-3d-v1.patch.json'
    recipe_path.write_text(json.dumps(recipe,separators=(',',':'))+'\n',newline='\n')
    assert east.fit.read_recipe(recipe_path)==built

    loader=(ROOT/'shared/afb-runtime-kobi-v1.js').read_text()
    loader=loader.replace('kobi-v1','mobile-3d-v1').replace('AFB_RUNTIME_KOBI_V1','AFB_RUNTIME_MOBILE_3D_V1')
    loader=re.sub(r'patch\.json\?v=\d+','patch.json?v=12',loader)
    (ROOT/'shared/afb-runtime-mobile-3d-v1.js').write_text(loader,newline='\n')

    release='0.7.9-beta.19-cloudtest.99-mobile3d.12'
    index=(ROOT/'index.html').read_text()
    index=index.replace('kobi-v1','mobile-3d-v1').replace('AFB_RUNTIME_KOBI_V1','AFB_RUNTIME_MOBILE_3D_V1')
    index=re.sub(r'afb-runtime-mobile-3d-v1\.js\?v=\d+','afb-runtime-mobile-3d-v1.js?v=12',index)
    index=re.sub(r'0\.7\.9-beta\.19-cloudtest\.(?:98-kobi|99-mobile3d)\.\d+',release,index)
    index=re.sub(r'"fileSizes":\{[^}]*\\}',f'"fileSizes":{{"index-mobile-3d-v1.pck":{len(built)},"index.wasm":{(ROOT/"index.wasm").stat().st_size}}}',index,count=1)
    if 'MOBILE 3D TEST</title>' not in index:index=index.replace('</title>',' Â· MOBILE 3D TEST</title>',1)
    (ROOT/'index.html').write_text(index,newline='\n')

    version=json.loads((ROOT/'version.json').read_text())
    version['release_id']=release
    version['paused_heat_decay']='100 Heat over 180 real minutes'
    version['mobile_3d_movement']={
        'branch':'main',
        'player':'CharacterBody3D capsule',
        'input':'touch joystick + drag look; full forward stick sprints; Shift+forward sprints on keyboard',
        'physics':'gravity, floor snap, cached StaticBody3D world proxies, physical doors and police stair ramp',
        'police_station':'clean floor closure; side-door widths match scaled apertures; jamb/header trim sits inside openings; wall-base trim is surface-mounted',
        'sprint':'5.4 m/s with shared 100-point stamina, drain/recovery/exhaustion and HUD label SPRINTING',
        'save_schema':'backward-compatible; adds property agreement/relocation and advancement choice state'
    }
    version['chapter_4_5']={'property_finale':'Rent / Lease to Own / Purchase -> relocate -> first house entry completes Chapter 4','chapter_5':'Building an Operation starts in house','agreement_terms':'Rent 1800 + 600/7d; Lease 4500 + 1000/7d toward 18500; Purchase 17500','apartment_lease':'continues at 600/14d after relocation unless explicitly released in Real Estate; existing rent and utility debt survives release'}
    version['heat_balance']={'routine_gain_multiplier':0.70,'online_open_decay_per_game_minute':0.012,'online_quiet_decay_per_game_minute':0.016,'online_lay_low_decay_per_game_minute':0.024,'offline_full_cool_minutes':180,'daily_pressure_chance':'12%-40%'}
    version['branching_tasks']={'reeves_payment_outcome':'On-time payment vs missed-payment objectives are mutually exclusive; incompatible unclaimed task retires automatically'}
    version['real_estate_app']={'phone_home':True,'portfolio':'apartment + house shown separately','billing':'independent rent/lease, electric and water balances by property','apartment_release':'requires another property and cleared apartment-assigned contents; future rent/utilities stop, existing debt remains; apartment door/computer lock','property_storage':'paid upgrades remain player-owned and can be unplaced/stored instead of deleted','apartment_reacquire':'released apartment can be rented again after prior debt is cleared'}
    version['districts']={'city':'Bongchester','current':['Roachwood','Half Baked Heights','Paranoia Point'],'hud':'Persistent city / current district; follows player location'}
    version['messages']='Newest messages first in each conversation; opening or refreshing Messages starts at the top'
    version['phone_home']='Illegal Businesses, Real Estate, Store, Contacts, Messages, Tasks & Rewards, Leaderboard, Settings'
    version['runtime_delivery']='SHA-256-verified mobile-3d-v1 delta over .98-kobi.1'
    (ROOT/'version.json').write_text(json.dumps(version,indent=2)+'\n',newline='\n')
    (ROOT/'BUILD_VERSION.txt').write_text(
        'AFewBuds Cloud Test\nGame build: 0.7.9-beta.19\nWeb release: '+release+
        '\nRuntime: Experimental mobile CharacterBody3D movement on .98-kobi.1\n',newline='\n')

    receipt={
        'baseline_sha256':expected,
        'target_sha256':hashlib.sha256(built).hexdigest(),
        'target_bytes':len(built),
        'changed_existing_entries':changed,
        'added_entries':['scripts/mobile_physics_player.gd','scripts/districts.gd'],
        'unchanged_entries':len(before)-len(changed),
        'reconstruction_verified':True
    }
    (HERE/'build_receipt.json').write_text(json.dumps(receipt,indent=2)+'\n',newline='\n')
    print(json.dumps(receipt))

if __name__=='__main__':main()
