extends RefCounted
## Offline, state-grounded dialogue. No remote API or generated gameplay commands.
## A saved per-contact/intent cursor prevents consecutive repetitions after reload.
const LINES={
 "missed":["Hey, stopped by but couldn't catch you. When's a good time?","Was over at yours. You around later?","Missed you at the apartment. Text me when you're free."],
 "appointment_missed":["Came by when we agreed but couldn't catch you. Want to pick another time?","I was there for our meetup. Nobody answered—when works for you?","Couldn't reach you at our scheduled time. Let me know when to try again."],
 "unavailable":["Couldn't get anything this time. Let me know when you're taking orders again.","Looks like now's not a good time. Text me when you're ready.","I'll try another time. Let me know when you're available."],
 "scheduled":["Sounds good. See you {when}.","Got it, I'll stop by {when}.","Works for me. I'll come over {when}."],
 "declined":["No worries. Catch you another time.","All good, just let me know.","Okay, we'll sort another time."],
 "assigned":["Got it, I'm assigned to the {property}. I'll use the stock and equipment there.","The {property}, got you. I'll work with what's there.","Okay, switching to the {property}. Keeping its stock and equipment separate."],
 "closed":["Closed up the {property} for clients. Left the equipment as it was.","No more sales at the {property} for now. Equipment's still on its usual settings.","The {property} is closed to clients. Haven't touched the equipment."],
 "shutdown":["The {property} is shut down. Lights and ventilation off, work and sales paused.","All quiet at the {property}. Switched off the lights and ventilation and stopped work and sales.","Done at the {property}. We're laying low—lights and ventilation off, nobody working or selling."],
 "restored":["The {property} is open again. Put the equipment back how you had it before shutdown.","Set back up at the {property}. Previous equipment settings restored, and we're open.","Back open at the {property}. Restored the old settings; anything that was off is still off."],
 "opened":["The {property} is open again. Equipment settings are unchanged.","Back open for clients at the {property}. Left the equipment alone.","Ready for sales at the {property} again. Same equipment settings as before."],
 "off_duty":["Can't handle the {property} right now. I need to be on duty and out of custody first.","I need to be on duty and free from custody before I can manage the {property}.","Not available to manage the {property}. Check my duty and custody status first."],
 "blocked":["Can't reopen the {property} yet. Heat or raid restrictions are still in effect.","Still blocked from reopening the {property} by the heat or raid restrictions.","Not clear to reopen the {property} yet. Those heat or raid restrictions haven't lifted."],
 "setup_first":["We're still shut down at the {property}. Send Set Up Shop first so I can restore the equipment.","Need to set the {property} back up first. Use Set Up Shop and I'll restore the equipment.","The {property} is laying low. Set Up Shop will restore the equipment and reopen."],
 "status":["The {property} is {status} right now.","Quick update: the {property} is {status}.","Checked the {property}. Current status: {status}."],
 "served":["Just served {client}: {qty}g of {product}. Proceeds will settle at closeout.","{client} got their {qty}g of {product}. We'll settle the proceeds at closeout.","Finished with {client}—{qty}g of {product}. Proceeds go into closeout."],
 "short_stock":["Couldn't fill {client}'s order for {qty}g of {product}. Check packaged stock and what's reserved.","{client} wants {qty}g of {product}, but I couldn't fill it. Can you check the packaged and reserved stock?","Can't cover {qty}g of {product} for {client}. Check what's packaged and what's reserved."]
}
static func compose(host:Node,name:String,intent:String,context:Dictionary={}) -> String:
 if not LINES.has(intent):return ""
 if not host.location_state.get("phone_dialogue",{}) is Dictionary:host.location_state["phone_dialogue"]={}
 if not host.location_state.has("phone_dialogue"):host.location_state["phone_dialogue"]={}
 var memory:Dictionary=host.location_state.phone_dialogue
 var key:String=name+":"+intent
 var cursor:int=int(memory.get(key,0))
 # Stable starting voice per contact, separate from gameplay random numbers.
 var offset:int=(name+intent).sha256_text().substr(0,7).hex_to_int()%LINES[intent].size()
 var text:String=LINES[intent][(offset+cursor)%LINES[intent].size()]
 memory[key]=cursor+1
 for field in context:text=text.replace("{"+str(field)+"}",str(context[field]))
 return text
