"""Mobile phone listing and emergency Heat shutdown parity.

Runs after the existing multi-storage integration. Edits only the matching
UI/shop entry points, never input, cloud login, career saves, or gameplay assets.
"""
from pathlib import Path
HERE=Path(__file__).parent

def exactly(source,old,new,context):
    count=source.count(old)
    if count!=1:raise AssertionError(f"heat shop mobile source drift {context}: {count} matches for {old[:120]!r}")
    return source.replace(old,new,1)

def patch_main(source):
    source=exactly(source,
        '\t\tvar head: HBoxContainer = HBoxContainer.new()\n\t\trow.add_child(head)',
        '''\t\t# Compact web layouts stack the product name above a full-width LIST action.
\t\tvar compact:bool=OS.has_feature("web") or get_viewport().get_visible_rect().size.x<680.0 or get_window().size.x<680
\t\tvar head: BoxContainer=VBoxContainer.new() if compact else HBoxContainer.new()
\t\thead.add_theme_constant_override("separation",8)
\t\trow.add_child(head)''',
        'listing layout')
    source=exactly(source,
        '\t\ttoggle.custom_minimum_size = Vector2(132, 52)\n\t\ttoggle.disabled = stock <= 0 or not business_open',
        '''\t\ttoggle.custom_minimum_size = Vector2(132, 52)
\t\ttoggle.set_meta("product_listing_toggle",true)
\t\ttoggle.autowrap_mode=TextServer.AUTOWRAP_OFF
\t\ttoggle.size_flags_horizontal=Control.SIZE_EXPAND_FILL
\t\ttoggle.add_theme_font_size_override("font_size",16)
\t\ttoggle.disabled = stock <= 0 or not business_open''',
        'listing button visibility')
    source=exactly(source,
        '\tshutdown_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART\n\tphone_list.add_child(shutdown_note)',
        '''\tshutdown_note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
\tphone_list.add_child(shutdown_note)
\tif neighborhood!=null and neighborhood.location_ops!=null and neighborhood.location_ops.crew!=null:
\t\tvar shop:RefCounted=neighborhood.location_ops.crew.shop
\t\tfor property_id in ["apartment","house"]:
\t\t\tif neighborhood.location_ops._property_controlled(property_id):
\t\t\t\tshop.render(phone_list,property_id)''',
        'heat controls available without crew')
    return source

def patch_crew(source):
    return exactly(source,
        '\tbutton(ops.ui.body,"REOPEN APARTMENT" if not host.business_open else "APARTMENT AWAY · TEXT CLIENTS",host._reopen_business if not host.business_open else host._set_business_away)\n\tbutton(ops.ui.body,"APARTMENT LAY LOW · SHUT DOWN",shutdown)',
        '''\tbutton(ops.ui.body,"REOPEN APARTMENT" if not host.business_open else "CLOSE APARTMENT",shop.owner_control.bind("apartment","open" if not host.business_open else "close"),not host.business_open and (host._staff_heat_locked() or host.game_day<host.raid_lockdown_until_day))
\tbutton(ops.ui.body,"APARTMENT LAY LOW · SHUT DOWN",shop.owner_control.bind("apartment","shutdown"))''',
        'legacy apartment computer')
def apply_entries(entries):
    found=set()
    result=[]
    for path,data,flags in entries:
        if path=="scripts/main.gd":
            data=patch_main(data.decode("utf-8")).encode("utf-8")
            found.add(path)
        elif path=="scripts/crew_phone.gd":
            data=patch_crew(data.decode("utf-8")).encode("utf-8")
            found.add(path)
        result.append([path,data,flags])
    if found!={"scripts/main.gd","scripts/crew_phone.gd"}:
        raise AssertionError(f"Missing final phone/crew source {found}")
    return result
