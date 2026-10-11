extends Node3D
## Cosmetic modular humanoid, attached to the approved AFewBuds 56-bone friend rig.
## Geometry is a prototype/fitting set: each body/garment/accessory is its own
## replaceable part, never a baked skin recolor or an NPC identity.
const Catalog=preload("res://scripts/avatar_catalog.gd")
const BASE=preload("res://assets/characters/Mike.glb")
var skeleton:Skeleton3D
var animation:AnimationPlayer
var modules:Dictionary={}
var current:Dictionary={}
var revision:int=0
var material_cache:Dictionary={}
func _ready()->void:
 var carrier:Node3D=BASE.instantiate()
 carrier.name="AFB_PlayerRig"
 add_child(carrier)
 var bones:Array[Node]=carrier.find_children("*","Skeleton3D",true,false)
 if bones.is_empty():
  push_error("AFB avatar: approved skeleton missing")
  return
 skeleton=bones[0] as Skeleton3D
 for mesh in carrier.find_children("*","MeshInstance3D",true,false):
  (mesh as MeshInstance3D).visible=false
 var players:Array[Node]=carrier.find_children("*","AnimationPlayer",true,false)
 if not players.is_empty():
  animation=players[0] as AnimationPlayer
  if animation.has_animation("idle"):animation.play("idle")
 rebuild(Catalog.defaults())
func material(color:Color,roughness:float=.82,metallic:float=0.0)->StandardMaterial3D:
 var key:String=color.to_html(true)+"_"+str(roughness)+"_"+str(metallic)
 if material_cache.has(key):return material_cache[key]
 var m:=StandardMaterial3D.new()
 m.albedo_color=color
 m.roughness=roughness
 m.metallic=metallic
 if color.a<.99:m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
 material_cache[key]=m
 return m
func color_value(key:String)->Color:
 return Color("#"+str(current.get(key,Catalog.DEFAULT.get(key,"888888"))))
func _create(slot:String,bone_name:String,mesh:Mesh,at:Vector3,scale_value:Vector3,color:Color,roughness:float=.82,metallic:float=0.0)->MeshInstance3D:
 if skeleton==null or skeleton.find_bone(bone_name)<0:return null
 var socket:=BoneAttachment3D.new()
 socket.name="Avatar_"+slot+"_"+str(revision)+"_"+str(modules.get(slot,[]).size())
 socket.bone_name=bone_name
 skeleton.add_child(socket)
 var part:=MeshInstance3D.new()
 part.name=slot.capitalize()
 part.mesh=mesh
 part.material_override=material(color,roughness,metallic)
 part.position=at
 part.scale=scale_value
 part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
 socket.add_child(part)
 if not modules.has(slot):modules[slot]=[]
 modules[slot].append(part)
 return part
func _ball(slot:String,bone:String,at:Vector3,dimensions:Vector3,color:Color,roughness:float=.82,metallic:float=0.0)->MeshInstance3D:
 var mesh:=SphereMesh.new()
 mesh.radius=1
 mesh.height=2
 mesh.radial_segments=16
 mesh.rings=9
 return _create(slot,bone,mesh,at,dimensions,color,roughness,metallic)
func _block(slot:String,bone:String,at:Vector3,dimensions:Vector3,color:Color,roughness:float=.82)->void:
 var mesh:=BoxMesh.new();mesh.size=Vector3.ONE
 _create(slot,bone,mesh,at,dimensions,color,roughness)
func _tube(slot:String,start:String,finish:String,radius:float,color:Color,fraction:float=1.0,roughness:float=.82)->void:
 var a:int=skeleton.find_bone(start)
 var b:int=skeleton.find_bone(finish)
 if a<0 or b<0:return
 var vector:Vector3=skeleton.get_bone_global_rest(a).affine_inverse()*skeleton.get_bone_global_rest(b).origin
 var length:float=vector.length()*fraction
 if length<.02:return
 var part:MeshInstance3D=_ball(slot,start,vector*fraction*.5,Vector3(radius,length*.54,radius),color,roughness)
 if part!=null:part.quaternion=Quaternion(Vector3.UP,vector.normalized())
