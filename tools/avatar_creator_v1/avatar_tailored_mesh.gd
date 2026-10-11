extends RefCounted
## AFewBuds v2 tailored streetwear geometry.
## A cross-platform, weighted-mesh fitting stage: anatomy and garments are
## continuous tapered meshes rather than stacked spheres or capsules.
## All vertices reference the original 56-bone skeleton, so clothing follows
## one shared animation contract on web and desktop. No career data is touched.
const RADIAL:int=16
var model:Node3D
var sk:Skeleton3D
var look:Dictionary
var modules:Dictionary
var mats:Dictionary={}
var fem:bool=false
var skin:Color
var hair:Color
var cloth:Color
var pants:Color
var shoes:Color
var shoulders:float
var waist:float
var hips:float

func build(owner:Node3D,rig:Skeleton3D,appearance:Dictionary,parts:Dictionary)->void:
 model=owner
 sk=rig
 look=appearance
 modules=parts
 fem=str(look.get("body","masculine"))=="feminine"
 shoulders=.237 if fem else .276
 waist=.175 if fem else .203
 hips=.255 if fem else .218
 skin=tint("skin_color","af8667")
 hair=tint("hair_color","201b19")
 cloth=tint("top_color","426d59")
 pants=tint("bottom_color","405066")
 shoes=tint("shoe_color","e6e6dc")
 _anatomy()
 _face()
 _hairstyle()
 _outfit()
 _details()

func tint(slot:String,fallback:String)->Color:
 return Color("#"+str(look.get(slot,fallback)))

func tone(color:Color,amount:float)->Color:
 return color.lightened(amount) if amount>=0 else color.darkened(-amount)

func mat(color:Color,rough:float=.84,metal:float=0.0)->StandardMaterial3D:
 var key:String=color.to_html(true)+"-"+str(rough)+"-"+str(metal)
 if mats.has(key):return mats[key]
 var res:=StandardMaterial3D.new()
 res.albedo_color=color
 res.roughness=rough
 res.metallic=metal
 res.cull_mode=BaseMaterial3D.CULL_DISABLED
 mats[key]=res
 return res

func section(point:Vector3,radii:Vector2,primary:String,secondary:String="",influence:float=1.0)->Dictionary:
 return {"p":point,"r":radii,"a":primary,"b":secondary if not secondary.is_empty() else primary,"w":clampf(influence,0,1)}

# Each ring has skin indices and two-bone weights. SurfaceTool emits a mesh
# with SKIN_4_WEIGHTS for Godot's standard Skeleton3D deformation pipeline.
func loft(slot:String,name:String,axis:String,rings:Array,color:Color,segments:int=RADIAL,rough:float=.84)->MeshInstance3D:
 if rings.size()<2 or sk==null:return null
 var st:=SurfaceTool.new()
 st.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
 st.begin(Mesh.PRIMITIVE_TRIANGLES)
 for k in range(rings.size()):
  var ring:Dictionary=rings[k]
  var center:Vector3=ring.p
  var radius:Vector2=ring.r
  var bone_a:int=maxi(0,sk.find_bone(str(ring.a)))
  var bone_b:int=maxi(0,sk.find_bone(str(ring.b)))
  var w:float=float(ring.w)
  for i in range(segments):
   var u:float=float(i)/float(segments)
   var angle:float=u*TAU
   var cos_v:float=cos(angle)
   var sin_v:float=sin(angle)
   var point:Vector3
   var normal:Vector3
   if axis=="x":
    point=center+Vector3(0,cos_v*radius.x,sin_v*radius.y)
    normal=Vector3(0,cos_v/maxf(radius.x,.001),sin_v/maxf(radius.y,.001)).normalized()
   elif axis=="z":
    point=center+Vector3(cos_v*radius.x,sin_v*radius.y,0)
    normal=Vector3(cos_v/maxf(radius.x,.001),sin_v/maxf(radius.y,.001),0).normalized()
   else:
    point=center+Vector3(cos_v*radius.x,0,sin_v*radius.y)
    normal=Vector3(cos_v/maxf(radius.x,.001),0,sin_v/maxf(radius.y,.001)).normalized()
   st.set_bones(PackedInt32Array([bone_a,bone_b,0,0]))
   st.set_weights(PackedFloat32Array([w,1.0-w,0,0]))
   st.set_normal(normal)
   st.set_uv(Vector2(u,float(k)/float(rings.size()-1)))
   st.add_vertex(point)
 for k in range(rings.size()-1):
  for i in range(segments):
   var a:int=k*segments+i
   var b:int=k*segments+(i+1)%segments
   var c:int=(k+1)*segments+i
   var d:int=(k+1)*segments+(i+1)%segments
   # Two-sided materials keep winding consistent across left/right limbs.
   st.add_index(a);st.add_index(c);st.add_index(b)
   st.add_index(b);st.add_index(c);st.add_index(d)
 var geometry:ArrayMesh=st.commit()
 var instance:=MeshInstance3D.new()
 instance.name=name
 instance.mesh=geometry
 instance.material_override=mat(color,rough)
 model.add_child(instance)
 instance.skeleton=instance.get_path_to(sk)
 instance.set_meta("afb_tailored",true)
 if not modules.has(slot):modules[slot]=[]
 modules[slot].append(instance)
 return instance

