extends Node3D
## Native AFewBuds 56-bone master rig v1, from the owner's AFB_MasterRig_v1.
## No GLB importer required on WebGL/iOS; desktop still supports Mike.glb.
## Rest translations and bone hierarchy are identical to the master contract.
const BONES: String = """
Root|-1|0,0,0
Hips|0|0,0.94,0
Spine|1|0,0.12,0
Chest|2|0,0.18,0
UpperChest|3|0,0.14,0
Neck|4|0,0.09,0
Head|5|0,0.1,0
Jaw|6|0,-0.02,-0.07
Eye_L|6|0.032,0.065,-0.08
Eye_R|6|-0.032,0.065,-0.08
Shoulder_L|4|0.065,0.025,0
UpperArm_L|10|0.12,0,0
LowerArm_L|11|0.28,0,0
Hand_L|12|0.25,0,0
Thumb1_L|13|0.025,-0.008,-0.035
Thumb2_L|14|0.026,0,0
Thumb3_L|15|0.022,0,0
Index1_L|13|0.07,-0.008,-0.025
Index2_L|17|0.027,0,0
Index3_L|18|0.022,0,0
Middle1_L|13|0.07,-0.008,-0.008
Middle2_L|20|0.03,0,0
Middle3_L|21|0.023,0,0
Ring1_L|13|0.07,-0.008,0.01
Ring2_L|23|0.027,0,0
Ring3_L|24|0.022,0,0
Pinky1_L|13|0.07,-0.008,0.027
Pinky2_L|26|0.021,0,0
Pinky3_L|27|0.018,0,0
UpperLeg_L|1|0.095,-0.035,0
LowerLeg_L|29|0,-0.43,-0.015
Foot_L|30|0,-0.405,0.015
Toes_L|31|0,-0.035,-0.14
Shoulder_R|4|-0.065,0.025,0
UpperArm_R|33|-0.12,0,0
LowerArm_R|34|-0.28,0,0
Hand_R|35|-0.25,0,0
Thumb1_R|36|-0.025,-0.008,-0.035
Thumb2_R|37|-0.026,0,0
Thumb3_R|38|-0.022,0,0
Index1_R|36|-0.07,-0.008,-0.025
Index2_R|40|-0.027,0,0
Index3_R|41|-0.022,0,0
Middle1_R|36|-0.07,-0.008,-0.008
Middle2_R|43|-0.03,0,0
Middle3_R|44|-0.023,0,0
Ring1_R|36|-0.07,-0.008,0.01
Ring2_R|46|-0.027,0,0
Ring3_R|47|-0.022,0,0
Pinky1_R|36|-0.07,-0.008,0.027
Pinky2_R|49|-0.021,0,0
Pinky3_R|50|-0.018,0,0
UpperLeg_R|1|-0.095,-0.035,0
LowerLeg_R|52|0,-0.43,-0.015
Foot_R|53|0,-0.405,0.015
Toes_R|54|0,-0.035,-0.14
"""
var skeleton:Skeleton3D
func _ready()->void:
 skeleton=Skeleton3D.new()
 skeleton.name="AFB_MasterSkeleton"
 add_child(skeleton)
 var names:Dictionary={}
 var count:int=0
 for raw in BONES.strip_edges().split("\n"):
  var columns:PackedStringArray=raw.strip_edges().split("|")
  if columns.size()!=3:
   push_error("AFB native rig: invalid bone contract at "+str(count))
   return
  var parts:PackedStringArray=columns[2].split(",")
  if parts.size()!=3:return
  var idx:int=skeleton.add_bone(str(columns[0]))
  if idx!=count:return
  var parent_id:int=int(columns[1])
  if parent_id>=0:skeleton.set_bone_parent(idx,parent_id)
  var rest:=Transform3D(Basis.IDENTITY,Vector3(float(parts[0]),float(parts[1]),float(parts[2])))
  skeleton.set_bone_rest(idx,rest)
  count+=1
 if count!=56 or skeleton.find_bone("Head")<0 or skeleton.find_bone("Foot_R")<0:
  push_error("AFB native rig: master skeleton contract mismatch")
  return
 skeleton.force_update_all_bone_transforms()
 set_meta("afb_native_rig",true)
