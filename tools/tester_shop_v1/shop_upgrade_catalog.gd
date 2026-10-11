extends RefCounted
## Read-only phone upgrade catalog and existing on-site backpack purchase UI.
## No new career schema, inventory ownership, or payment route is introduced.
const FAMILIES=[
 {"title":"Packing Benches","items":["bench_1","bench_2","bench_3"]},
 {"title":"Grow Tents","items":["tent_1","tent_2","grow_tent","tent_4"]},
 {"title":"Grow Supply Shelves","items":["shelf_1","shelf_2","shelf_3"]},
 {"title":"Storage & Vaults","items":["storage_1","storage_2","storage_3","storage_4","storage_5"]},
 {"title":"Dealer Storage","items":["dealer_1","dealer_2","dealer_3","dealer_4"]}
]
static func backpack_text(inv:Node)->String:
 inv.ensure_state()
 var level:int=clampi(int(inv.state.get("backpack_level",1)),1,inv.BACKPACK_LIMITS.size())
 var pounds:int=int(inv.BACKPACK_LIMITS[level-1]/inv.POUND)
 return "Backpack Level %d · %d lb capacity" % [level,pounds]
static func market(host:Node3D,parent:Node)->void:
 if host.inventory_system==null:return
 var inv:Node=host.inventory_system
 inv.ensure_state()
 inv.label("PERSONAL BACKPACK UPGRADES",parent,21)
 inv.label(backpack_text(inv),parent,17)
 var level:int=int(inv.state.backpack_level)
 if level>=inv.BACKPACK_LIMITS.size():
  inv.label("Maximum backpack capacity unlocked. Your saved upgrade is permanent.",parent,15)
  return
 var next_capacity:int=int(inv.BACKPACK_LIMITS[level]/inv.POUND)
 var price:int=int(inv.BACKPACK_PRICES[level-1])
 inv.label("Next level: %d lb · $%d. Upgrades increase carrying capacity without deleting existing items." % [next_capacity,price],parent,15)
 var buy:Button=inv.button("UPGRADE BACKPACK TO LEVEL %d · $%d" % [level+1,price],inv.upgrade_backpack.bind(level),parent,true)
 buy.disabled=host.cash<price or not inv.reachable("market:orders")
 if host.cash<price:inv.label("Need $%d more. Your current backpack level is unchanged." % (price-host.cash),parent,14)
 elif not inv.reachable("market:orders"):inv.label("Visit the Central Market checkout to buy this upgrade.",parent,14)
static func phone(host:Node3D,parent:Node)->void:
 if host.inventory_system==null or host.inventory_system.furniture==null:return
 var inv:Node=host.inventory_system
 inv.ensure_state()
 inv.label("SHOP UPGRADES · BROWSE",parent,21)
 inv.label("Buy starter furniture and equipment at Central Market for pickup or property delivery. Once placed, select that specific item in Furniture Arrangement to upgrade it. Tent size is separate from its Basic I / LED II lighting.",parent,15)
 inv.label(backpack_text(inv),parent,19)
 var level:int=int(inv.state.backpack_level)
 if level>=inv.BACKPACK_LIMITS.size():
  inv.label("Backpack: MAXIMUM CAPACITY",parent,16)
 else:
  var pounds:int=int(inv.BACKPACK_LIMITS[level]/inv.POUND)
  var cost:int=int(inv.BACKPACK_PRICES[level-1])
  inv.label("NEXT BACKPACK LEVEL %d · %d lb · $%d" % [level+1,pounds,cost],parent,17)
  inv.label("Your upgrade can be purchased only while standing at Central Market. No remote charge will be made from this page.",parent,14)
 var model:RefCounted=inv.furniture.model
 for family in FAMILIES:
  inv.label(str(family.title).to_upper(),parent,19)
  for sku in family.items:
   if not model.CATALOG.has(sku):continue
   var item:Dictionary=model.CATALOG[sku]
   var tier:int=int(item.get("tier",1))
   var line:String="%s" % str(item.get("name",sku))
   if tier>1:
    var base:String=sku.get_slice("_",0)+"_"+str(tier-1)
    var cost:int=maxi(0,int(model.price_for(sku))-int(model.price_for(base))) if model.CATALOG.has(base) else 0
    line+=" · Level %d upgrade +$%d" % [tier,cost]
   else:
    line+=" · Buy at Market $%d" % int(model.price_for(sku))
   if item.has("plants"):line+=" · %d plants · Basic grow light included" % int(item.plants)
   if item.has("capacity"):line+=" · %d capacity" % int(item.capacity)
   var unlocked_at:int=model.unlock_level(sku)
   if unlocked_at>1:line+=" · Unlock: Grower Lv %d" % unlocked_at
   inv.label(line,parent,15)
  if str(family.title)=="Grow Tents":inv.label("Each tent: upgrade the built-in light to LED II for $320 by selecting that tent in Arrangement. No new tent purchase is needed.",parent,14)
 inv.label("Higher levels are not separate shop purchases. Owned upgraded furniture, existing stock, deliveries and career progress remain unchanged.",parent,14)
