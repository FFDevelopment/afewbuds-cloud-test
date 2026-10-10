extends RefCounted
# A single persisted basket shared by phone ordering and the physical market.
var host:Node3D
var inv:Node
var busy:=false
func setup(owner:Node3D,inventory:Node)->void:host=owner;inv=inventory
func state()->Dictionary:
 if not host.location_state.get("market_cart_v1",{}) is Dictionary:host.location_state.market_cart_v1={}
 if not host.location_state.has("market_cart_v1"):host.location_state.market_cart_v1={}
 return host.location_state.market_cart_v1
func quote(key:String)->Dictionary:
 var kind:=key.get_slice("|",0);var name:=key.get_slice("|",1)
 if kind=="seed" and host.seed_catalog.has(name):
  var data:Dictionary=host.seed_catalog[name];var level:int=int(data.get("unlock",1))
  return {"name":name+" seed","price":int(data.cost),"reason":"Discover this hybrid by growing its parents." if data.get("recipe_only",false) else ("Reach Grower Level %d (current: %d)."%[level,host.grower_level] if host.grower_level<level else "")}
 if key=="fertilizer":return {"name":"Fertilizer · pack of 5","price":45,"reason":""}
 if kind=="item" and inv.furniture.model.CATALOG.has(name):
  return {"name":str(inv.furniture.model.CATALOG[name].name),"price":inv.furniture.model.price_for(name),"reason":""}
 return {"name":"Unavailable item","price":0,"reason":"This item is no longer available."}
func total()->int:
 var value:=0
 for key in state():value+=int(quote(key).price)*int(state()[key])
 return value
func count()->int:
 var value:=0
 for amount in state().values():value+=int(amount)
 return value
func set_quantity(key:String,amount:int)->void:
 if amount<=0:state().erase(key)
 else:state()[key]=clampi(amount,1,99)
 host._save_game();refresh_summaries()
func add(key:String,amount:int)->void:
 var info:=quote(key)
 if not str(info.reason).is_empty():host.status_label.text=info.reason;return
 set_quantity(key,int(state().get(key,0))+amount)
 host.status_label.text="Added to cart. Review your cart to pay and place the order."
func chooser(parent:Node,key:String,disabled:bool=false)->void:
 var row:=HBoxContainer.new();row.add_theme_constant_override("separation",8);parent.add_child(row)
 var amount:=SpinBox.new();amount.min_value=1;amount.max_value=99;amount.step=1;amount.value=1;amount.custom_minimum_size=Vector2(98,40);row.add_child(amount)
 var button:Button=inv.button("Add to cart",func():add(key,int(amount.value)),row)
 button.size_flags_horizontal=Control.SIZE_EXPAND_FILL;button.disabled=disabled or not str(quote(key).reason).is_empty()
func toolbar(parent:Node)->void:
 var button:Button=inv.button("VIEW CART · %d items · $%d"%[count(),total()],show,parent,true)
 button.set_meta("market_cart_summary",true)
func show()->void:
 var editor=inv.furniture
 if host.phone_open:host._toggle_phone()
 if host.neighborhood.location_ops.is_open():host.neighborhood.location_ops.close()
 editor.open();editor.clear();editor.hint.text="CENTRAL MARKET · CART"
 inv.label("Pay once for the whole order. At checkout, collect what fits; the rest stays here for your next visit.",editor.list)
 if state().is_empty():inv.label("Your cart is empty.",editor.list)
 for key in state().keys():
  var info:=quote(key);inv.label("%s · $%d each"%[info.name,info.price],editor.list,18)
  if not str(info.reason).is_empty():inv.label(info.reason,editor.list,15)
  var row:=HBoxContainer.new();editor.list.add_child(row)
  var amount:=SpinBox.new();amount.min_value=1;amount.max_value=99;amount.step=1;amount.value=int(state()[key]);amount.custom_minimum_size=Vector2(98,40);row.add_child(amount)
  amount.value_changed.connect(func(value):set_quantity(key,int(value));editor.hint.text="CENTRAL MARKET · CART · $%d"%total())
  inv.button("Remove",func():set_quantity(key,0);show(),row)
 var summary:Label=inv.label("TOTAL $%d · YOUR CASH $%d"%[total(),host.cash],editor.list,20)
 summary.set_meta("market_cart_total",true)
 inv.button("PLACE ORDER / PAY",func():
  var result:=checkout()
  if result.ok:show()
  editor.hint.text=result.reason,editor.list,true).disabled=state().is_empty()
 inv.button("Awaiting pickup · %d items"%pickup_count(),func():
  if not inv.reachable("market:orders"):editor.hint.text="Your paid order is safe. Walk to Central Market checkout to collect it.";return
  editor.close();inv.open_container("market:orders"),editor.list)
 inv.button("Continue shopping",func():editor.close();host.neighborhood.location_ops.market(),editor.list)
