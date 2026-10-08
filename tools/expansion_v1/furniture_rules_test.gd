extends SceneTree
var failures:=0
class Career extends Node:
 var location_state:Dictionary={}
 var apartment_rent_state:Dictionary={"lease_active":true}
 var property_opportunity_state:Dictionary={"acquired":true}
 var cash:=10000
 var grower_level:=6
 var grow_tent_count:=1
 var plant_slots:Array=[{"stage":-1},{"stage":-1},{"stage":-1}]
 func _record_daily_expense(_a,_b):pass
 func _update_cash_ui():pass
 func _save_game():pass
 func _sync_grow_expansion_visuals():pass
func check(ok:bool,label:String):
 if not ok:failures+=1;push_error(label)
 else:print("PASS ",label)
func _initialize():call_deferred("run")
func run():
 var host:=Career.new();root.add_child(host)
 var m=load("res://scripts/property_furniture.gd").new();m.setup(host)
 check(m.state.items.size()==1,"Existing tent entitlement migrated")
 var before:int=host.cash
 var chair:String=m.own("armchair")
 check(not chair.is_empty() and host.cash==before-180,"Purchase charged once")
 check(not m.place(chair,"unowned",Vector3.ZERO,0),"Unowned property rejected")
 check(m.place(chair,"house",Vector3(28,0,-2),90),"Ordinary furniture placed in living room")
 check(not m.pack(chair),"Locked item cannot be packed")
 m.lock(chair,false)
 var table:String=m.own("coffee_table")
 check(not m.place(table,"house",Vector3(28,0,-2),0),"Overlapping furniture rejected")
 check(not m.place(table,"house",Vector3(25,0,-2),0),"Footprint outside room rejected")
 check(not m.place(table,"house",Vector3(28,1,-2),0),"Floating placement rejected")
 check(not m.place(table,"house",Vector3(28,0,-2),45),"Unsupported rotation rejected")
 check(m.pack(chair) and m.state.items.has(chair),"Packing preserves ownership")
 check(m.place(table,"house",Vector3(28,0,-2),0),"Packed furniture frees footprint")
 m.lock("legacy_tent_0",false)
 check(not m.place("legacy_tent_0","house",Vector3(28,0,-2),0),"Tent rejected outside grow room")
 host.plant_slots[0].stage=1
 check(not m.pack("legacy_tent_0"),"Live plants block tent packing")
 check(not m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Live plants block tent relocation")
 host.plant_slots[0].stage=-1
 check(m.place("legacy_tent_0","house",Vector3(41.8,0,-12),0),"Empty legacy tent moves to house")
 m.lock("legacy_tent_0",false);m.pack("legacy_tent_0")
 check(not m.can_plant(0),"Packed tent cannot accept seeds")
 var tent:String=m.own("grow_tent")
 check(m.place(tent,"house",Vector3(41.8,0,-12),0),"Purchased tent installs")
 var count:int=m.state.items.size();m.setup(host)
 check(m.state.items.size()==count,"Reload does not duplicate purchased tents")
 host.apartment_rent_state.lease_active=false
 check(not m.place(chair,"apartment",Vector3(0,0,0),0),"Released lease rejects placement")
 var editor=load("res://scripts/furniture_editor.gd")
 var packing=load("res://scripts/physical_packing.gd")
 check(packing!=null,"Physical packing script parses")
 var chapter=load("res://scripts/chapter_five.gd")
 check(editor!=null and chapter!=null,"Editor and story scripts parse")
 print("FURNITURE_RULES_RESULT: ","PASS" if failures==0 else "FAIL")
 host.queue_free();quit(0 if failures==0 else 1)
