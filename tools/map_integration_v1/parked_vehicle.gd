extends Node3D
## Original lightweight procedural vehicles. Local +X is the front.
## Metres before the shared character-scale multiplier; no runtime animation.
var mats:Dictionary={}
func material(hex:String,metal:float=0.0)->StandardMaterial3D:
 var key=hex+str(metal)
 if mats.has(key):return mats[key]
 var m=StandardMaterial3D.new();m.albedo_color=Color(hex);m.roughness=.65;m.metallic=metal
 m.cull_mode=BaseMaterial3D.CULL_DISABLED;mats[key]=m;return m
func mesh_node(id:String,mesh:Mesh,mat:Material)->MeshInstance3D:
 var n=MeshInstance3D.new();n.name=id;n.mesh=mesh;n.material_override=mat;n.layers=3
 n.set_meta("no_collision",true);add_child(n);return n
func box(id:String,at:Vector3,size:Vector3,mat:Material)->MeshInstance3D:
 var mesh=BoxMesh.new();mesh.size=size
 var n=mesh_node(id,mesh,mat);n.position=at;return n
func panel(id:String,points:Array,mat:Material)->void:
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1)
 for i in range(1,points.size()-1):
  for v in [points[0],points[i],points[i+1]]:st.add_vertex(v)
 st.generate_normals();mesh_node(id,st.commit(),mat)
func profile(id:String,outline:PackedVector2Array,width:float,mat:Material)->void:
 var indices=Geometry2D.triangulate_polygon(outline)
 var st=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_smooth_group(-1)
 for side in [-1.0,1.0]:
  for i in range(0,indices.size(),3):
   var order=[indices[i],indices[i+1],indices[i+2]] if side>0 else [indices[i+2],indices[i+1],indices[i]]
   for index in order:
    var p=outline[index];st.add_vertex(Vector3(p.x,p.y,side*width*.5))
 for i in range(outline.size()):
  var a=outline[i];var b=outline[(i+1)%outline.size()]
  for v in [Vector3(a.x,a.y,-width*.5),Vector3(b.x,b.y,-width*.5),Vector3(b.x,b.y,width*.5),Vector3(a.x,a.y,-width*.5),Vector3(b.x,b.y,width*.5),Vector3(a.x,a.y,width*.5)]:st.add_vertex(v)
 st.generate_normals();mesh_node(id,st.commit(),mat)
func disc(id:String,at:Vector3,radius:float,depth:float,mat:Material)->void:
 var m=CylinderMesh.new();m.top_radius=radius;m.bottom_radius=radius;m.height=depth;m.radial_segments=16;m.rings=1
 var n=mesh_node(id,m,mat);n.position=at;n.rotation.x=PI/2