func pickup_count()->int:
 var value:=0
 for amount in inv.contents("market:orders").values():value+=int(amount)
 return value
func checkout()->Dictionary:
 if busy:return {"ok":false,"reason":"Checkout is already processing."}
 if state().is_empty():return {"ok":false,"reason":"Your cart is empty."}
 var basket:Dictionary=state().duplicate(true);var price:=0
 for key in basket:
  if not basket[key] is int and not basket[key] is float:return {"ok":false,"reason":"Invalid quantity. Update the cart."}
  var amount:int=int(basket[key]);var info:=quote(key)
  if amount<1 or amount>99 or float(amount)!=float(basket[key]):return {"ok":false,"reason":"Choose 1–99 of each item."}
  if not str(info.reason).is_empty():return {"ok":false,"reason":info.name+": "+info.reason}
  price+=int(info.price)*amount
 if host.cash<price:return {"ok":false,"reason":"Order costs $%d. You have $%d—need $%d more. Nothing was charged."%[price,host.cash,price-host.cash]}
 busy=true
 # Validate everything before charging. No awaits or callbacks while committing.
 host.cash-=price
 for key in basket:
  var amount:int=int(basket[key]);var name:String=str(key).get_slice("|",1)
  if str(key).begins_with("item|"):
   var model=inv.furniture.model
   for i in amount:
    var id:="furniture_%d"%int(model.state.next_id);model.state.next_id=int(model.state.next_id)+1
    model.state.items[id]={"sku":name,"property":"market:orders","locked":false,"paid":model.price_for(name),"condition":100,"upgrades":{}}
  elif str(key).begins_with("seed|"):
   inv.set_amount("market:orders",key,int(inv.contents("market:orders").get(key,0))+amount)
   host._increment_advancement_stat("seeds_bought",amount)
   if inv.guide!=null:inv.guide.record("order_seed")
  else:
   inv.set_amount("market:orders","fertilizer",int(inv.contents("market:orders").get("fertilizer",0))+amount*5)
   host._increment_advancement_stat("supplies_bought",amount)
   if inv.guide!=null:inv.guide.record("order_fertilizer")
 state().clear();inv.revision+=1
 host._record_daily_expense("Market order",price)
 host._update_cash_ui();host._save_game();busy=false
 if inv.reachable("market:orders"):inv.collect_all()
 return {"ok":true,"reason":"Paid $%d. %d item(s) awaiting pickup at Central Market; everything that fits is in your backpack."%[price,pickup_count()] if inv.reachable("market:orders") else "Paid $%d. Your order is waiting at Central Market checkout."%price}

func seeds(parent:Node)->void:
 inv.label("Choose quantities, add seeds to your cart, then check out once. Paid orders wait at Central Market.",parent)
 toolbar(parent)
 for name in host.SEED_ORDER:
  if not host.seed_catalog.has(name) or host.seed_catalog[name].get("recipe_only",false):continue
  var key:String="seed|"+name;var info:=quote(key)
  var card:=PanelContainer.new();card.add_theme_stylebox_override("panel",inv.ui_style("151d17","44513f",12));parent.add_child(card)
  var box:=VBoxContainer.new();card.add_child(box)
  var heading:=HBoxContainer.new();box.add_child(heading)
  inv.art_rect(key,heading,Vector2(64,64))
  var title:Label=inv.label("%s · $%d"%[info.name,info.price],heading,18);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL
  inv.label("Available" if str(info.reason).is_empty() else info.reason,box,14)
  chooser(box,key)
func supplies(parent:Node)->void:
 inv.art_rect("fertilizer",parent,Vector2(80,80))
 inv.label("Fertilizer · 5 uses per pack · $45 · 5 lb",parent,18)
 toolbar(parent);chooser(parent,"fertilizer")

func refresh_summaries()->void:
 for node in host.find_children("*","Button",true,false):
  if node.get_meta("market_cart_summary",false):node.text="VIEW CART · %d items · $%d"%[count(),total()]
 for node in host.find_children("*","Label",true,false):
  if node.get_meta("market_cart_total",false):node.text="TOTAL $%d · YOUR CASH $%d"%[total(),host.cash]
