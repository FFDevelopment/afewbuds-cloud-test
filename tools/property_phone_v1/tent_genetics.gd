extends RefCounted
## A harvest discovery system, not a phone crafting table. All outcomes and
## lineage live in the existing location save and work for future catalog seeds.
var host:Node3D
const CROSS_CHANCE_PERCENT=15
func setup(owner:Node3D) -> void:
	host=owner
	var data:Dictionary=state()
	for name in data.discoveries:register_strain(name,data.discoveries[name].traits)
func state() -> Dictionary:
	if not host.location_state.get("tent_genetics",{}) is Dictionary or not host.location_state.has("tent_genetics"):
		host.location_state["tent_genetics"]={}
	var data:Dictionary=host.location_state.tent_genetics
	if not data.has("salt"):data["salt"]=str(host.rng.randi())+str(host.rng.randi())
	if not data.has("next_cycle"):data["next_cycle"]=1
	if not data.has("discoveries"):data["discoveries"]={}
	if not data.has("lineages"):data["lineages"]={}
	if not data.has("pending"):data["pending"]={}
	data["schema"]=1
	return data
func cycle(slot:Dictionary) -> int:
	if not slot.has("genetics_cycle"):
		var data:Dictionary=state()
		slot["genetics_cycle"]=int(data.next_cycle);data.next_cycle=int(data.next_cycle)+1
	return int(slot.genetics_cycle)
func planted(index:int) -> void:
	cycle(host.plant_slots[index])
func eligible(a:Dictionary,b:Dictionary) -> bool:
	return int(a.get("stage",-1))>=2 and int(b.get("stage",-1))>=2 and not bool(a.get("dead",false)) and not bool(b.get("dead",false)) and str(a.get("strain",""))!=str(b.get("strain","")) and host.seed_catalog.has(str(a.get("strain",""))) and host.seed_catalog.has(str(b.get("strain","")))
func pair_roll(a:Dictionary,b:Dictionary) -> int:
	var ids:Array[int]=[cycle(a),cycle(b)];ids.sort()
	return int((str(state().salt)+":"+str(ids[0])+":"+str(ids[1])).sha256_text().left(8).hex_to_int()%100)
func register_strain(name:String,traits:Dictionary) -> void:
	host.seed_catalog[name]=traits.duplicate(true)
	if not host.SEED_ORDER.has(name):host.SEED_ORDER.append(name)
func discover(a:String,b:String,tent_id:String,property:String) -> String:
	var parents:Array[String]=[a,b];parents.sort()
	var data:Dictionary=state()
	var lineage:String=JSON.stringify(parents).sha256_text()
	if data.lineages.has(lineage):return str(data.lineages[lineage])
	var name:String=""
	# Existing named hybrids and owned seeds retain their identity.
	for recipe in host._genetics_recipe_catalog():
		var known:Array[String]=[str(recipe.parent_a),str(recipe.parent_b)];known.sort()
		if known==parents:name=str(recipe.output);break
	if name.is_empty():
		var first:PackedStringArray=parents[0].split(" ",false)
		var second:PackedStringArray=parents[1].split(" ",false)
		name=first[0]+" "+second[-1]
		if host.seed_catalog.has(name):name+=" "+lineage.left(6).to_upper()
		while host.seed_catalog.has(name):name+="X"
	var left:Dictionary=host.seed_catalog[parents[0]];var right:Dictionary=host.seed_catalog[parents[1]]
	var traits:Dictionary=host.seed_catalog.get(name,{}).duplicate(true)
	if traits.is_empty():
		# Averaging preserves balance across repeated generations.
		traits={"unlock":1,"cost":0,"price":maxi(1,int(round((float(left.get("price",14))+float(right.get("price",14)))/2.0))),"harvest":maxi(1,int(round((float(left.get("harvest",8))+float(right.get("harvest",8)))/2.0))),"grade":str(left.get("grade","B")),"profile":str(left.get("profile","custom"))}
	traits["recipe_only"]=true;traits["unlock"]=1
	traits["description"]="Discovered by growing "+parents[0]+" and "+parents[1]+" together."
	data.lineages[lineage]=name
	data.discoveries[name]={"parents":parents,"lineage":lineage,"day":host.game_day,"property":property,"tent":tent_id,"method":"Different strains flowered together in the same tent; seed found at harvest.","traits":traits}
	register_strain(name,traits)
	host._add_progress(30,5)
	return name
