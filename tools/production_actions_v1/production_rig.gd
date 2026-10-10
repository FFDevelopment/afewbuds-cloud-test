extends Node3D
# Shared approved arm/pinch solver. Visual-only: never writes inventory.
var sk:Skeleton3D
var action:="pack"
var clock:=0.0
var pass_roll:=0.0
var lighter_press:=0.0
var max_reach_error:=0.0
var max_joint_error:=0.0
var wrist_bend:=0.0
var left:=Vector3.ZERO
var right:=Vector3.ZERO
func oriented_basis(axis:Vector3,palm:Vector3)->Basis:
 var y:Vector3=(palm-axis*axis.dot(palm)).normalized()
 if y.length()<.01:y=(Vector3.FORWARD-axis*axis.dot(Vector3.FORWARD)).normalized()
 return Basis(axis,y,axis.cross(y).normalized())

func arm(side:String,wrist:Vector3,finger_dir:Vector3,curl:float):
 var sg:=1.0 if side=="L" else -1.0
 var u:=sk.find_bone("UpperArm_"+side);var e:=sk.find_bone("LowerArm_"+side);var h:=sk.find_bone("Hand_"+side)
 var shoulder:=sk.get_bone_global_rest(u).origin
 if action=="pack":
  shoulder=(sk.get_bone_global_pose(sk.get_bone_parent(u))*sk.get_bone_rest(u)).origin
 var delta:=wrist-shoulder;var d:=clampf(delta.length(),.04,.529);var direction:=delta.normalized();var reach:=shoulder+direction*d
 max_reach_error=maxf(max_reach_error,wrist.distance_to(reach))
 var pole:=Vector3(sg*.20,-1.0,.05);var perpendicular:=(pole-direction*pole.dot(direction)).normalized()
 var along:=(.28*.28-.25*.25+d*d)/(2*d);var height:=sqrt(maxf(0,.28*.28-along*along));var elbow:=shoulder+direction*along+perpendicular*height
 var forearm:Vector3=(reach-elbow).normalized()
 var bend:=forearm.angle_to(finger_dir)
 if bend>.70:finger_dir=forearm.slerp(finger_dir,.70/bend).normalized()
 wrist_bend=maxf(wrist_bend,forearm.angle_to(finger_dir))
 var smoking:=action in ["light","smoke"] and side=="R"
 var palm:=Vector3.BACK if smoking else Vector3.UP
 var hand_basis:=oriented_basis(finger_dir*sg,palm)
 # Use one continuous neutral roll through lift, handoff and lowering.
 # Thumb goes forward as fingers hang down, avoiding a vertical-axis singularity.
 if action in ["idle","light","smoke"]:
  var thumb_direction:Vector3=(Vector3.UP+Vector3.FORWARD*.9*smoothstep(.55,.95,-finger_dir.y)).normalized()
  var neutral_palm:Vector3=(-thumb_direction).cross(finger_dir*sg).normalized()
  if neutral_palm.length()>.01:
   hand_basis=oriented_basis(finger_dir*sg,neutral_palm)
 var lower_basis:=oriented_basis(forearm*sg,hand_basis.y)
 var upper_basis:=Basis(Quaternion(Vector3(sg,0,0),(elbow-shoulder).normalized()))
 sk.set_bone_global_pose_override(u,Transform3D(upper_basis,shoulder),1,true)
 sk.set_bone_global_pose_override(e,Transform3D(lower_basis,elbow),1,true)
 sk.set_bone_global_pose_override(h,Transform3D(hand_basis,reach),1,true)
 max_joint_error=maxf(max_joint_error,(Transform3D(upper_basis,shoulder)*sk.get_bone_rest(e).origin).distance_to(elbow))
 max_joint_error=maxf(max_joint_error,(Transform3D(lower_basis,elbow)*sk.get_bone_rest(h).origin).distance_to(reach))
 for finger in ["Index","Middle","Ring","Pinky","Thumb"]:
  for joint in [1,2,3]:
   var b:=sk.find_bone(finger+str(joint)+"_"+side)
   var angle:float=.4 if finger=="Thumb" else .55
   if smoking:angle=([.12,.24,.18][joint-1] if finger=="Index" else ([.05,.12,.08][joint-1] if finger=="Thumb" else .55))
   var hold_weight:=1.0 if smoking and finger in ["Index","Thumb"] else curl
   var q:=Quaternion(Vector3(0,0,1),-sg*hold_weight*angle)
   # Slightly separate the holding fingers at their bases; keep all joint positions intact.
   if smoking and joint==1 and finger in ["Index","Thumb"]:
    q=Quaternion(Vector3.UP,(.12 if finger=="Index" else -.19)*hold_weight)*q
   if action=="light" and side=="L":
    var grip_q:Quaternion
    if finger=="Thumb":
     var thumb_angles:Array=[0.0,lerpf(.35,.65,lighter_press),lerpf(.4,.8,lighter_press)]
     grip_q=Quaternion(Vector3.FORWARD,float(thumb_angles[joint-1]))
     if joint==1:grip_q=Quaternion(Vector3.UP,.12*(1-lighter_press))*grip_q
    else:grip_q=Quaternion(Vector3.FORWARD,([1.0,.7,.55][joint-1])*curl)
    var hold:=1-smoothstep(2.5,3.1,fmod(maxf(0,clock-1),6.0))
    q=q.slerp(grip_q,hold)
   if action=="pack" and side=="L":
    # Side pinch: curled middle/ring/pinky, opposed thumb and index pads.
    var angles:Array=[.65,.85,.60] if finger not in ["Thumb","Index"] else ([.35,.60,.35] if finger=="Index" else [.30,.55,.35])
    q=Quaternion(Vector3.FORWARD,float(angles[joint-1]))
    if finger=="Thumb" and joint==1:q=Quaternion(Vector3.UP,-.55)*q
   sk.set_bone_pose_rotation(b,q)
 if action=="pack" and side=="L":close_bag_pinch()

 # Keep the thumb itself lifted during an offer, not only the thumb edge of the palm.
 if smoking and pass_roll>0:
  sk.force_update_all_bone_transforms()
  var tip_id:=sk.find_bone("Thumb3_R")
  var tip:Transform3D=sk.get_bone_global_pose(tip_id)
  var current_direction:Vector3=-tip.basis.x.normalized()
  var lifted:=Vector3(current_direction.x,.55,current_direction.z).normalized()
  var correction:=Quaternion(current_direction,lifted)
  var limit:=minf(1.0,.85/maxf(.001,current_direction.angle_to(lifted)))
  correction=Quaternion.IDENTITY.slerp(correction,limit*smoothstep(0,.1,pass_roll))
  var parent_basis:Basis=sk.get_bone_global_pose(sk.get_bone_parent(tip_id)).basis
  var local_basis:Basis=sk.get_bone_rest(tip_id).basis.inverse()*parent_basis.inverse()*Basis(correction)*tip.basis
  sk.set_bone_pose_rotation(tip_id,local_basis.get_rotation_quaternion().normalized())