func box_on(slot:String,name:String,bone:String,position:Vector3,dimensions:Vector3,color:Color,metal:float=0.0)->void:
 if sk.find_bone(bone)<0:return
 var attachment:=BoneAttachment3D.new()
 attachment.bone_name=bone
 attachment.name="AvatarTailor_"+name
 sk.add_child(attachment)
 var instance:=MeshInstance3D.new()
 var shape:=BoxMesh.new()
 shape.size=Vector3.ONE
 instance.mesh=shape
 instance.scale=dimensions
 instance.position=position
 instance.material_override=mat(color,.78,metal)
 instance.name=name
 attachment.add_child(instance)
 if not modules.has(slot):modules[slot]=[]
 modules[slot].append(instance)

func spine_rings(pad:float=0.0)->Array:
 return [
  section(Vector3(0,.835,0),Vector2(hips*.83+pad,.120+pad),"Hips"),
  section(Vector3(0,.925,0),Vector2(hips+pad,.147+pad),"Hips"),
  section(Vector3(0,1.075,0),Vector2(waist+pad,.125+pad),"Spine"),
  section(Vector3(0,1.185,-.002),Vector2(waist+.024+pad,.141+pad),"Spine","Chest",.40),
  section(Vector3(0,1.290,-.005),Vector2(shoulders*.90+pad,.151+pad),"Chest"),
  section(Vector3(0,1.375,0),Vector2(shoulders+pad,.152+pad),"UpperChest"),
  section(Vector3(0,1.420,0),Vector2(shoulders*.77+pad,.117+pad),"UpperChest"),
  section(Vector3(0,1.473,0),Vector2(.070+pad,.070+pad),"Neck"),
  section(Vector3(0,1.505,0),Vector2(.061+pad,.061+pad),"Neck")
 ]

func arm_rings(side:String,pad:float=0.0,length_part:float=1.0)->Array:
 var s:float=1.0 if side=="L" else -1.0
 var top:String="UpperArm_"+side
 var elbow:String="LowerArm_"+side
 var wrist:String="Hand_"+side
 var rings:Array=[
  section(Vector3(s*.170,1.403,0),Vector2(.093+pad,.089+pad),top),
  section(Vector3(s*.215,1.405,0),Vector2(.100+pad,.096+pad),top),
  section(Vector3(s*.295,1.401,0),Vector2(.091+pad,.089+pad),top),
  section(Vector3(s*.390,1.399,0),Vector2(.082+pad,.083+pad),top,elbow,.74),
  section(Vector3(s*.465,1.398,0),Vector2(.075+pad,.076+pad),elbow),
  section(Vector3(s*.555,1.397,0),Vector2(.073+pad,.071+pad),elbow),
  section(Vector3(s*.647,1.399,0),Vector2(.064+pad,.061+pad),elbow,wrist,.75),
  section(Vector3(s*.710,1.399,0),Vector2(.055+pad,.053+pad),wrist)
 ]
 if length_part<.99:
  var count:int=4 if length_part<=.48 else 6
  return rings.slice(0,count)
 return rings

