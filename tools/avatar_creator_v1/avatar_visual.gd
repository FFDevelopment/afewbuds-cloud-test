extends Node3D
## AFewBuds player art v2: smooth, tapered anatomical mesh and tailored
## skinned clothing. Shares original native 56-bone rig across mobile/desktop;
## never creates sellable NPCs or touches career/economy data.
const Catalog=preload("res://scripts/avatar_catalog.gd")
const NativeRig=preload("res://scripts/avatar_native_rig.gd")
const Tailor=preload("res://scripts/avatar_tailored_mesh.gd")
var skeleton:Skeleton3D
var modules:Dictionary={}
var current:Dictionary={}
var force_native_rig:bool=true
var native_mode:bool=true
var preview_motion:String="idle"
var motion_clock:float=0.0

func _ready()->void:
 # A single native rig avoids browser-side GLB skeleton import differences.
 var carrier:Node3D=NativeRig.new()
 carrier.name="AFB_PlayerRig"
 add_child(carrier)
 skeleton=carrier.skeleton
 if skeleton==null or skeleton.get_bone_count()!=56:
  push_error("AFB tailored player: 56-bone native skeleton unavailable")
  return
 rebuild(Catalog.defaults())

func rebuild(source:Variant)->void:
 current=Catalog.sanitize(source)
 if skeleton==null:return
 # Remove all old appearance meshes synchronously. Never affect the rig.
 for child in get_children():
  if child is MeshInstance3D and child.has_meta("afb_tailored"):
   remove_child(child)
   child.queue_free()
 for child in skeleton.get_children():
  if child is BoneAttachment3D and str(child.name).begins_with("AvatarTailor_"):
   skeleton.remove_child(child)
   child.queue_free()
 modules.clear()
 var tailor=Tailor.new()
 tailor.build(self,skeleton,current,modules)
 motion_clock=0.0

func _process(delta:float)->void:
 if skeleton==null:return
 motion_clock+=delta
 var walk:bool=preview_motion=="walk"
 var phase:float=sin(motion_clock*7.0) if walk else sin(motion_clock*1.5)
 var left_arm:int=skeleton.find_bone("UpperArm_L")
 var right_arm:int=skeleton.find_bone("UpperArm_R")
 var left_leg:int=skeleton.find_bone("UpperLeg_L")
 var right_leg:int=skeleton.find_bone("UpperLeg_R")
 var rest_l:int=skeleton.find_bone("LowerArm_L")
 var rest_r:int=skeleton.find_bone("LowerArm_R")
 if left_arm>=0:skeleton.set_bone_pose_rotation(left_arm,Quaternion(Vector3(0,0,1),-1.27+(phase*.15 if walk else .014*phase)))
 if right_arm>=0:skeleton.set_bone_pose_rotation(right_arm,Quaternion(Vector3(0,0,1),1.27+(phase*.15 if walk else -.014*phase)))
 if rest_l>=0:skeleton.set_bone_pose_rotation(rest_l,Quaternion(Vector3.FORWARD,-.13))
 if rest_r>=0:skeleton.set_bone_pose_rotation(rest_r,Quaternion(Vector3.FORWARD,.13))
 if left_leg>=0:skeleton.set_bone_pose_rotation(left_leg,Quaternion(Vector3.RIGHT,(-phase*.29 if walk else 0.0)))
 if right_leg>=0:skeleton.set_bone_pose_rotation(right_leg,Quaternion(Vector3.RIGHT,(phase*.29 if walk else 0.0)))

func play_preview(clip:String)->void:
 preview_motion=clip if clip in ["idle","walk"] else "idle"

func part_count(slot:String)->int:
 return modules.get(slot,[]).size()
