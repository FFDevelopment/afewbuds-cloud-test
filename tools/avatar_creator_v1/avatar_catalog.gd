extends RefCounted
## AFewBuds character-appearance contract. Shared byte-for-byte by PC and web.
## This is strictly cosmetic; it must never change account/worker/customer records.
const SCHEMA_VERSION:int=1
const OPTIONS:Dictionary={
 "body":["masculine","feminine"],
 "face":["balanced","angular","soft","round"],
 "hair":["short","fade","swept","wavy","curls","locs","ponytail","bald"],
 "beard":["none","stubble","goatee","full"],
 "top":["tee","tank","hoodie","button_shirt"],
 "outerwear":["none","denim_jacket","bomber","long_coat"],
 "bottom":["jeans","cargos","shorts","skirt"],
 "shoes":["sneakers","high_tops","boots"],
 "headwear":["none","cap","beanie"],
 "glasses":["none","clear","sunglasses"],
 "gloves":["none","fabric","leather"],
 "bag":["none","daypack","satchel"],
 "jewelry":["none","studs","chain"]
}
const COLORS:Array[String]=[
 "skin_color","hair_color","eye_color","top_color","outerwear_color",
 "bottom_color","shoe_color","headwear_color","bag_color"
]
const DEFAULT:Dictionary={
 "body":"masculine","face":"balanced","hair":"short","beard":"none",
 "top":"tee","outerwear":"none","bottom":"jeans","shoes":"sneakers",
 "headwear":"none","glasses":"none","gloves":"none","bag":"none","jewelry":"none",
 "skin_color":"a76d4a","hair_color":"292522","eye_color":"493f32",
 "top_color":"387d62","outerwear_color":"394f61","bottom_color":"384a61",
 "shoe_color":"d4d0bc","headwear_color":"374b40","bag_color":"775c44"
}
const SKIN_SWATCHES:Array[String]=["3e2821","5b3729","754831","925e40","a76d4a","bd8760","c99b75","d7ad8a","e1bd9e","efd0b1"]
const SWATCHES:Array[String]=["1d232a","283b35","385d54","487d65","355d88","7e4b60","9c5935","bca17c","dbd2c2","f0f0e8"]
static func defaults()->Dictionary:
 return DEFAULT.duplicate(true)
static func sanitize(source:Variant)->Dictionary:
 var result:Dictionary=defaults()
 if not source is Dictionary:return result
 for slot in OPTIONS:
  var item:Variant=source.get(slot,DEFAULT[slot])
  if item is String and item in OPTIONS[slot]:result[slot]=item
 for key in COLORS:
  var value:Variant=source.get(key,DEFAULT[key])
  if value is String:
   var hex_code:String=str(value).trim_prefix("#").to_lower()
   if hex_code.length()==6 and Color.html_is_valid(hex_code):
    result[key]=hex_code
 return result
static func record_from(source:Variant)->Dictionary:
 var existing:Dictionary=source.duplicate(true) if source is Dictionary else {}
 existing["schema"]=SCHEMA_VERSION
 existing["owner_kind"]="player_only"
 existing["npc_spawn_allowed"]=false
 existing["sale_listing_allowed"]=false
 existing["appearance"]=sanitize(existing.get("appearance",{}))
 existing["created"]=bool(existing.get("created",false))
 return existing
static func label_for(slot:String,value:String)->String:
 if slot=="body":return "Masculine fit" if value=="masculine" else "Feminine fit"
 if slot=="hair" and value=="locs":return "Locs"
 if slot=="top" and value=="tee":return "T-shirt"
 if slot=="bag" and value=="none":return "No bag"
 if value=="none":return "None"
 return value.replace("_"," ").capitalize()
static func option_count()->int:
 var count:int=0
 for slot in OPTIONS:count+=OPTIONS[slot].size()
 return count