func leg_rings(side:String,pad:float=0.0,short:bool=false)->Array:
 var s:float=1.0 if side=="L" else -1.0
 var upper:String="UpperLeg_"+side
 var lower:String="LowerLeg_"+side
 var ankle:String="Foot_"+side
 var results:Array=[
  section(Vector3(s*.110,.918,0),Vector2(.119+pad,.123+pad),upper),
  section(Vector3(s*.111,.830,0),Vector2(.121+pad,.123+pad),upper),
  section(Vector3(s*.110,.688,-.006),Vector2(.113+pad,.117+pad),upper),
  section(Vector3(s*.111,.553,-.009),Vector2(.090+pad,.092+pad),upper,lower,.7),
  section(Vector3(s*.110,.450,-.013),Vector2(.084+pad,.083+pad),lower),
  section(Vector3(s*.110,.338,-.015),Vector2(.092+pad,.092+pad),lower),
  section(Vector3(s*.110,.204,-.014),Vector2(.074+pad,.072+pad),lower),
  section(Vector3(s*.111,.100,-.012),Vector2(.065+pad,.067+pad),lower,ankle,.66)
 ]
 return results.slice(0,4) if short else results

func face_rings()->Array:
 var wide:float=.96 if fem else 1.0
 var shape:String=str(look.get("face","balanced"))
 var jaw:float=.112 if shape=="angular" else (.124 if shape=="round" else .107)
 if fem:jaw*=.94
 return [
  section(Vector3(0,1.555,-.002),Vector2(.058,.073),"Head"),
  section(Vector3(0,1.582,-.007),Vector2(jaw*.80,.092),"Head"),
  section(Vector3(0,1.632,0),Vector2(jaw,.107),"Head"),
  section(Vector3(0,1.713,-.001),Vector2(.138*wide,.135),"Head"),
  section(Vector3(0,1.798,0),Vector2(.142*wide,.134),"Head"),
  section(Vector3(0,1.869,.006),Vector2(.137*wide,.121),"Head"),
  section(Vector3(0,1.920,.008),Vector2(.110*wide,.107),"Head"),
  section(Vector3(0,1.945,.008),Vector2(.030,.036),"Head")
 ]

func _anatomy()->void:
 loft("body","Anatomical torso","y",spine_rings(),skin)
 loft("body","Natural neck","y",[
  section(Vector3(0,1.447,0),Vector2(.073,.071),"Neck"),
  section(Vector3(0,1.507,0),Vector2(.069,.067),"Neck"),
  section(Vector3(0,1.569,0),Vector2(.078,.078),"Head")
 ],skin,12)
 loft("body","Sculpted head","y",face_rings(),skin,20)
 for side in ["L","R"]:
  loft("body","Continuous "+side+" arm","x",arm_rings(side),skin)
  loft("body","Continuous "+side+" leg","y",leg_rings(side),skin)
  var s:float=1.0 if side=="L" else -1.0
  loft("body","Hand palm "+side,"x",[
   section(Vector3(s*.704,1.398,0),Vector2(.055,.053),"Hand_"+side),
   section(Vector3(s*.759,1.398,-.001),Vector2(.064,.062),"Hand_"+side),
   section(Vector3(s*.813,1.398,-.003),Vector2(.049,.051),"Hand_"+side),
   section(Vector3(s*.841,1.398,0),Vector2(.012,.012),"Hand_"+side)
  ],skin,10)
  # One recognizable thumb, separate from the palm; no floating ball joints.
  loft("body","Fitted thumb "+side,"x",[
   section(Vector3(s*.739,1.366,-.043),Vector2(.024,.026),"Hand_"+side),
   section(Vector3(s*.783,1.356,-.054),Vector2(.025,.026),"Hand_"+side),
   section(Vector3(s*.814,1.349,-.060),Vector2(.007,.010),"Hand_"+side)
  ],skin,10)
  loft("body","Natural ankle "+side,"y",[
   section(Vector3(s*.111,.096,-.012),Vector2(.067,.066),"Foot_"+side),
   section(Vector3(s*.111,.048,-.061),Vector2(.086,.076),"Foot_"+side)
  ],skin,12)

