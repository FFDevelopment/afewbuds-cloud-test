"""Isolated public-beta market and phone upgrades patch.
Applied after the established inventory/properties/graphics adapters, without
touching unrelated gameplay or live career saving. Assert every text splice.
"""
import re

def must(source, old, new, label):
    count=source.count(old)
    assert count==1, f"tester shop {label}: expected 1 patch anchor, got {count}"
    return source.replace(old,new,1)

def patch_main(source):
    source=must(source,
        'if app_name in ["seeds","supplies"]:return "shop"',
        'if app_name in ["seeds","supplies","shop_upgrades"]:return "shop"',
        "phone app parent")
    marker='\t\t\t_build_shop_app()'
    # App stays under the existing Phone > Shop category, not the property menu.
    source=must(source,marker,marker+
        '\n\t\t"shop_upgrades":\n\t\t\tphone_title.text = "Shop Upgrades"\n'
        '\t\t\tload("res://scripts/shop_upgrade_catalog.gd").phone(self,phone_list)',
        "shop app route")
    function=re.search(r"(?m)^func _build_shop_app\(\) -> void:\n.*?(?=^func |\Z)",source,re.S)
    assert function is not None, "tester shop: missing Phone Shop screen"
    new_func='''func _build_shop_app() -> void:
\tif neighborhood!=null and neighborhood.location_ops!=null:neighborhood.location_ops.order_summary(phone_list)
\tvar intro:Label=Label.new()
\tintro.text="Seeds and fertilizer wait at Central Market pickup. Browse backpack and equipment upgrades here; order furniture for property curbside delivery from the market checkout."
\tintro.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
\tphone_list.add_child(intro)
\tvar grid:GridContainer=_phone_category_grid()
\t_add_phone_app_tile(grid,"","Supplies","Fertilizer orders & pickup","supplies")
\t_add_phone_app_tile(grid,"","Seed Orders","Order for Central Market pickup","seeds")
\t_add_phone_app_tile(grid,"","Shop Upgrades","Backpacks, benches, grow and storage tiers","shop_upgrades")

'''
    source=source[:function.start()]+new_func+source[function.end():]
    return source

def patch_location(source):
    old='\tmarket_card("equipment|Packing Bench","Stations & equipment","Buy basic or upgraded equipment; retain your old items.",func():host.inventory_system.furniture.shop("equipment"))'
    new='\tmarket_card("equipment|Packing Bench","Stations & equipment","Buy the same working benches used in the starter apartment.",func():host.inventory_system.furniture.shop("equipment"))'
    source=must(source,old,new+'\n\tload("res://scripts/shop_upgrade_catalog.gd").market(host,ui.body)',"on-site backpack upgrades")
    source=must(source,'\tmarket_card("equipment|Storage Shelving II","Furniture","Furnish your properties. Delivered to Property Storage.",market_furniture)',
                '\tmarket_card("equipment|Storage Shelving II","Furniture","Order furniture for pickup or owned property curbside delivery.",market_furniture)',
                "market delivery description")
    replacements = {
        "Buy additional equipment at Central Market. Purchases must be delivered or carried to this property.": "Buy starter equipment at Central Market. Upgrade each placed piece in Furniture Arrangement.",
        "Owned equipment stays with you when packed. Upgrade an empty item, or buy and place a better replacement.": "Upgrade installed equipment in Arrangement. Tiers and paid improvements stay with an item when packed.",
    }
    for before, after in replacements.items():
        if before in source: source = source.replace(before, after, 1)
    return source