func _skirt(slot:String,color:Color,long:bool=false)->void:
 var mesh:=CylinderMesh.new()
 mesh.top_radius=.22
 mesh.bottom_radius=.33 if long else .29
 mesh.height=.70 if long else .45
 mesh.radial_segments=20
 mesh.rings=3
 var base:=_create(slot,"Hips",mesh,Vector3(0,-.20 if long else -.12,0),Vector3.ONE,color)
 if base!=null:base.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
func rebuild(source:Variant)->void:
 current=Catalog.sanitize(source)
 if skeleton==null:return
 for child in skeleton.get_children():
  if child is BoneAttachment3D and str(child.name).begins_with("Avatar_"):
   skeleton.remove_child(child)
   child.queue_free()
 modules.clear()
 revision+=1
 var skin:Color=color_value("skin_color")
 var hair:Color=color_value("hair_color")
 var eyes:Color=color_value("eye_color")
 var fem:bool=str(current.body)=="feminine"
 var shoulders:float=.245 if not fem else .216
 var hips:float=.20 if not fem else .233
 var cheek:float=.135 if str(current.face)=="round" else (.121 if str(current.face)=="angular" else .13)
 var cheek_height:float=.168 if str(current.face)!="soft" else .163
 # The mesh below garments stays skin-toned; covered pieces are never drawn
 # through transparent material or treated as gameplay inventory.
 _ball("body","Hips",Vector3(0,.115,0),Vector3(hips,.24,.137),skin)
 _ball("body","Spine",Vector3(0,.19,0),Vector3(shoulders,.285,.142),skin)
 _ball("body","Neck",Vector3(0,.035,0),Vector3(.073,.10,.066),skin)
 _ball("body","Head",Vector3(0,.067,-.011),Vector3(cheek,cheek_height,.129),skin)
 for side in ["L","R"]:
  _tube("body","UpperArm_"+side,"LowerArm_"+side,.087,skin)
  _tube("body","LowerArm_"+side,"Hand_"+side,.067,skin)
  _tube("body","UpperLeg_"+side,"LowerLeg_"+side,.102,skin)
  _tube("body","LowerLeg_"+side,"Foot_"+side,.083,skin)
  _ball("body","Hand_"+side,Vector3(0,-.014,-.008),Vector3(.062,.075,.051),skin)
  _ball("body","Foot_"+side,Vector3(0,-.024,-.075),Vector3(.085,.055,.15),skin)
 # Distinct facial geometry; fitted to a bone that follows the shared animations.
 for side in [-1.0,1.0]:
  _ball("face","Head",Vector3(side*.055,.104,-.127),Vector3(.029,.024,.012),Color("f2eee5"))
  _ball("eyes","Head",Vector3(side*.055,.105,-.141),Vector3(.018,.018,.008),eyes,.25)
  _ball("face","Head",Vector3(side*.055,.145,-.133),Vector3(.044,.009,.009),hair)
 _ball("face","Head",Vector3(0,.039,-.135),Vector3(.027,.044,.027),skin)
 _ball("face","Head",Vector3(0,-.026,-.116),Vector3(.043,.011,.010),Color("8d5550"))
 _hair(hair)
 _facial_hair(hair)
 _clothing(shoulders,hips)
 _accessories()