func _face()->void:
 for side in [-1.0,1.0]:
  var x:float=side*.054
  box_on("face","Eye white","Head",Vector3(x,.175,-.133),Vector3(.060,.030,.012),Color("eee6dc"))
  box_on("face","Iris","Head",Vector3(x,.175,-.143),Vector3(.023,.023,.012),tint("eye_color","403528"))
  box_on("face","Pupil","Head",Vector3(x,.175,-.151),Vector3(.009,.014,.006),Color("151814"))
  box_on("face","Eyebrow","Head",Vector3(x,.212,-.131),Vector3(.071,.014,.018),tone(hair,-.08))
  loft("face","Ear","y",[
   section(Vector3(side*.137,1.691,0),Vector2(.025,.031),"Head"),
   section(Vector3(side*.154,1.738,0),Vector2(.030,.034),"Head"),
   section(Vector3(side*.137,1.773,0),Vector2(.020,.025),"Head")
  ],skin,10)
 # Shape nose as one tapered bridge, instead of a round protrusion.
 loft("face","Nose","y",[
  section(Vector3(0,1.674,-.151),Vector2(.025,.027),"Head"),
  section(Vector3(0,1.707,-.144),Vector2(.017,.026),"Head"),
  section(Vector3(0,1.755,-.119),Vector2(.014,.016),"Head")
 ],tone(skin,-.03),10)
 box_on("face","Upper lip","Head",Vector3(0,.060,-.113),Vector3(.070,.011,.012),tone(skin,-.28))
 box_on("face","Lower lip","Head",Vector3(0,.037,-.109),Vector3(.058,.010,.011),tone(skin,-.16))
 # Forehead is part of the sculpted head, not a separate floating sphere.

func _hairstyle()->void:
 var style:String=str(look.get("hair","short"))
 if style=="bald":return
 var tall:float=.022 if style in ["short","fade"] else (.059 if style in ["swept","locs","ponytail"] else .084)
 loft("hair","Natural hairline","y",[
  section(Vector3(0,1.823,.005),Vector2(.138,.121),"Head"),
  section(Vector3(0,1.876,.009),Vector2(.142,.130),"Head"),
  section(Vector3(0,1.945+tall,.007),Vector2(.129,.120),"Head"),
  section(Vector3(0,1.965+tall,.008),Vector2(.070,.070),"Head")
 ],hair,20)
 if style=="fade":
  # A sharper tapered fade retains visible natural side hair.
  for side in [-1.0,1.0]:
   box_on("hair","Fade temple","Head",Vector3(side*.129,.222,-.006),Vector3(.015,.06,.091),tone(hair,.15))
 elif style=="swept":
  for i in range(5):
   loft("hair","Swept strands","y",[
    section(Vector3(-.113+i*.055,1.941,-.074),Vector2(.047,.064),"Head"),
    section(Vector3(-.111+i*.055,2.032+float(4-i)*.012,-.089),Vector2(.038,.048),"Head"),
    section(Vector3(-.067+i*.047,2.053+float(4-i)*.010,-.102),Vector2(.006,.012),"Head")
   ],tone(hair,float(i%3)*.06),8)
 elif style in ["wavy","curls"]:
  var count:int=10 if style=="wavy" else 14
  for i in range(count):
   var theta:float=TAU*float(i)/float(count)
   var x:float=.096*cos(theta)
   var z:float=.092*sin(theta)
   var top:float=2.043+float(i%4)*.015
   loft("hair","Textured curl","y",[
    section(Vector3(x,1.969,z),Vector2(.038,.042),"Head"),
    section(Vector3(x*1.13,top-.021,z*1.12),Vector2(.045,.047),"Head"),
    section(Vector3(x*1.17,top+.025,z*1.14),Vector2(.008,.010),"Head")
   ],tone(hair,float(i%4)*.035),8)
 elif style=="locs":
  for side in [-1.0,1.0]:
   for i in range(4):
    var x:float=side*(.112+float(i%2)*.017)
    var z:float=-.059+float(i)*.045
    loft("hair","Hanging loc","y",[
     section(Vector3(x,1.645,z),Vector2(.022,.026),"Head"),
     section(Vector3(x*1.08,1.758,z+.003),Vector2(.028,.028),"Head"),
     section(Vector3(x,1.923,z+.005),Vector2(.025,.026),"Head")
    ],tone(hair,float(i%3)*.06),8)
 elif style=="ponytail":
  loft("hair","Pulled back ponytail","y",[
   section(Vector3(0,1.662,.190),Vector2(.050,.054),"Head"),
   section(Vector3(0,1.807,.171),Vector2(.063,.065),"Head"),
   section(Vector3(0,1.912,.138),Vector2(.069,.069),"Head")
  ],hair,12)

func _beard()->void:
 var name:String=str(look.get("beard","none"))
 if name=="none":return
 var color:Color=tone(hair,.065 if name=="stubble" else 0.0)
 var extent:float=.035 if name=="stubble" else (.08 if name=="goatee" else .118)
 loft("beard","Fitted facial hair","y",[
  section(Vector3(0,1.557,-.077),Vector2(.035,.021),"Head"),
  section(Vector3(0,1.602,-.108),Vector2(extent,.027),"Head"),
  section(Vector3(0,1.644,-.109),Vector2(extent*.78,.021),"Head")
 ],color,16)