func harvest(index:int) -> Array[String]:
	var found:Array[String]=[]
	if host.inventory_system==null or host.inventory_system.furniture==null:return found
	var model:RefCounted=host.inventory_system.furniture.model
	var plant:Dictionary=host.plant_slots[index]
	for tent_id in model.state.items:
		var tent:Dictionary=model.state.items[tent_id]
		var slots:Array=tent.get("slots",[])
		if not model.is_tent(tent) or not tent.has("position") or slots.size()<2 or not slots.has(index):continue
		for other_index in slots:
			if int(other_index)==index or int(other_index)<0 or int(other_index)>=host.plant_slots.size():continue
			var other:Dictionary=host.plant_slots[int(other_index)]
			if not eligible(plant,other):continue
			var own_cycle:int=cycle(plant);var other_cycle:int=cycle(other)
			var checked:Array=plant.get("genetics_checked",[])
			if checked.any(func(value):return int(value)==other_cycle):continue
			checked.append(other_cycle);plant["genetics_checked"]=checked
			var theirs:Array=other.get("genetics_checked",[]);theirs.append(own_cycle);other["genetics_checked"]=theirs
			if pair_roll(plant,other)>=CROSS_CHANCE_PERCENT:continue
			var name:String=discover(str(plant.strain),str(other.strain),str(tent_id),str(tent.property))
			var data:Dictionary=state();data.pending[name]=int(data.pending.get(name,0))+1
			host._increment_advancement_stat("hybrids_created")
			found.append(name)
		break
	# Overflow is a durable, claim-only reward. It is never deposited in storage.
	claim_pending(false)
	return found
func claim_pending(save_now:bool=true) -> void:
	if host.inventory_system==null:return
	var inv:Node=host.inventory_system;var data:Dictionary=state()
	for name in data.pending.keys():
		var item:String="seed|"+str(name)
		var count:int=mini(int(data.pending[name]),inv.free_space("backpack",item))
		if count<=0:continue
		inv.set_amount("backpack",item,int(inv.contents("backpack").get(item,0))+count)
		inv.revision+=1;data.pending[name]=int(data.pending[name])-count
		if int(data.pending[name])<=0:data.pending.erase(name)
	if save_now:
		host._save_game();host._refresh_phone()
func render(parent:VBoxContainer) -> void:
	var crew:RefCounted=host.neighborhood.location_ops.crew
	crew.label(parent,"GENETICS · DISCOVERY JOURNAL")
	crew.label(parent,"Grow different strains together in one 2-, 3- or 4-plant tent. When both reach flowering, harvesting can reveal a hybrid seed. One-plant tents and identical strains do not cross. Each plant pair has one saved chance per grow cycle.")
	crew.label(parent,"New seeds go into your backpack. A full backpack keeps the earned seed here for collection; it never disappears.")
	crew.label(parent,"RESEARCH NOTES · Parent hints")
	for recipe in host._genetics_recipe_catalog():
		if host._genetics_recipe_unlocked(recipe):
			crew.label(parent,str(recipe.output)+": grow "+str(recipe.parent_a)+" + "+str(recipe.parent_b)+" in the same tent. A chance at a premium cross, not a guaranteed result.")
		else:crew.label(parent,str(recipe.output)+": claim "+str(recipe.unlock_label)+" to reveal the parents. You can still discover this cross naturally.")
	var data:Dictionary=state()
	if not data.pending.is_empty():
		for name in data.pending:crew.label(parent,"Waiting for backpack space: %d × %s" % [int(data.pending[name]),str(name)])
		crew.button(parent,"COLLECT EARNED SEEDS",claim_pending)
	if data.discoveries.is_empty():crew.label(parent,"No discoveries yet. Try growing two different strains in the same tent.")
	for name in data.discoveries:
		var entry:Dictionary=data.discoveries[name]
		var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",host._style_box(Color("15271e"),Color("496b55"),14,1));parent.add_child(card)
		var box:=VBoxContainer.new();card.add_child(box)
		crew.label(box,str(name))
		crew.label(box,"Parents: "+str(entry.parents[0])+" × "+str(entry.parents[1]))
		crew.label(box,"Discovered Day %d · %s · %s" % [int(entry.day),str(entry.property).capitalize(),str(entry.tent)])
		crew.label(box,str(entry.method))
		crew.label(box,"Yield: %dg · Base value: $%d/g" % [int(entry.traits.harvest),int(entry.traits.price)])
