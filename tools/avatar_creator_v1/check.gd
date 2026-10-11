extends SceneTree
## Isolated cloud-career fixture + approved rig and modular-slot validation.
## Render previews are deliberately disabled on headless CI's dummy GPU.
class FakeHost:
 extends Node3D
 var location_state:Dictionary={
  "furniture_v1":{"items":{"keep_tent":{"sku":"tent_1","property":"house"}}},
  "container_inventory":{"backpack":{"seed|Purple Dream":4}}
 }
 var property_opportunity_state:Dictionary={"acquired":true,"relocated":true}
 var cash:int=4200
 var last_save_ok:bool=false
 var saves:int=0
 var saved_json:String=""
 var pause_message:Label=Label.new()
 func _save_game()->void:
  last_save_ok=true
  saves+=1
  saved_json=JSON.stringify({"location_state":location_state,"cash":cash,"property_opportunity_state":property_opportunity_state})
class FakeMenu:
 extends Node
 var avatar_editor:CanvasLayer
 var cloud_locked:bool=false
 var quitting:bool=false
 var page:String=""
 func show_page(target:String)->void:page=target
var checks:int=0
var failures:int=0
func check(ok:bool,title:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("AVATAR_CREATOR FAIL: "+title)
func _initialize()->void:call_deferred("run")
func run()->void:
 var catalog=load("res://scripts/avatar_catalog.gd")
 var look:Dictionary=catalog.defaults()
 check(catalog.option_count()>=45,"Appearance has modular body, hair, outfits and accessories")
 var bad:Dictionary={"body":"invalid","hair":"curls","top":"hoodie","skin_color":"not-a-color","top_color":"#ab2134","bottom":"skirt","bag":"satchel","extra":"reject"}
 var clean:Dictionary=catalog.sanitize(bad)
 check(clean.body=="masculine" and clean.hair=="curls" and clean.top=="hoodie" and clean.bottom=="skirt" and clean.bag=="satchel","Invalid silhouette rejected; valid wardrobe selections preserved")
 check(clean.skin_color==look.skin_color and clean.top_color=="ab2134" and not clean.has("extra"),"Arbitrary/untrusted colors and options are sanitized")
 var unknown:Dictionary={"schema":0,"created":true,"appearance":clean,"future_field":"keep"}
 var record:Dictionary=catalog.record_from(unknown)
 check(record.future_field=="keep" and record.owner_kind=="player_only" and not record.npc_spawn_allowed and not record.sale_listing_allowed,"Versioned player-only record keeps future extensions and cannot become NPC stock")
 var avatar:Node3D=load("res://scripts/avatar_visual.gd").new()
 root.add_child(avatar)
 await process_frame
 check(avatar.skeleton!=null and avatar.skeleton.get_bone_count()>=56,"Approved 56-bone AFewBuds rig used for player model")
 if avatar.skeleton!=null:
  check(avatar.part_count("body")>=10 and avatar.part_count("top")>0 and avatar.part_count("bottom")>0 and avatar.part_count("shoes")>0,"Skin, clothing and footwear are independently replaceable meshes")
  var alternate:Dictionary=look.duplicate(true)
  alternate.body="feminine";alternate.hair="locs";alternate.beard="full"
  alternate.top="hoodie";alternate.outerwear="bomber";alternate.bottom="skirt"
  alternate.headwear="cap";alternate.glasses="clear";alternate.gloves="leather"
  alternate.bag="daypack";alternate.jewelry="studs"
  avatar.rebuild(alternate)
  check(avatar.part_count("hair")>1 and avatar.part_count("outerwear")>0 and avatar.part_count("headwear")>0 and avatar.part_count("glasses")>0 and avatar.part_count("gloves")>0 and avatar.part_count("bag")>0 and avatar.part_count("jewelry")>0,"All garment/accessory modules regenerate on appearance changes")
  check(avatar.current.body=="feminine","Feminine body fit preserves common skeleton")
 avatar.queue_free()
 avatar=null
 for i in 5:await process_frame
 var menu_code:String=FileAccess.get_file_as_string("res://scripts/session_menu.gd")
 check(menu_code.contains("CHARACTER & WARDROBE") and menu_code.contains("avatar_editor.open(host,self)"),"Both games route Pause Settings to shared avatar editor")
 var host:=FakeHost.new()
 root.add_child(host)
 var menu:=FakeMenu.new()
 host.add_child(menu)
 var previous:String=JSON.stringify(host.location_state)
 var editor=load("res://scripts/avatar_editor.gd").new()
 host.add_child(editor)
 menu.avatar_editor=editor
 editor.open(host,menu)
 check(editor.visible and editor.preview_model!=null and editor.camera!=null,"Preview has independent character model and camera")
 editor.draft["top"]="hoodie"
 editor._refresh_preview()
 editor._cancel()
 check(not editor.visible and JSON.stringify(host.location_state)==previous,"Cancel never changes an existing career")
 for i in 5:await process_frame
 editor=load("res://scripts/avatar_editor.gd").new()
 host.add_child(editor)
 menu.avatar_editor=editor
 editor.open(host,menu)
 editor.draft["body"]="feminine"
 editor.draft["hair"]="ponytail"
 editor.draft["top"]="button_shirt"
 editor.draft["outerwear"]="denim_jacket"
 editor.draft["bottom"]="cargos"
 editor.draft["skin_color"]="bc8864"
 editor._save()
 var record_saved:Dictionary=host.location_state.get("player_avatar_v1",{})
 var outfit:Dictionary=record_saved.get("appearance",{})
 check(record_saved.get("created",false) and record_saved.get("schema",0)==1 and record_saved.get("owner_kind","")=="player_only","Saving creates additive versioned player-owned avatar record")
 check(outfit.get("body","")=="feminine" and outfit.get("hair","")=="ponytail" and outfit.get("top","")=="button_shirt" and outfit.get("skin_color","")=="bc8864","Separate outfit and skin choices survive save")
 var persisted:Variant=JSON.parse_string(host.saved_json)
 check(persisted.location_state.player_avatar_v1.appearance.bottom=="cargos" and persisted.location_state.container_inventory.backpack["seed|Purple Dream"]==4,"Cloud-career JSON preserves wardrobe and inventory without rewrites")
 check(host.cash==4200 and host.property_opportunity_state.acquired and host.location_state.furniture_v1.items.has("keep_tent") and host.saves==1,"No money/property/furniture changes and no writes until Save")
 check(not editor.visible and menu.page=="settings","Save closes editor and returns to Pause Settings")
 host.queue_free()
 menu=null
 editor=null
 host=null
 for i in 12:await process_frame
 print("AVATAR_CREATOR_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks))
 quit(0 if failures==0 else 1)