func _outfit()->void:
 var top:String=str(look.get("top","tee"))
 var hoodie:bool=top=="hoodie"
 var tank:bool=top=="tank"
 var shirt_pad:float=.027 if not hoodie else .046
 var top_rings:Array=spine_rings(shirt_pad)
 # End just below the neckline instead of ballooning over the head.
 # Keep the fabric hem above the denim shell, with a real 20 mm gap:
 # an almost-coplanar waistband caused z-fighting that looked like a torn shirt.
 top_rings[0]=section(Vector3(0,.914,0),Vector2(hips+.065,.196),"Hips")
 top_rings[1]=section(Vector3(0,.976,0),Vector2(hips+.059,.189),"Hips")
 top_rings[-1]=section(Vector3(0,1.485,0),Vector2(.092,.083),"Neck")
 loft("top","Tailored "+top.capitalize(),"y",top_rings,cloth,18)
 if not tank:
  for side in ["L","R"]:
   loft("top","Fitted sleeve "+side,"x",arm_rings(side,.014 if not hoodie else .034,.98 if hoodie else .40),cloth,12)
   # Hem and cuff give sleeves an actual tailored termination.
   var s:float=1.0 if side=="L" else -1.0
   var cuff_x:float=.68 if hoodie else .375
   loft("top_detail","Sleeve seam "+side,"x",[
    section(Vector3(s*(cuff_x-.012),1.399,0),Vector2(.089,.090) if hoodie else Vector2(.097,.10),"LowerArm_"+side if hoodie else "UpperArm_"+side),
    section(Vector3(s*cuff_x,1.399,0),Vector2(.089,.090) if hoodie else Vector2(.097,.10),"LowerArm_"+side if hoodie else "UpperArm_"+side)
   ],tone(cloth,-.10),12)
 if hoodie:
  loft("top_detail","Hood fold","y",[
   section(Vector3(0,1.414,.096),Vector2(.120,.122),"Neck"),
   section(Vector3(0,1.514,.079),Vector2(.161,.126),"Neck"),
   section(Vector3(0,1.568,.079),Vector2(.131,.097),"Neck")
  ],tone(cloth,-.12),14)
  box_on("top_detail","Hoodie pouch","Hips",Vector3(0,.115,-.162),Vector3(.245,.16,.025),tone(cloth,.058))
  for side in [-1.0,1.0]:
   box_on("top_detail","Drawstring","Chest",Vector3(side*.061,.194,-.162),Vector3(.009,.168,.010),Color("e3d7bd"))
 elif top=="button_shirt":
  box_on("top_detail","Button placket","Chest",Vector3(0,.06,-.174),Vector3(.018,.30,.012),tone(cloth,-.22))
  for i in range(3):
   box_on("top_detail","Button","Chest",Vector3(0,.14-float(i)*.065,-.187),Vector3(.010,.010,.008),Color("e1d5b9"))
 elif top=="tee":
  loft("top_detail","Crew collar","y",[
   section(Vector3(0,1.483,0),Vector2(.101,.086),"Neck"),
   section(Vector3(0,1.510,0),Vector2(.102,.085),"Neck")
  ],tone(cloth,-.22),16)
 if str(look.get("outerwear","none"))!="none":_jacket()
 _pants()
 _shoes()
 _beard()

