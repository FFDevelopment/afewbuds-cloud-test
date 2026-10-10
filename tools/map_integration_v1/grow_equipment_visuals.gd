extends Node3D
## Shared owned-equipment visuals. All dimensions stay within catalog footprints.
var equipment_id:String
var emitters:Array[StandardMaterial3D]=[]
var lamp:SpotLight3D
var status:MeshInstance3D
func mat(hex:String,metal:float=0.0)->StandardMaterial3D:
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.metallic=metal;m.roughness=.72;return m
func mesh(id:String,shape:Mesh,at:Vector3,m:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=id;n.mesh=shape;n.position=at;n.material_override=m
 n.set_meta("no_collision",true);n.set_meta("furniture_id",equipment_id);add_child(n);return n
func box(id:String,at:Vector3,size:Vector3,m:Material,solid:bool=false)->MeshInstance3D:
 var shape=BoxMesh.new();shape.size=size;var n=mesh(id,shape,at,m)
 if solid:
  var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4;n.add_child(body)
  var hit=CollisionShape3D.new();hit.shape=BoxShape3D.new();hit.shape.size=size;body.add_child(hit)
 return n
func cylinder(id:String,at:Vector3,radius:float,height:float,m:Material)->MeshInstance3D:
 var shape=CylinderMesh.new();shape.top_radius=radius;shape.bottom_radius=radius;shape.height=height;shape.radial_segments=16;shape.rings=1
 return mesh(id,shape,at,m)
func pipe(id:String,a:Vector3,b:Vector3,r:float,m:Material)->void:
 var n=cylinder(id,(a+b)*.5,r,a.distance_to(b),m)
 n.quaternion=Quaternion(Vector3.UP,(b-a).normalized())
func badge(text:String,at:Vector3,size:float=.002)->void:
 var t=Label3D.new();t.name="EquipmentBadge";t.text=text;t.font_size=32;t.pixel_size=size;t.position=at;t.outline_size=0;t.modulate=Color("ccd4c7");add_child(t)
func build_tent(id:String,s:Vector3,quality:int,plants:int)->void:
 equipment_id=id;set_meta("furniture_id",id);set_meta("fixture_tier",quality)
 var fabric=mat("242932");var seams=mat("12191d");var frame=mat("778487",.6);var lining=mat("9ba7a5",.4);var rubber=mat("30383a")
 box("BackFabric",Vector3(0,s.y/2,-s.z/2+.035),Vector3(s.x,s.y,.07),fabric,true)
 box("ReflectiveBack",Vector3(0,s.y/2,-s.z/2+.078),Vector3(s.x-.13,s.y-.18,.014),lining)
 for side in [-1.0,1.0]:
  box("SideFabric",Vector3(side*(s.x/2-.035),s.y/2,0),Vector3(.07,s.y,s.z),fabric,true)
  box("ReflectiveSide",Vector3(side*(s.x/2-.078),s.y/2,0),Vector3(.014,s.y-.18,s.z-.14),lining)
  for z in [-s.z/2+.10,s.z/2-.09]:pipe("FrameUpright",Vector3(side*(s.x/2-.1),.08,z),Vector3(side*(s.x/2-.1),s.y-.09,z),.025,frame)
  box("ZipperEdge",Vector3(side*(s.x/2-.12),s.y/2,s.z/2-.015),Vector3(.042,s.y-.15,.024),seams)
  # Folded fabric stays within the tent width and leaves the plant targets open.
  box("TiedDoorFlap",Vector3(side*(s.x/2-.075),s.y*.55,s.z/2-.10),Vector3(.095,s.y*.65,.13),fabric)
  for y in [s.y*.35,s.y*.72]:box("FlapStrap",Vector3(side*(s.x/2-.072),y,s.z/2-.026),Vector3(.10,.035,.018),frame)
 box("Roof",Vector3(0,s.y-.035,0),Vector3(s.x,.07,s.z),fabric,true)
 box("CatchTray",Vector3(0,.19,0),Vector3(s.x-.17,.08,s.z-.16),rubber,true)
 for z in [-s.z/2+.13,s.z/2-.13]:box("TrayLip",Vector3(0,.245,z),Vector3(s.x-.18,.07,.045),rubber)
 for x in [-s.x/2+.12,s.x/2-.12]:box("TrayLip",Vector3(x,.245,0),Vector3(.045,.07,s.z-.23),rubber)
 for z in [-s.z/2+.1,s.z/2-.09]:pipe("TopFrame",Vector3(-s.x/2+.1,s.y-.10,z),Vector3(s.x/2-.1,s.y-.10,z),.025,frame)
 # Seams and lower intake slots add scale without adding collision lips.
 for x in [-s.x*.25,s.x*.25]:box("BackSeam",Vector3(x,s.y/2,-s.z/2+.09),Vector3(.012,s.y-.20,.008),frame)
 for j in range(5):box("PassiveIntake",Vector3(-s.x*.26,.44+j*.035,-s.z/2+.095),Vector3(minf(.32,s.x*.3),.018,.015),seams)
 var port=cylinder("DuctPort",Vector3(s.x*.30,s.y-.38,-s.z/2+.10),.105,.06,seams);port.rotation.x=PI/2
 badge("AFB  /  "+str(plants)+" PLANT",Vector3(0,s.y-.09,s.z/2+.004),.0017)
 var light_y=s.y-.38
 for x in [-s.x*.25,s.x*.25]:pipe("LightHanger",Vector3(x,s.y-.10,0),Vector3(x,light_y,0),.009,seams)
 var glow=mat("e4d7a4" if quality<2 else "dceee4");glow.emission_enabled=true;emitters.append(glow)
 if quality<2:
  box("BasicLightReflector",Vector3(0,light_y,0),Vector3(s.x*.65,.09,.23),mat("8c9390",.4))
  for z in [-.063,.063]:pipe("BasicTube",Vector3(-s.x*.30,light_y-.065,z),Vector3(s.x*.30,light_y-.065,z),.024,glow)
 else:
  box("LEDDriver",Vector3(0,light_y+.055,0),Vector3(minf(.38,s.x*.5),.09,.20),seams)
  for x in [-s.x*.30,s.x*.30]:box("LEDFrame",Vector3(x,light_y,0),Vector3(.035,.045,s.z*.6),frame)
  for j in range(4):
   var z=(j-1.5)*s.z*.16
   box("LEDBarHousing",Vector3(0,light_y,z),Vector3(s.x*.73,.055,.075),frame)
   box("LEDDiffuser",Vector3(0,light_y-.031,z),Vector3(s.x*.69,.014,.052),glow)
   for k in range(plants*4):box("LEDDiode",Vector3((float(k)+.5)/(plants*4)*s.x*.67-s.x*.335,light_y-.041,z),Vector3(.025,.008,.032),glow)
 pipe("PowerCable",Vector3(s.x*.28,light_y,0),Vector3(s.x*.38,s.y-.14,-s.z*.32),.008,seams)
 lamp=SpotLight3D.new();lamp.name="GrowBeam";lamp.position=Vector3(0,light_y-.12,0);lamp.rotation.x=-PI/2
 lamp.light_color=Color("f2deb0" if quality<2 else "dcefe4");lamp.light_energy=.65 if quality<2 else .95
 lamp.spot_range=s.y;lamp.spot_angle=70;lamp.spot_attenuation=.65;lamp.shadow_enabled=false;add_child(lamp)
 set_power(false)
func build_utility(id:String,sku:String,s:Vector3)->void:
 equipment_id=id;set_meta("furniture_id",id)
 var steel=mat("82918e",.45);var dark=mat("263539");var pale=mat("bac5b8");var hose=mat("222d2c")
 for x in [-s.x*.32,s.x*.32]:
  box("MountingRail",Vector3(x,s.y*.52,-s.z*.5-.010),Vector3(.045,s.y*.75,.030),steel)
  for y in [s.y*.20,s.y*.83]:
   var bolt=cylinder("MountBolt",Vector3(x,y,-s.z*.5+.048),.013,.01,dark);bolt.rotation.x=PI/2
 box("UtilityBase",Vector3(0,.055,0),Vector3(s.x*.93,.11,s.z*.92),dark,true)
 if sku=="water_kit":
  cylinder("Reservoir",Vector3(-.055,.33,-.025),.185,.47,pale)
  cylinder("ReservoirLid",Vector3(-.055,.58,-.025),.196,.055,dark)
  cylinder("FillCap",Vector3(-.055,.628,-.025),.054,.038,steel)
  box("WaterGauge",Vector3(-.055,.35,.165),Vector3(.048,.32,.016),mat("5f9da4"))
  for y in [.24,.32,.40,.48]:box("GaugeMark",Vector3(-.018,y,.175),Vector3(.035,.009,.008),dark)
  box("PumpMotor",Vector3(.18,.20,.07),Vector3(.13,.18,.22),steel)
  pipe("FeedHose",Vector3(.08,.18,.09),Vector3(.18,.18,.09),.018,hose)
  pipe("OutletRiser",Vector3(.18,.25,.09),Vector3(.18,.48,.09),.016,hose)
  box("Manifold",Vector3(.15,.49,.10),Vector3(.20,.06,.07),dark)
  for j in range(3):
   var x=.09+j*.06
   pipe("OutletConnector",Vector3(x,.49,.12),Vector3(x,.49,.19),.012,steel)
  box("Timer",Vector3(.11,.68,0),Vector3(.23,.12,.09),dark)
  box("TimerDisplay",Vector3(.11,.695,.048),Vector3(.14,.045,.01),mat("74a293"))
  badge("AUTO",Vector3(.11,.659,.052),.0012)
 else:
  cylinder("CarbonFilter",Vector3(0,.37,0),.225,.52,dark)
  for y in [.14,.60]:cylinder("FilterCollar",Vector3(0,y,0),.24,.045,steel)
  for j in range(10):cylinder("FilterRib",Vector3(0,.18+j*.04,0),.229,.009,steel)
  cylinder("InlineFan",Vector3(0,.76,0),.18,.24,steel)
  cylinder("OutletRim",Vector3(0,.94,0),.19,.07,dark)
  cylinder("OutletGrille",Vector3(0,.981,0),.158,.015,hose)
  for offset in [-.10,-.05,0,.05,.10]:box("GrilleBar",Vector3(offset,.993,0),Vector3(.008,.009,.23),steel)
  for side in [-1,1]:box("SupportBracket",Vector3(side*.25,.39,0),Vector3(.027,.68,.10),steel)
  box("FanController",Vector3(0,.76,.21),Vector3(.22,.15,.08),dark)
  var knob=cylinder("SpeedDial",Vector3(.04,.755,.257),.027,.015,pale);knob.rotation.x=PI/2
  status=box("AirStatus",Vector3(-.06,.77,.255),Vector3(.018,.018,.012),mat("69716c"))
  badge("AIR",Vector3(-.03,.71,.258),.0012)
 # Enclosing collider follows the catalog footprint; small hoses never snag feet.
 var body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4;add_child(body)
 var hit=CollisionShape3D.new();hit.shape=BoxShape3D.new();hit.shape.size=s;hit.position.y=s.y/2;body.add_child(hit)
func set_power(on:bool)->void:
 if lamp!=null:lamp.visible=on
 for m in emitters:m.emission=m.albedo_color if on else Color.BLACK;m.emission_energy_multiplier=.6 if on else 0.0
 if status!=null:status.material_override=mat("74bb91" if on else "69716c")
