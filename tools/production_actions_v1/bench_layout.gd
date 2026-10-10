extends RefCounted
# Additive layout revision over the extracted repo bench geometry.
static func box(root:Node3D,id:String,at:Vector3,size:Vector3,color:String)->MeshInstance3D:
 var n:=MeshInstance3D.new();n.name=id;n.mesh=BoxMesh.new();n.mesh.size=size;n.position=at
 var m:=StandardMaterial3D.new();m.albedo_color=Color(color);m.roughness=.65;n.material_override=m;root.add_child(n);return n
static func text(root:Node3D,id:String,words:String,at:Vector3,rotation_y:float,pixel:float)->Label3D:
 var n:=Label3D.new();n.name=id;n.text=words;n.font_size=32;n.pixel_size=pixel;n.position=at;n.rotation.y=rotation_y;n.modulate=Color("d4efb6");root.add_child(n);return n
static func original(root:Node3D):
 var pivot:=Vector3(3.86,1.16,.40)
 for n in root.get_children():
  var id:=str(n.name)
  if id.begins_with("Scale") or id=="PackingScaleText":
   n.position=pivot+(n.position-pivot)*.68;n.scale*=.68
  if id in ["LabelRoll","ToolCup","ToolPenA","ToolPenB","ScissorBladeA","ScissorBladeB","ScissorHandleA","ScissorHandleB"] or id.begins_with("BenchIIITool_"):
   n.free()
 for id in ["TrimTray","TrayRimBack","TrayRimFront"]:root.get_node(id).position+=Vector3(.22,0,-.06)
 # Compact bag box in the back-right corner, with a clear label.
 for id in ["BaggieBox","BaggieBoxGreenTop"]:
  var n:Node3D=root.get_node(id);n.position=Vector3(4.30,1.16,1.77)+(n.position-Vector3(4.22,1.16,1.77))*.60;n.scale*=.60
 root.get_node("BagStack").position=Vector3(3.82,1.20,2.20)
 text(root,"BagSupplyLabel","BAGS",Vector3(4.145,1.285,1.77),-PI/2,.0017)
 # Small scissors laid flat: steel blades and two ring handles.
 for i in 2:
  var blade:=box(root,"WorkScissorBlade"+str(i),Vector3(3.66,1.175,1.81+float(i)*.055),Vector3(.24,.012,.018),"c0c8cb");blade.rotation.y=-.10 if i==0 else .10
  var ring:=MeshInstance3D.new();ring.name="WorkScissorRing"+str(i);var torus:=TorusMesh.new();torus.inner_radius=.025;torus.outer_radius=.038;torus.rings=16;torus.ring_segments=8;ring.mesh=torus;ring.position=Vector3(3.51,1.178,1.81+float(i)*.075);root.add_child(ring)
  var mat:=StandardMaterial3D.new();mat.albedo_color=Color("253a32");ring.material_override=mat
static func purchased(root:Node3D):
 var scale:MeshInstance3D=root.get_child(5);scale.name="ScaleBody"
 scale.mesh.size=Vector3(.34,.065,.29);scale.position=Vector3(-.35,1.2625,.05)
 box(root,"ScalePlatform",Vector3(-.35,1.303,.05),Vector3(.29,.016,.25),"bfc7c6")
 box(root,"ScaleDisplay",Vector3(-.35,1.261,.198),Vector3(.21,.045,.008),"142c20")
 text(root,"PackingScaleText","0.00 g",Vector3(-.35,1.261,.204),0,.00085)
 var tray:MeshInstance3D=root.get_child(6);tray.name="TrimTray";tray.mesh.size=Vector3(.35,.025,.25);tray.position.y=1.2425
 for x in [-1,1]:box(root,"TraySide"+str(x),Vector3(.35+x*.175,1.267,.05),Vector3(.018,.05,.25),"35423e")
 for z in [-1,1]:box(root,"TrayEnd"+str(z),Vector3(.35,1.267,.05+z*.125),Vector3(.35,.05,.018),"35423e")
 box(root,"BagStack",Vector3(0,1.245,-.18),Vector3(.17,.03,.16),"dce4db")