func grip(side:String)->Vector3:
 var b:=sk.get_bone_global_pose(sk.find_bone("Hand_"+side));return b*Vector3(.068 if side=="L" else -.068,0,0)

func pack_hand(side:String,target_point:Vector3):
 var wrist:=target_point+Vector3(0,.055,.025)
 var direction:=Vector3(-.95,-.12,-.25) if side=="L" else Vector3(.7,0,-.7)
 for iteration in 8:
  arm(side,wrist,direction.normalized(),.75)
  sk.force_update_all_bone_transforms()
  wrist+=(target_point-(bag_pinch() if side=="L" else grip(side))).limit_length(.03)
 arm(side,wrist,direction.normalized(),.75)
 if side=="L":left=wrist
 else:right=wrist
 sk.force_update_all_bone_transforms()


func bag_pinch()->Vector3:
 var index:=sk.get_bone_global_pose(sk.find_bone("Index3_L"))
 var thumb:=sk.get_bone_global_pose(sk.find_bone("Thumb3_L"))
 return (index*Vector3(.010,0,0)+thumb*Vector3(.010,0,0))*.5


func close_bag_pinch():
 sk.force_update_all_bone_transforms()
 var index:=sk.get_bone_global_pose(sk.find_bone("Index3_L"))
 var thumb:=sk.get_bone_global_pose(sk.find_bone("Thumb3_L"))
 var center:Vector3=(index*Vector3(.010,0,0)).lerp(thumb*Vector3(.010,0,0),.8)
 for finger in ["Index","Thumb"]:
  var target:Vector3=center+Vector3(0,0,.003 if finger=="Thumb" else -.003)
  var tip_id:=sk.find_bone(finger+"3_L")
  for iteration in 16:
   for joint in [3,2,1]:
    var bone:=sk.find_bone(finger+str(joint)+"_L")
    var pose:=sk.get_bone_global_pose(bone)
    var tip:Vector3=sk.get_bone_global_pose(tip_id)*Vector3(.010,0,0)
    var from:Vector3=(tip-pose.origin).normalized()
    var to:Vector3=(target-pose.origin).normalized()
    var correction:=Quaternion(from,to)
    if correction.get_angle()>.25:correction=Quaternion(correction.get_axis(),.25)
    var parent:=sk.get_bone_global_pose(sk.get_bone_parent(bone))
    var local:Basis=sk.get_bone_rest(bone).basis.inverse()*parent.basis.inverse()*Basis(correction)*pose.basis
    sk.set_bone_pose_rotation(bone,local.get_rotation_quaternion().normalized())
    sk.force_update_all_bone_transforms()

# Lower the pelvis while keeping both feet planted, with knees bending forward.
func crouch(amount:float):
 var hips:=sk.find_bone("Hips")
 sk.set_bone_pose_position(hips,sk.get_bone_rest(hips).origin+Vector3(0,-amount,amount*.18))
 sk.force_update_all_bone_transforms()
 for side in ["L","R"]:
  var u:=sk.find_bone("UpperLeg_"+side);var k:=sk.find_bone("LowerLeg_"+side);var f:=sk.find_bone("Foot_"+side)
  var hip:Vector3=(sk.get_bone_global_pose(sk.get_bone_parent(u))*sk.get_bone_rest(u)).origin
  var foot:=sk.get_bone_global_rest(f)
  var upper:=sk.get_bone_rest(k).origin;var lower:=sk.get_bone_rest(f).origin
  var a:=upper.length();var b:=lower.length();var delta:=foot.origin-hip;var d:=clampf(delta.length(),.02,a+b-.001)
  var direction:=delta.normalized();var forward:=(Vector3.FORWARD-direction*direction.dot(Vector3.FORWARD)).normalized()
  var along:=(a*a-b*b+d*d)/(2*d);var knee:=hip+direction*along+forward*sqrt(maxf(0,a*a-along*along))
  sk.set_bone_global_pose_override(u,Transform3D(Basis(Quaternion(upper.normalized(),(knee-hip).normalized())),hip),1,true)
  sk.set_bone_global_pose_override(k,Transform3D(Basis(Quaternion(lower.normalized(),(foot.origin-knee).normalized())),knee),1,true)
  sk.set_bone_global_pose_override(f,foot,1,true)
 sk.force_update_all_bone_transforms()