func _jacket()->void:
 var style:String=str(look.get("outerwear","none"))
 var color:Color=tint("outerwear_color","414e60")
 var pad:float=.071 if style=="bomber" else .047
 var shell:Array=spine_rings(pad)
 shell[0]=section(Vector3(0,.92,0),Vector2(hips+pad,.17+pad),"Hips")
 shell[-1]=section(Vector3(0,1.48,0),Vector2(.100,.090),"Neck")
 loft("outerwear","Structured "+style.replace("_"," "),"y",shell,color,18)
 for side in ["L","R"]:
  loft("outerwear","Jacket sleeve "+side,"x",arm_rings(side,.046),color,12)
  var s:float=1 if side=="L" else -1
  loft("outerwear_detail","Jacket cuff "+side,"x",[
   section(Vector3(s*.668,1.4,0),Vector2(.10,.10),"LowerArm_"+side),
   section(Vector3(s*.707,1.4,0),Vector2(.094,.093),"Hand_"+side)
  ],tone(color,-.21),12)
 box_on("outerwear_detail","Front zip","Chest",Vector3(0,.045,-.219),Vector3(.015,.405,.013),Color("bcc0b9"),.45)
 for side in [-1.0,1.0]:
  box_on("outerwear_detail","Jacket chest pocket","Chest",Vector3(side*.138,.032,-.205),Vector3(.105,.105,.023),tone(color,-.07))
  box_on("outerwear_detail","Jacket collar","UpperChest",Vector3(side*.105,.090,-.141),Vector3(.14,.10,.065),tone(color,.08))
 if style=="denim_jacket":
  for side in [-1.0,1.0]:
   box_on("outerwear_detail","Denim stitch","Chest",Vector3(side*.21,.02,-.10),Vector3(.008,.39,.010),tone(color,.25))
 if style=="long_coat":
  loft("outerwear","Long coat lower","y",[
   section(Vector3(0,.50,0),Vector2(hips+.11,.17),"Hips"),
   section(Vector3(0,.74,0),Vector2(hips+.080,.18),"Hips"),
   section(Vector3(0,.94,0),Vector2(hips+.065,.18),"Hips")
  ],color,18)

func _pants()->void:
 var kind:String=str(look.get("bottom","jeans"))
 var joggers:bool=kind=="joggers"
 var cargo:bool=kind=="cargos"
 var skirt:bool=kind=="skirt"
 # Keep the waistband beneath the shirt instead of an exposed protruding
 # light-blue apron across the front of jeans and cargos.
 loft("bottom","Fitted waistband","y",[
  section(Vector3(0,.895,0),Vector2(hips+.017,.139),"Hips"),
  section(Vector3(0,.936,0),Vector2(hips+.018,.144),"Hips"),
  section(Vector3(0,.978,0),Vector2(hips+.017,.141),"Hips")
 ],pants,16)
 if skirt:
  loft("bottom","Skirt silhouette","y",[
   section(Vector3(0,.528,0),Vector2(hips+.098,.158),"Hips"),
   section(Vector3(0,.585,0),Vector2(hips+.079,.151),"Hips"),
   section(Vector3(0,.793,0),Vector2(hips+.038,.142),"Hips"),
   section(Vector3(0,.963,0),Vector2(hips+.028,.155),"Hips")
  ],pants,18)
 else:
  for side in ["L","R"]:
   var leg:Array=leg_rings(side,.022 if cargo else (.013 if joggers else .015),kind=="shorts")
   loft("bottom","Tailored leg "+side,"y",leg,pants,14)
   var s:float=1 if side=="L" else -1
   if kind not in ["shorts"]:
    loft("bottom_detail","Trouser cuff "+side,"y",[
     section(Vector3(s*.110,.102,-.012),Vector2(.085,.083),"LowerLeg_"+side),
     section(Vector3(s*.110,.145,-.013),Vector2(.088,.087),"LowerLeg_"+side)
    ],tone(pants,-.17),12)
   if cargo:
    box_on("bottom_detail","Cargo side pocket "+side,"UpperLeg_"+side,Vector3(s*.130,-.217,-.104),Vector3(.125,.145,.034),tone(pants,.07))
    box_on("bottom_detail","Cargo pocket flap "+side,"UpperLeg_"+side,Vector3(s*.130,-.148,-.13),Vector3(.130,.023,.017),tone(pants,-.18))
   if kind=="jeans":
    box_on("bottom_detail","Denim thigh stitch "+side,"UpperLeg_"+side,Vector3(s*.097,-.16,-.125),Vector3(.008,.24,.010),tone(pants,.16))