func _hair(hair:Color)->void:
 var style:String=str(current.hair)
 if style=="bald":return
 var hat:bool=str(current.headwear)!="none"
 _ball("hair","Head",Vector3(0,.196,-.008),Vector3(.139,.072,.128),hair)
 if style in ["fade","short"]:
  _ball("hair","Head",Vector3(0,.202,-.052),Vector3(.138,.047,.103),hair)
 elif style=="swept":
  for i in range(5):
   _ball("hair","Head",Vector3(-.105+i*.055,.212+(4-i)*.009,-.075),Vector3(.060,.066,.070),hair)
 elif style=="wavy":
  for i in range(7):
   var angle:float=i*TAU/7.0
   _ball("hair","Head",Vector3(cos(angle)*.112,.21,sin(angle)*.10),Vector3(.058,.074,.057),hair)
 elif style=="curls":
  for i in range(13):
   var angle:float=i*TAU/13.0
   _ball("hair","Head",Vector3(cos(angle)*.12,.23+float(i%3)*.018,sin(angle)*.10),Vector3(.056,.059,.055),hair)
 elif style=="locs":
  for side in [-1.0,1.0]:
   for i in range(4):
    _ball("hair","Head",Vector3(side*(.113+float(i%2)*.013),.11-float(i)*.052,-.07+float(i%2)*.065),Vector3(.034,.104,.036),hair)
 elif style=="ponytail":
  _ball("hair","Head",Vector3(0,.135,.128),Vector3(.085,.12,.065),hair)
  _ball("hair","Head",Vector3(0,-.018,.15),Vector3(.058,.20,.055),hair)
 if hat:return
 for side in [-1.0,1.0]:
  if style in ["wavy","locs","ponytail"]:
   _ball("hair","Head",Vector3(side*.128,.051,.015),Vector3(.039,.115,.060),hair)
func _facial_hair(hair:Color)->void:
 match str(current.beard):
  "stubble":
   _ball("beard","Head",Vector3(0,-.048,-.093),Vector3(.091,.035,.037),hair.lightened(.27))
  "goatee":
   _ball("beard","Head",Vector3(0,-.057,-.113),Vector3(.052,.052,.023),hair)
  "full":
   _ball("beard","Head",Vector3(0,-.065,-.091),Vector3(.112,.083,.057),hair)
func _clothing(shoulders:float,hips:float)->void:
 var top_color:Color=color_value("top_color")
 var outer:Color=color_value("outerwear_color")
 var bottom:Color=color_value("bottom_color")
 var shoe:Color=color_value("shoe_color")
 var top:String=str(current.top)
 var covering:float=1.0 if top!="tank" else .88
 _ball("top","Spine",Vector3(0,.172,0),Vector3(shoulders*1.10,.29*covering,.157),top_color,.85)
 if top!="tank":
  for side in ["L","R"]:
   _tube("top","UpperArm_"+side,"LowerArm_"+side,.103,top_color,.32 if top in ["tee","button_shirt"] else .91)
 if top=="hoodie":
  _ball("top","Neck",Vector3(0,.065,.095),Vector3(.145,.15,.100),top_color)
  _ball("top","Hips",Vector3(0,.02,0),Vector3(hips*1.05,.095,.16),top_color)
 elif top=="button_shirt":
  for i in range(4):
   _ball("top_detail","Chest",Vector3(0,.04-i*.073,-.157),Vector3(.009,.009,.01),Color("dfd4bb"))
 elif top=="tank":
  for side in [-1.0,1.0]:
   _block("top_detail","UpperChest",Vector3(side*.128,.025,-.09),Vector3(.052,.19,.035),top_color)
 var outerwear:String=str(current.outerwear)
 if outerwear!="none":
  var coat_length:float=.38 if outerwear=="long_coat" else .28
  _ball("outerwear","Chest",Vector3(0,-.11,0),Vector3(shoulders*1.21,coat_length,.18),outer,.78)
  for side in ["L","R"]:_tube("outerwear","UpperArm_"+side,"LowerArm_"+side,.118,outer,.98)
  _block("outerwear_detail","UpperChest",Vector3(0,-.18,-.185),Vector3(.012,.27,.012),Color("c1bda8"))
  if outerwear=="long_coat":_skirt("outerwear",outer,true)
  if outerwear=="bomber":
   _ball("outerwear_detail","Hips",Vector3(0,.02,0),Vector3(hips*1.1,.07,.17),outer.darkened(.25))
 var pants:String=str(current.bottom)
 if pants=="skirt":_skirt("bottom",bottom)
 else:
  _ball("bottom","Hips",Vector3(0,.04,0),Vector3(hips*1.08,.20,.153),bottom)
  for side in ["L","R"]:
   _tube("bottom","UpperLeg_"+side,"LowerLeg_"+side,.122 if pants=="cargos" else .112,bottom,.42 if pants=="shorts" else 1.0)
   if pants!="shorts":_tube("bottom","LowerLeg_"+side,"Foot_"+side,.113 if pants=="cargos" else .103,bottom,.94)
   if pants=="cargos":
    _ball("bottom_detail","UpperLeg_"+side,Vector3(0,-.06,-.112),Vector3(.10,.115,.027),bottom.lightened(.12))
 for side in ["L","R"]:
  _ball("shoes","Foot_"+side,Vector3(0,-.029,-.077),Vector3(.128,.079,.186),shoe,.65)
  _ball("shoes","Foot_"+side,Vector3(0,-.083,-.071),Vector3(.13,.023,.18),Color("f0ede2"),.89)
  if str(current.shoes)=="high_tops":
   _ball("shoes","Foot_"+side,Vector3(0,.045,.001),Vector3(.112,.14,.108),shoe)
  elif str(current.shoes)=="boots":
   _ball("shoes","Foot_"+side,Vector3(0,.083,.012),Vector3(.126,.205,.118),shoe.darkened(.12))