func build(color:String,pickup:bool=false,police:bool=false)->void:
 set_meta("parked_vehicle",true);set_meta("variant","police" if police else ("pickup" if pickup else "sedan"))
 var paint=material("20282b" if police else color,.18)
 var trim=material("252a2b");var chrome=material("9ca4a4",.6);var glass=material("37494e",.2)
 glass.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
 var white=material("d6d9cf");var tire=material("202323")
 # The lower silhouette cuts real wheel openings into the body, avoiding slab sides.
 var outline=PackedVector2Array([Vector2(-2.3,.40)])
 for axle in [-1.45,1.45]:
  for j in range(9):
   var angle=PI-float(j)*PI/8
   outline.append(Vector2(axle+cos(angle)*.45,.40+sin(angle)*.45))
 outline.append_array(PackedVector2Array([Vector2(2.3,.40),Vector2(2.3,.81),Vector2(2.07,.95),Vector2(-2.08,.95),Vector2(-2.3,.82)]))
 profile("BodyWithWheelArches",outline,1.82,paint)
 box("Chassis",Vector3(0,.39,0),Vector3(3.7,.14,1.40),trim)
 var rear=-.68 if pickup else -1.52
 var roof_rear=-.59 if pickup else -.98
 var roof_front=.48;var nose=.98;var roof_y=1.66 if pickup else 1.52
 profile("Cabin",PackedVector2Array([Vector2(rear,.94),Vector2(nose,.94),Vector2(roof_front,roof_y),Vector2(roof_rear,roof_y)]),1.62,white if police else paint)
 # Glazing is inset from pillars; front/rear panes lie on the sloped cabin surfaces.
 var glass_bottom=1.015;var glass_top=roof_y-.06
 var front_bottom=lerpf(nose,roof_front,(glass_bottom-.94)/(roof_y-.94))+.012
 var front_top=lerpf(nose,roof_front,(glass_top-.94)/(roof_y-.94))+.012
 var rear_bottom=lerpf(rear,roof_rear,(glass_bottom-.94)/(roof_y-.94))-.012
 var rear_top=lerpf(rear,roof_rear,(glass_top-.94)/(roof_y-.94))-.012
 panel("Windshield",[Vector3(front_bottom,glass_bottom,-.73),Vector3(front_bottom,glass_bottom,.73),Vector3(front_top,glass_top,.73),Vector3(front_top,glass_top,-.73)],glass)
 panel("RearGlass",[Vector3(rear_bottom,glass_bottom,-.70),Vector3(rear_top,glass_top,-.70),Vector3(rear_top,glass_top,.70),Vector3(rear_bottom,glass_bottom,.70)],glass)
 for side in [-1.0,1.0]:
  var z=side*.819
  panel("FrontSideGlass",[Vector3(-.24,1.015,z),Vector3(nose-.12,1.015,z),Vector3(roof_front-.055,roof_y-.07,z),Vector3(-.24,roof_y-.07,z)],glass)
  if not pickup:
   panel("RearSideGlass",[Vector3(rear+.12,1.015,z),Vector3(-.33,1.015,z),Vector3(-.33,roof_y-.07,z),Vector3(roof_rear+.065,roof_y-.07,z)],glass)
  else:
   panel("QuarterGlass",[Vector3(rear+.065,1.015,z),Vector3(-.33,1.015,z),Vector3(-.33,roof_y-.07,z),Vector3(roof_rear+.065,roof_y-.07,z)],glass)
  if police:box("WhiteDoor",Vector3(-.12,.80,side*.917),Vector3(1.72,.27,.018),white)
  box("DoorSeam",Vector3(-.285,.72,side*.929),Vector3(.016,.39,.012),trim)
  for x in [-.43,.55]:box("Handle",Vector3(x,.92,side*.946),Vector3(.19,.036,.032),chrome)
  box("SideMoulding",Vector3(0,.54,side*.925),Vector3(1.9,.055,.028),trim)
  box("MirrorStalk",Vector3(.76,1.03,side*.92),Vector3(.12,.055,.18),trim)
  box("Mirror",Vector3(.76,1.055,side*1.015),Vector3(.21,.13,.10),paint)
  for axle in [-1.45,1.45]:
   disc("Tire",Vector3(axle,.365,side*.92),.365,.24,tire)
   disc("Rim",Vector3(axle,.365,side*1.048),.242,.025,chrome)
   disc("Hub",Vector3(axle,.365,side*1.067),.09,.032,trim)
   for j in range(6):
    var a=j*TAU/6
    disc("RimSlot",Vector3(axle+sin(a)*.155,.365+cos(a)*.155,side*1.065),.032,.012,trim)
  box("Headlight",Vector3(2.306,.755,side*.62),Vector3(.025,.205,.40),material("d6d3b6"))
  box("Indicator",Vector3(2.307,.755,side*.85),Vector3(.027,.205,.09),material("b98636"))
  box("TailLight",Vector3(-2.307,.755,side*.67),Vector3(.027,.19,.33),material("8c302e"))
 for end in [-1.0,1.0]:
  box("Bumper",Vector3(end*2.34,.49,0),Vector3(.16,.19,1.91),trim)
  box("BumperStrip",Vector3(end*2.427,.535,0),Vector3(.022,.045,1.77),chrome)
  box("LicensePlate",Vector3(end*2.44,.49,0),Vector3(.012,.105,.28),material("c9c4af"))
 box("Grille",Vector3(2.314,.754,0),Vector3(.04,.22,.78),trim)
 for y in [.68,.735,.79,.845]:box("GrilleSlat",Vector3(2.339,y,0),Vector3(.018,.015,.73),chrome)
 if pickup:
  box("BedLiner",Vector3(-1.47,.966,0),Vector3(1.36,.028,1.48),trim)
  for side in [-1.0,1.0]:box("BedRail",Vector3(-1.47,1.06,side*.84),Vector3(1.55,.21,.13),paint)
  box("Tailgate",Vector3(-2.18,1.06,0),Vector3(.12,.21,1.65),paint)
  box("TailgateHandle",Vector3(-2.249,1.08,0),Vector3(.015,.045,.24),chrome)
 if police:
  box("LightbarBase",Vector3(-.18,roof_y+.06,0),Vector3(.28,.10,1.25),trim)
  for side in [-1.0,1.0]:box("LightbarLens",Vector3(-.18,roof_y+.14,side*.36),Vector3(.25,.12,.50),material("436c99" if side>0 else "a0443c"))
  for side in [-1.0,1.0]:
   var label=Label3D.new();label.name="PoliceDoorMarking";label.text="POLICE";label.font_size=48;label.pixel_size=.0024
   label.position=Vector3(-.1,.79,side*.935);label.rotation.y=PI if side<0 else 0.0;label.modulate=Color("17272b");label.outline_size=0;add_child(label)
 # One deliberately simple body collider avoids snagging on handles and mirrors.
 var body=StaticBody3D.new();body.name="VehicleCollision";body.collision_layer=1;body.collision_mask=4;add_child(body)
 var shape=CollisionShape3D.new();var collision=BoxShape3D.new();collision.size=Vector3(4.78,1.35,2.08)
 shape.shape=collision;shape.position.y=.72;body.add_child(shape)
