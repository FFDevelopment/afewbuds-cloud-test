extends Node3D
# Continuous three-flight stair tower; paired with thin ramp colliders for smooth walking.
var metal: Material
var collision_bodies: Array[StaticBody3D]=[]
var flights: Array[Dictionary]=[]
var landings: Array[Dictionary]=[]
func block(at: Vector3,size: Vector3,solid: bool=false) -> MeshInstance3D:
 var n:=MeshInstance3D.new();var mesh:=BoxMesh.new();mesh.size=size
 n.mesh=mesh;n.material_override=metal;n.position=at;n.layers=3;add_child(n)
 if solid:
  var b:=StaticBody3D.new();b.collision_layer=1;b.collision_mask=4
  var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=size;shape.shape=box
  b.add_child(shape);n.add_child(b);collision_bodies.append(b)
 return n
func beam(a: Vector3,b: Vector3,width: float=.055,solid: bool=false) -> void:
 var n:=block((a+b)*.5,Vector3(width,width,a.distance_to(b)),solid)
 n.look_at(b,Vector3.UP if absf((b-a).normalized().dot(Vector3.UP))<.99 else Vector3.FORWARD)
func guard(a: Vector3,b: Vector3) -> void:
 beam(a+Vector3.UP*1.15,b+Vector3.UP*1.15,.055)
 # One continuous vertical guard collider prevents the capsule catching under
 # sloped handrails or on their tiny end caps while sliding alongside a flight.
 var tangent:=Vector3(b.x-a.x,0,b.z-a.z).normalized()
 var across:=Vector3(-tangent.z,0,tangent.x)*.035
 var points:=PackedVector3Array()
 for end in [a,b]:
  for offset in [-across,across]:
   points.append(end+offset-Vector3.UP*.16)
   points.append(end+offset+Vector3.UP*1.18)
 var body:=StaticBody3D.new();body.name="ContinuousGuard";body.collision_layer=1;body.collision_mask=4
 var shape:=CollisionShape3D.new();var convex:=ConvexPolygonShape3D.new();convex.points=points;shape.shape=convex
 body.add_child(shape);add_child(body);collision_bodies.append(body)
 beam(a+Vector3.UP*.55,b+Vector3.UP*.55,.035)
 var count:=maxi(1,ceili(a.distance_to(b)/.65))
 for i in range(count+1):
  var at:=a.lerp(b,float(i)/count)
  beam(at,at+Vector3.UP*1.15,.045)
func landing(y: float,z0: float,z1: float,roof: bool=false) -> void:
 var start:=5.05 if roof else 5.22
 block(Vector3((start+8.55)*.5,y-.07,(z0+z1)*.5),Vector3(8.55-start,.14,z1-z0),true)
 landings.append({"y":y,"z0":z0,"z1":z1,"x0":start,"x1":8.55})
 guard(Vector3(8.55,y,z0),Vector3(8.55,y,z1))
 # Rails along the outer end; the inner edge is open to the stair flights.
 var end_z:=z0 if z0< -6 else z1
 if y>0:guard(Vector3(start,y,end_z),Vector3(8.55,y,end_z))
 for x in [5.35,8.4]:
  beam(Vector3(x,y-.14,(z0+z1)*.5),Vector3(5.12,y-.85,(z0+z1)*.5),.085)
func flight(x: float,from_y: float,to_y: float,from_z: float,to_z: float) -> void:
 var width:=1.45
 var count:=ceili((to_y-from_y)/.19)
 var run:=absf(to_z-from_z)/count
 for i in range(count):
  var t:=minf(float(i+1)*run/(absf(to_z-from_z)-.4),1.0)
  var z:=lerpf(from_z,to_z,(i+.5)/count)
  block(Vector3(x,lerpf(from_y,to_y,t)-.045,z),Vector3(width,.09,run+.02))
 var a:=Vector3(x,from_y,from_z);var b:=Vector3(x,to_y,to_z)
 for side in [-1.0,1.0]:
  var offset:=Vector3(side*width*.5,0,0)
  beam(a+offset-Vector3.UP*.12,b+offset-Vector3.UP*.12,.11)
  guard(a+offset,b+offset)
 # A level crest begins before the landing lip and overlaps the deck.
 # The capsule reaches deck height before its leading edge touches the deck face.
 var points:=PackedVector3Array()
 var direction:float=signf(to_z-from_z)
 var crest:=b-Vector3(0,0,direction*.4)
 var cap:=b+Vector3(0,0,direction*.1)
 for side in [-1.0,1.0]:
  for point in [a,crest,cap]:
   points.append(point+Vector3(side*width*.5,0,0))
   points.append(point+Vector3(side*width*.5,-.2,0))
 var body:=StaticBody3D.new();body.collision_layer=1;body.collision_mask=4
 var shape:=CollisionShape3D.new();var convex:=ConvexPolygonShape3D.new();convex.points=points;shape.shape=convex
 body.add_child(shape);add_child(body);collision_bodies.append(body)
 flights.append({"from":a,"to":b,"steps":count,"width":width})
func build(mat: Material,roof_top: float) -> void:
 metal=mat
 landing(0,1.6,2.8)
 landing(4.4,-8,-6.8)
 landing(7.9,1.6,2.8)
 landing(roof_top,-8,-6.8,true)
 flight(6.02,0,4.4,1.6,-6.8)
 flight(7.75,4.4,7.9,-6.8,1.6)
 flight(6.02,7.9,roof_top,1.6,-6.8)
 # Close the unused upper landing edge, preserving the stair mouth and roof entry.
 guard(Vector3(6.8,roof_top,-6.8),Vector3(8.55,roof_top,-6.8))
 # Roof perimeter; the east opening aligns with the connected landing.
 guard(Vector3(-5.18,roof_top,-10.35),Vector3(5.18,roof_top,-10.35))
 guard(Vector3(-5.18,roof_top,6.15),Vector3(5.18,roof_top,6.15))
 guard(Vector3(-5.18,roof_top,-10.35),Vector3(-5.18,roof_top,6.15))
 guard(Vector3(5.18,roof_top,-10.35),Vector3(5.18,roof_top,-8.05))
 guard(Vector3(5.18,roof_top,-6.75),Vector3(5.18,roof_top,6.15))
 # Grounded support columns connect all landings; no floating deck ends.
 for x in [5.1,8.5]:
  for z in [-7.9,2.7]:
   var height:=roof_top if z<0 else 7.9
   block(Vector3(x,height*.5,z),Vector3(.12,height,.12),true)
   block(Vector3(x,.04,z),Vector3(.32,.08,.32),true)
func set_collision_active(active: bool) -> void:
 for body in collision_bodies:body.collision_layer=1 if active else 0
