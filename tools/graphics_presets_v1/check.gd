extends SceneTree
## Device-only graphics preferences, visual restoration, runtime light updates and menu options.
var checks:int=0
var failures:int=0
func check(condition:bool,note:String)->void:
    checks+=1
    if condition:print("PASS: "+note)
    else:failures+=1;push_error("GRAPHICS_PRESET FAIL: "+note)
func _initialize()->void:call_deferred("run")
func run()->void:
    var game:Node3D=load("res://scenes/main.tscn").instantiate()
    root.add_child(game)
    await process_frame
    game.set_process(false)
    game.neighborhood.set_process(false)
    if game.neighborhood.physics_body!=null:game.neighborhood.physics_body.set_physics_process(false)
    var menu:Node=game.inventory_system.session_menu
    var graphics:Node=menu.graphics
    check(graphics!=null and graphics.selected=="high","Default graphics preserve the existing artwork")
    menu.show_page("settings")
    var visible_buttons:String=""
    for b in menu.body.find_children("*","Button",true,false):visible_buttons+=b.text+"\n"
    check("LOW" in visible_buttons and "MEDIUM" in visible_buttons and "HIGH" in visible_buttons,"All three presets are accessible through Pause Settings")
    var viewport:Viewport=game.get_viewport()
    var original_atlas:int=graphics.original_shadow_atlas
    var original_scale:float=graphics.original_scale
    var original_fps:int=graphics.original_fps
    var sun:DirectionalLight3D=game.neighborhood.outdoor_sun
    var original_shadow:bool=bool(sun.get_meta("afb_quality_original_shadow",sun.shadow_enabled))
    menu._select_graphics("low")
    check(is_equal_approx(viewport.scaling_3d_scale,.75) and viewport.positional_shadow_atlas_size==512,"Low reduces internal 3D resolution and shadow budget")
    check(Engine.max_fps==30 and not sun.shadow_enabled,"Low caps FPS and disables expensive shadows")
    var new_light:=DirectionalLight3D.new()
    new_light.shadow_enabled=true
    game.add_child(new_light)
    await process_frame
    await process_frame
    check(not new_light.shadow_enabled,"Lights added after gameplay starts obey the current quality preset")
    menu._select_graphics("medium")
    check(is_equal_approx(viewport.scaling_3d_scale,.9) and viewport.positional_shadow_atlas_size==1024 and Engine.max_fps==60,"Medium applies balanced 3D settings")
    check(sun.shadow_enabled==original_shadow and new_light.shadow_enabled,"Medium restores the original light configuration")
    var before:String=graphics.selected
    check(not graphics.change("invalid") and graphics.selected==before,"Unexpected preset values are rejected")
    menu._select_graphics("high")
    check(is_equal_approx(viewport.scaling_3d_scale,original_scale) and viewport.positional_shadow_atlas_size==original_atlas and Engine.max_fps==original_fps,"High restores preexisting display quality")
    check(sun.shadow_enabled==original_shadow and new_light.shadow_enabled,"High preserves original appearance including shadows")
    menu._select_graphics("low")
    var prefs:Variant=JSON.parse_string(FileAccess.get_file_as_string(graphics.PATH))
    check(prefs is Dictionary and prefs.get("quality","")=="low","Quality selection saved to a separate device-only file")
    check(graphics.read_preference()=="low" and graphics.get_parent()==menu,"Preference reload works without changing career save state")
    graphics.change("high")
    game.queue_free()
    await process_frame
    await process_frame
    check(Engine.max_fps==original_fps,"Graphics changes do not persist as a global FPS cap after exiting the game")
    print("GRAPHICS_PRESETS_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
    quit(0 if failures==0 else 1)
