extends Node
## Only local device graphics preferences. NEVER included in shared career/cloud saves.
const PATH:String = "user://graphics_preferences.json"
const PRESETS:Array[String] = ["low","medium","high"]
const DETAILS:Dictionary = {
    "low":"75% 3D resolution · fewer shadows · 30 FPS cap",
    "medium":"90% 3D resolution · regular shadows · 60 FPS cap",
    "high":"Native 3D resolution · original shadows · uncapped FPS"
}
var host:Node
var viewport:Viewport
var selected:String="high"
var original_scale:float=1.0
var original_shadow_atlas:int=2048
var original_fps:int=0

func setup(owner:Node)->void:
    host=owner
    viewport=owner.get_viewport()
    original_scale=viewport.scaling_3d_scale
    original_shadow_atlas=viewport.positional_shadow_atlas_size
    original_fps=Engine.max_fps
    selected=read_preference()
    if not get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.connect(_on_node_added)
    apply()

func read_preference()->String:
    if not FileAccess.file_exists(PATH):return "high"
    var data:Variant=JSON.parse_string(FileAccess.get_file_as_string(PATH))
    if not data is Dictionary:return "high"
    var name:String=str(data.get("quality","high")).to_lower()
    return name if PRESETS.has(name) else "high"

func change(value:String)->bool:
    if not PRESETS.has(value):return false
    selected=value
    apply()
    var file:FileAccess=FileAccess.open(PATH,FileAccess.WRITE)
    if file==null:return false
    file.store_string(JSON.stringify({"quality":selected}))
    return true

func profile(name:String)->Dictionary:
    if name=="low":return {"scale":0.75,"atlas":512,"fps":30,"shadows":false}
    if name=="medium":return {"scale":0.90,"atlas":1024,"fps":60,"shadows":true}
    return {"scale":original_scale,"atlas":original_shadow_atlas,"fps":original_fps,"shadows":true}

func apply()->void:
    if viewport==null:return
    var settings:Dictionary=profile(selected)
    Engine.max_fps=int(settings.fps)
    # Headless CI has no GPU and must not allocate temporary dummy render RIDs.
    # Native/Web games apply the same selected profile to their actual viewport.
    if DisplayServer.get_name()=="headless":return
    viewport.scaling_3d_mode=Viewport.SCALING_3D_MODE_BILINEAR
    viewport.scaling_3d_scale=float(settings.scale)
    viewport.positional_shadow_atlas_size=int(settings.atlas)
    if host!=null:
        for light in host.find_children("*","Light3D",true,false):
            _apply_light(light)

func _apply_light(node:Node)->void:
    if DisplayServer.get_name()=="headless":return
    if not is_instance_valid(node) or not node is Light3D:return
    var light:Light3D=node as Light3D
    if not light.has_meta("afb_quality_original_shadow"):
        light.set_meta("afb_quality_original_shadow",light.shadow_enabled)
    light.shadow_enabled=bool(light.get_meta("afb_quality_original_shadow",false)) and selected!="low"

func _on_node_added(node:Node)->void:
    if node is Light3D:call_deferred("_on_new_light_ready",node)

func _on_new_light_ready(node:Node)->void:
    if not is_instance_valid(node) or host==null:return
    if node!=host and not host.is_ancestor_of(node):return
    _apply_light(node)

func _exit_tree()->void:
    if get_tree()!=null and get_tree().node_added.is_connected(_on_node_added):
        get_tree().node_added.disconnect(_on_node_added)
    if is_instance_valid(viewport):
        viewport.scaling_3d_scale=original_scale
        viewport.positional_shadow_atlas_size=original_shadow_atlas
    Engine.max_fps=original_fps