func _accessories()->void:
 var hair:Color=color_value("hair_color")
 var headwear_color:Color=color_value("headwear_color")
 match str(current.headwear):
  "cap":
   _ball("headwear","Head",Vector3(0,.225,-.007),Vector3(.148,.075,.144),headwear_color)
   _block("headwear","Head",Vector3(0,.206,-.179),Vector3(.20,.019,.175),headwear_color)
  "beanie":
   _ball("headwear","Head",Vector3(0,.234,-.004),Vector3(.150,.106,.147),headwear_color)
   _ball("headwear","Head",Vector3(0,.169,-.012),Vector3(.147,.035,.141),headwear_color.darkened(.19))
 match str(current.glasses):
  "clear","sunglasses":
   var dark:bool=str(current.glasses)=="sunglasses"
   var lens_color:Color=Color(.08,.14,.16,.94) if dark else Color(.61,.75,.73,.42)
   for side in [-1.0,1.0]:
    _ball("glasses","Head",Vector3(side*.066,.107,-.157),Vector3(.059,.045,.013),lens_color,.15)
    _block("glasses","Head",Vector3(side*.108,.112,-.137),Vector3(.065,.012,.014),Color("3e443e"))
   _block("glasses","Head",Vector3(0,.116,-.160),Vector3(.06,.011,.014),Color("3e443e"))
 if str(current.gloves)!="none":
  var glove_color:Color=Color("555b58") if str(current.gloves)=="fabric" else Color("302824")
  for side in ["L","R"]:
   _ball("gloves","Hand_"+side,Vector3(0,-.014,-.01),Vector3(.067,.082,.062),glove_color)
 if str(current.bag)!="none":
  var bag_color:Color=color_value("bag_color")
  var daypack:bool=str(current.bag)=="daypack"
  _ball("bag","UpperChest",Vector3(0,-.18,.19) if daypack else Vector3(-.14,-.22,.14),Vector3(.19,.26,.13) if daypack else Vector3(.14,.17,.075),bag_color,.85)
  if daypack:
   for side in [-1.0,1.0]:
    _ball("bag","UpperChest",Vector3(side*.17,-.07,.06),Vector3(.025,.25,.06),bag_color.darkened(.28))
 if str(current.jewelry)=="studs":
  for side in [-1.0,1.0]:
   _ball("jewelry","Head",Vector3(side*.135,-.01,-.001),Vector3(.016,.02,.018),Color("d6bf7a"),.28,.75)
 elif str(current.jewelry)=="chain":
  _ball("jewelry","Neck",Vector3(0,-.052,-.086),Vector3(.105,.018,.016),Color("d6bf7a"),.28,.70)
func play_preview(clip:String)->void:
 if animation!=null and animation.has_animation(clip):animation.play(clip,.15)
func part_count(slot:String)->int:
 return modules.get(slot,[]).size()
