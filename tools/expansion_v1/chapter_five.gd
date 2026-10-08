extends RefCounted
const STEPS=[
 {"id":"settle","title":"Make It Yours","detail":"Place and lock two pieces of furniture in the house.","reward":150,"text":"Rod: Keys do not make a home. Set the rooms up for how you actually work."},
 {"id":"grow","title":"Room to Grow","detail":"Place a tent in the house grow room, then harvest three plants.","reward":200,"text":"Rod: Now give the grow room a proper setup. Let the first house harvest prove the move was worth it."},
 {"id":"craft","title":"A Consistent Batch","detail":"Trim 30g and seal five bags after setting up the house.","reward":250,"text":"Kobi: More space is useful. Consistency is what people come back for. Show me five clean batches."},
 {"id":"customers","title":"House Regulars","detail":"Make five personal sales and two dealer sales from the new operation.","reward":300,"text":"Malik: Keep your regulars looked after while the crew finds its rhythm. Nobody needs a crowd at the front door."},
 {"id":"balance","title":"Keep the Lights On","detail":"Pay a house electric or water bill and clear overdue property balances.","reward":200,"text":"Rod: A bigger place comes with real bills. Stay square before you promise anybody more."},
 {"id":"finale","title":"Open House, Quiet Business","detail":"Reach $2,500 new revenue, ten personal sales and Heat at or below 25; meet Rod to finish.","reward":500,"text":"Rod: The house runs, the customers come back, and the bills are covered. Come see me when things are quiet. I want to talk about what comes next."}]
var host:Node
var state:Dictionary
var furniture:RefCounted
func setup(owner:Node,items:RefCounted) -> void:
 host=owner;furniture=items
 if not host.location_state.has("chapter_five"):host.location_state["chapter_five"]={}
 state=host.location_state.chapter_five
func started() -> bool:return bool(host.property_opportunity_state.get("first_entry",false))
func snapshot() -> Dictionary:
 var out:Dictionary=host.advancement_stats.duplicate(true)
 out["revenue"]=host.lifetime_revenue
 out["house_bills"]=int(host.location_state.get("house_bills_paid",0))
 return out
func progress(key:String) -> int:
 return maxi(0,int(snapshot().get(key,0))-int(state.get("baseline",{}).get(key,0)))
func stage() -> int:return clampi(int(state.get("stage",0)),0,STEPS.size())
func complete() -> bool:return stage()>=STEPS.size()
func tick() -> void:
 if not started() or host._simulation_blocked():return
 if not state.has("baseline"):
  state["baseline"]=snapshot();state["stage"]=0;state["rewards"]={};message(STEPS[0].text);host._save_game()
 if complete() or stage()==STEPS.size()-1:return
 if ready():advance()
func placed(tents:bool) -> int:
 var total:=0
 for e in furniture.state.items.values():
  if e.get("property","")=="house" and bool(e.get("locked",false)) and (e.sku=="grow_tent")==tents:total+=1
 return total
func ready() -> bool:
 if not state.has("baseline") or complete():return false
 match stage():
  0:return placed(false)>=2
  1:return placed(true)>=1 and progress("harvests")>=3
  2:return progress("grams_trimmed")>=30 and progress("bags_sealed")>=5
  3:return progress("sales")-progress("dealer_sales")>=5 and progress("dealer_sales")>=2
  4:return progress("house_bills")>=1 and not host.neighborhood.location_ops._apartment_overdue() and not host.neighborhood.location_ops._house_overdue()
  5:return progress("revenue")>=2500 and progress("sales")-progress("dealer_sales")>=10 and host.heat<=25
 return false
func meet_rod() -> bool:
 if stage()!=5 or not ready() or host._simulation_blocked():return false
 advance();return true
func advance() -> void:
 var entry:Dictionary=STEPS[stage()]
 if not state.rewards.has(entry.id):
  state.rewards[entry.id]=true;host.cash+=int(entry.reward);host._update_cash_ui()
 state.stage=stage()+1
 if complete():
  state["completed_day"]=host.game_day
  message("Rod: You built an operation, not just a bigger apartment. Chapter 5 complete. Next up: Joint Junction. We grow carefully, on our terms.")
 else:message(STEPS[stage()].text)
 host._save_game()
func message(text:String) -> void:
 var split:=text.find(":")
 host.phone_text_messages.append({"sender":text.substr(0,split),"body":text.substr(split+2),"day":host.game_day,"time":host._format_game_clock(),"read":false})
 while host.phone_text_messages.size()>120:host.phone_text_messages.pop_front()
 host.phone_text_unread+=1
func description() -> String:
 if not started():return "Move into the house to begin Chapter 5."
 if complete():return "CHAPTER 5 COMPLETE - BUILDING AN OPERATION\nThe house is established. Chapter 6: Joint Junction is the next story chapter."
 var lines:=PackedStringArray()
 for i in range(STEPS.size()):
  var e:Dictionary=STEPS[i]
  lines.append(("Done: " if i<stage() else ("Current: " if i==stage() else "Next: "))+str(e.title)+"\n"+str(e.detail))
 return "\n\n".join(lines)