func _shoes()->void:
 var kind:String=str(look.get("shoes","sneakers"))
 for side in ["L","R"]:
  var s:float=1 if side=="L" else -1
  var base_x:float=s*.111
  loft("shoes","Sculpted shoe upper "+side,"z",[
   section(Vector3(base_x,.095,.132),Vector2(.098,.083),"Foot_"+side),
   section(Vector3(base_x,.099,.039),Vector2(.115,.086),"Foot_"+side),
   section(Vector3(base_x,.081,-.106),Vector2(.122,.072),"Foot_"+side),
   section(Vector3(base_x,.068,-.225),Vector2(.135,.052),"Toes_"+side,"Foot_"+side,.25),
   section(Vector3(base_x,.066,-.271),Vector2(.090,.040),"Toes_"+side,"Foot_"+side,.25),
   section(Vector3(base_x,.064,-.285),Vector2(.006,.006),"Toes_"+side)
  ],shoes,14,.60)
  loft("shoes","Rubber outsole "+side,"z",[
   section(Vector3(base_x,.036,.153),Vector2(.113,.025),"Foot_"+side),
   section(Vector3(base_x,.033,-.070),Vector2(.138,.029),"Foot_"+side),
   section(Vector3(base_x,.032,-.239),Vector2(.146,.028),"Toes_"+side,"Foot_"+side,.3),
   section(Vector3(base_x,.034,-.278),Vector2(.089,.023),"Toes_"+side)
  ],Color("e8e5dc"),14)
  for i in range(3):
   box_on("shoes_detail","Lace bar","Foot_"+side,Vector3(0,.104,-.055-float(i)*.043),Vector3(.095,.009,.010),tone(shoes,-.24))
  if kind=="high_tops" or kind=="boots":
   loft("shoes","High shoe ankle "+side,"y",[
    section(Vector3(base_x,.098,0),Vector2(.085,.083),"Foot_"+side),
    section(Vector3(base_x,.201,0),Vector2(.098 if kind=="boots" else .081,.093),"Foot_"+side),
    section(Vector3(base_x,.272,0),Vector2(.101 if kind=="boots" else .080,.092),"LowerLeg_"+side)
   ],tone(shoes,-.11 if kind=="boots" else 0),12)

func _details()->void:
 var hat:String=str(look.get("headwear","none"))
 if hat!="none":
  var color:Color=tint("headwear_color","324438")
  loft("headwear","Fitted "+hat,"y",[
   section(Vector3(0,1.854,.009),Vector2(.147,.132),"Head"),
   section(Vector3(0,1.924,.008),Vector2(.150,.137),"Head"),
   section(Vector3(0,2.010,.007),Vector2(.12,.111),"Head"),
   section(Vector3(0,2.029,.007),Vector2(.04,.043),"Head")
  ],color,18)
  if hat=="cap":box_on("headwear","Stiff cap visor","Head",Vector3(0,.296,-.166),Vector3(.238,.022,.180),color)
 var eyewear:String=str(look.get("glasses","none"))
 if eyewear!="none":
  var frame:Color=Color("25282a")
  for side in [-1.0,1.0]:
   box_on("glasses","Glass lens","Head",Vector3(side*.059,.174,-.164),Vector3(.102,.066,.012),Color("222a30") if eyewear=="sunglasses" else Color("b3cccb"))
   box_on("glasses","Temple arm","Head",Vector3(side*.124,.175,-.095),Vector3(.016,.012,.137),frame)
  box_on("glasses","Eyeglass bridge","Head",Vector3(0,.180,-.167),Vector3(.043,.013,.015),frame)
 if str(look.get("gloves","none"))!="none":
  var color:Color=Color("3a3937") if str(look.gloves)=="leather" else Color("555d59")
  for side in ["L","R"]:
   var s:float=1 if side=="L" else -1
   loft("gloves","Tailored glove "+side,"x",[
    section(Vector3(s*.711,1.399,0),Vector2(.061,.055),"Hand_"+side),
    section(Vector3(s*.766,1.399,0),Vector2(.068,.062),"Hand_"+side),
    section(Vector3(s*.825,1.399,0),Vector2(.047,.05),"Hand_"+side)
   ],color,12)
 var bag:String=str(look.get("bag","none"))
 if bag!="none":
  var bc:Color=tint("bag_color","71604d")
  box_on("bag","Canvas body","UpperChest",Vector3(0,-.15,.231),Vector3(.32,.32,.125),bc)
  for side in [-1.0,1.0]:
   box_on("bag","Backpack strap","UpperChest",Vector3(side*.17,-.02,.107),Vector3(.045,.34,.04),tone(bc,-.21))
 if str(look.get("jewelry","none"))=="chain":
  box_on("jewelry","Chain pendant","Neck",Vector3(0,-.12,-.109),Vector3(.045,.045,.014),Color("e5c47c"),.67)
 elif str(look.get("jewelry","none"))=="studs":
  for side in [-1.0,1.0]:
   box_on("jewelry","Ear stud","Head",Vector3(side*.155,.125,0),Vector3(.028,.035,.027),Color("dbbc79"),.67)
