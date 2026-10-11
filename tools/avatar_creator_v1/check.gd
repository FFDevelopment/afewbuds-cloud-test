extends SceneTree
## Additive player-only appearance, modular rig preview and existing-career safety.
var checks:int=0
var failures:int=0
func check(ok:bool,title:String)->void:
 checks+=1
 if not ok:failures+=1;push_error("AVATAR_CREATOR FAIL: "+title)
func _initialize()->void:call_deferred("run")
func run()->void:
 var catalog=load("res://scripts/avatar_catalog.gd")
 var defaults:Dictionary=catalog.defaults()
 check(catalog.option_count()>=45,"Independent body, hair, clothes and accessories are cataloged")
 var corrupted:Dictionary={"body":"invalid","hair":"curls","top":"hoodie","skin_color":"xyz","top_color":"#ab2134","bottom":"skirt","bag":"satchel","extra":"do-not-copy"}
 var clean:Dictionary=catalog.sanitize(corrupted)
 check(clean.body=="masculine" and clean.hair=="curls" and clean.top=="hoodie" and clean.bottom=="skirt" and clean.bag=="satchel","Invalid body rejected; valid pieces retained")
 check(clean.skin_color==defaults.skin_color and clean.top_color=="ab2134" and not clean.has("extra"),"Untrusted save fields sanitized")
 var old_record={"schema":0,"created":true,"appearance":clean,"future_attribute":"preserve"}
 var restored:Dictionary=catalog.record_from(old_record)
 check(restored.future_attribute=="preserve" and restored.owner_kind=="player_only" and not restored.npc_spawn_allowed and not restored.sale_listing_allowed,"Reserved player-only appearance never exposed as NPC or sale listing")
 var avatar:Node3D=load("res://scripts/avatar_visual.gd").new()
 root.add_child(avatar)
 await process_frame
 check(avatar.skeleton!=null and avatar.skeleton.get_bone_count()>=56,"Approved AFewBuds skeleton drives player preview")
 if avatar.skeleton!=null:
  check(avatar.part_count("body")>=10 and avatar.part_count("top")>0 and avatar.part_count("bottom")>0 and avatar.part_count("shoes")>0,"Body and outfit are separate replaceable mesh modules")
  var alternate:Dictionary=defaults.duplicate(true)
  alternate.body="feminine";alternate.hair="locs";alternate.beard="full"
  alternate.top="hoodie";alternate.outerwear="bomber";alternate.bottom="skirt"
  alternate.headwear="cap";alternate.glasses="clear";alternate.gloves="leather"
  alternate.bag="daypack";alternate.jewelry="studs"
  avatar.rebuild(alternate)
  check(avatar.part_count("hair")>1 and avatar.part_count("outerwear")>0 and avatar.part_count("headwear")>0 and avatar.part_count("glasses")>0 and avatar.part_count("gloves")>0 and avatar.part_count("bag")>0 and avatar.part_count("jewelry")>0,"Swapping all clothing slots rebuilds visible independent geometry")
  check(str(avatar.current.body)=="feminine","Feminine body fit uses the same skeletal animation contract")
 avatar.queue_free()
 await process_frame
 var desktop:bool=ResourceLoader.exists("res://prototype/apartment.tscn")
 if root.has_node("AFBCloud"):await root.get_node("AFBCloud").prepare(true)
 var path:String="res://prototype/apartment.tscn" if desktop else "res://scenes/main.tscn"
 var game:Node3D=load(path).instantiate()
 root.add_child(game)
 for i in 12:await process_frame
 game.set_process(false)
 game.neighborhood.set_process(false)
 game._pause_gameplay()
 var menu:Node=game.inventory_system.session_menu
 menu.show_page("settings")
 var has_button:bool=false
 for button in menu.body.find_children("*","Button",true,false):
  if button.text=="CHARACTER & WARDROBE":has_button=true
 check(has_button,"Pause Settings exposes character editor on both platforms")
 var balance:int=game.cash
 var property_state:Dictionary=game.property_opportunity_state.duplicate(true)
 var was_created:bool=game.location_state.has("player_avatar_v1")
 var old_appearance:Variant=game.location_state.get("player_avatar_v1",{}).duplicate(true) if was_created else {}
 menu._open_avatar()
 var editor:Node=menu.avatar_editor
 check(editor!=null and editor.visible and editor.preview_model!=null and editor.camera!=null,"Rotating 3D character editor opens with independent camera")
 if editor!=null:
  editor.draft["top"]="hoodie"
  editor._refresh_preview()
  editor._cancel()
  check(not editor.visible and (game.location_state.get("player_avatar_v1",{})==old_appearance),"Cancel does not mutate career")
  menu._open_avatar()
  editor.draft["body"]="feminine"
  editor.draft["hair"]="ponytail"
  editor.draft["top"]="button_shirt"
  editor.draft["outerwear"]="denim_jacket"
  editor.draft["bottom"]="cargos"
  editor.draft["skin_color"]="bc8864"
  editor._save()
  var stored:Dictionary=game.location_state.get("player_avatar_v1",{})
  check(stored.get("created",false) and int(stored.get("schema",0))==1 and str(stored.get("owner_kind",""))=="player_only","Save adds versioned player-only avatar record")
  var look:Dictionary=stored.get("appearance",{})
  check(look.get("body","")=="feminine" and look.get("top","")=="button_shirt" and look.get("hair","")=="ponytail" and look.get("skin_color","")=="bc8864","Appearance survives serialization with separate pieces")
  var roundtrip:Variant=JSON.parse_string(JSON.stringify(game.location_state))
  check(roundtrip is Dictionary and roundtrip.player_avatar_v1.appearance.bottom=="cargos","Existing cloud JSON contract carries new outfit unchanged")
  check(game.cash==balance and game.property_opportunity_state==property_state,"Editing appearance preserves money and property progression")
  check(not editor.visible and game.session_paused,"Saving closes editor but leaves gameplay paused")
 game.queue_free()
 for i in 3:await process_frame
 print("AVATAR_CREATOR_RESULT: "+("PASS" if failures==0 else "FAIL")+" checks="+str(checks))
 quit(0 if failures==0 else 1)
