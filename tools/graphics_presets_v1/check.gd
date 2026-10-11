extends SceneTree
## Headless-safe graphics settings regression. Full gameplay tests cover pause UI.
var checks:int=0
var failures:int=0
func check(condition:bool,note:String)->void:
    checks+=1
    if condition:print("PASS: "+note)
    else:failures+=1;push_error("GRAPHICS_PRESET FAIL: "+note)
func _initialize()->void:call_deferred("run")
func run()->void:
    var source:String=FileAccess.get_file_as_string("res://scripts/session_menu.gd")
    check(source.contains("for preset in [\"low\",\"medium\",\"high\"]") and source.contains("GRAPHICS QUALITY"),"Pause Settings contains all three graphics choices")
    check(source.contains("graphics.change(preset)") and source.contains("graphics.selected"),"Pause options update and indicate the active preset")
    var host:Node3D=Node3D.new()
    root.add_child(host)
    var graphics:Node=load("res://scripts/graphics_quality.gd").new()
    host.add_child(graphics)
    graphics.setup(host)
    var previous_fps:int=graphics.original_fps
    var original_scale:float=graphics.original_scale
    var original_atlas:int=graphics.original_shadow_atlas
    check(graphics.selected=="high","Default preserves existing rendering quality")
    check(graphics.change("low") and graphics.selected=="low","Low preset can be selected")
    check(is_equal_approx(float(graphics.profile("low").scale),.75) and int(graphics.profile("low").atlas)==512 and Engine.max_fps==30 and not bool(graphics.profile("low").shadows),"Low reduces 3D detail and shadow cost with 30 FPS cap")
    check(graphics.change("medium") and graphics.selected=="medium","Medium preset can be selected")
    check(is_equal_approx(float(graphics.profile("medium").scale),.9) and int(graphics.profile("medium").atlas)==1024 and Engine.max_fps==60,"Medium balances quality and performance")
    check(not graphics.change("invalid") and graphics.selected=="medium","Invalid preset cannot alter settings")
    check(graphics.change("high"),"High preset can be restored")
    check(is_equal_approx(float(graphics.profile("high").scale),original_scale) and int(graphics.profile("high").atlas)==original_atlas and Engine.max_fps==previous_fps,"High restores the original renderer and FPS settings")
    check(graphics.change("low") and graphics.read_preference()=="low","Device-only quality choice persists locally")
    var prefs:Variant=JSON.parse_string(FileAccess.get_file_as_string(graphics.PATH))
    check(prefs is Dictionary and prefs.get("quality","")=="low","Preferences are written outside the career save")
    graphics.change("high")
    host.queue_free()
    await process_frame
    await process_frame
    check(Engine.max_fps==previous_fps,"Closing the game restores the engine frame limit")
    print("GRAPHICS_PRESETS_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks)+" failures="+str(failures))
    quit(0 if failures==0 else 1)
