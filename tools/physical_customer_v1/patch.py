"""Adapt the approved physical-visit prototype to the rebuilt mobile runtime.
Place after all inventory, map and worker patches; do not modify checkout, sales
payments, cloud sessions or save identifiers.
"""
from pathlib import Path
HERE=Path(__file__).parent

def one(source,old,new,label):
    count=source.count(old)
    if count!=1:
        raise AssertionError(f"Mobile customer encounter source drift {label}: {count} matches for {old[:110]!r}")
    return source.replace(old,new,1)

def patch_main(s):
    s=one(s,"var production_crew:RefCounted","var production_crew:RefCounted\nvar customer_encounters:Node","engine field")
    s=one(s,"\tproduction_crew.setup(self)\n",
        "\tproduction_crew.setup(self)\n\tcustomer_encounters=load(\"res://scripts/customer_encounters.gd\").new()\n\tadd_child(customer_encounters)\n\tcustomer_encounters.setup(self)\n","ready")
    s=one(s,'''\t\t"station_door":
\t\t\tif customer_waiting:
\t\t\t\tif peephole_checked:
\t\t\t\t\t_open_customer_sale()
\t\t\t\telse:
\t\t\t\t\t_open_peephole()
\t\t\telse:
\t\t\t\t_open_peephole()''',
       '''\t\t"station_door":
\t\t\tif customer_waiting:
\t\t\t\tif customer_encounters!=null and customer_encounters.prepare_sale():
\t\t\t\t\t_open_customer_sale()
\t\t\t\telif peephole_checked:
\t\t\t\t\t_open_customer_sale()
\t\t\t\telse:
\t\t\t\t\t_open_peephole()
\t\t\telse:
\t\t\t\t_open_peephole()''',"approach door")
    s=one(s,'''\t\t"door":
\t\t\tif customer_waiting:
\t\t\t\tif peephole_checked:
\t\t\t\t\t_open_customer_sale()
\t\t\t\telse:
\t\t\t\t\t_open_peephole()
\t\t\telse:
\t\t\t\t_open_peephole()''',
       '''\t\t"door":
\t\t\tif customer_waiting:
\t\t\t\tif customer_encounters!=null and customer_encounters.prepare_sale():
\t\t\t\t\t_open_customer_sale()
\t\t\t\telif peephole_checked:
\t\t\t\t\t_open_customer_sale()
\t\t\t\telse:
\t\t\t\t\t_open_peephole()
\t\t\telse:
\t\t\t\t_open_peephole()''',"context door")
    s=one(s,'contextual_button.text = "ANSWER DOOR" if peephole_checked else "LOOK THROUGH PEEPHOLE"',
          'contextual_button.text = "OPEN DOOR · TALK TO CUSTOMER" if customer_encounters!=null and customer_encounters.available() else ("ANSWER DOOR" if peephole_checked else "LOOK THROUGH PEEPHOLE")',"door prompt")
    s=one(s,"func _any_modal_open() -> bool:\n\tif inventory_system!=null",
          "func _any_modal_open() -> bool:\n\tif customer_encounters!=null and customer_encounters.blocks_controls():return true\n\tif inventory_system!=null","modal")
    s=one(s,'''\tif not peephole_checked:
\t\tstatus_label.text = "Check the peephole before answering the door."
\t\t_open_peephole()
\t\treturn''',
          '''\tif not peephole_checked:
\t\tif customer_encounters==null or not customer_encounters.prepare_sale():
\t\t\tstatus_label.text = "Check the peephole before answering the door."
\t\t\t_open_peephole()
\t\t\treturn''',"open sale")
    s=one(s,'''\t_apply_customer_art(sale_customer_art, current_customer, "door_art")
\tsale_body.text = line
\t_clear_substitutes()

func _sell_requested() -> void:''',
          '''\t_apply_customer_art(sale_customer_art, current_customer, "door_art")
\tsale_body.text = line
\t_clear_substitutes()
\tif customer_encounters!=null:customer_encounters.opened_sale()

func _sell_requested() -> void:''',"sale UI")
    s=one(s,'''\tvar newly_known_name: String = _record_customer_encounter(completed)
\tsale_panel.visible = false''',
          '''\tvar newly_known_name: String = _record_customer_encounter(completed)
\tif customer_encounters!=null:customer_encounters.conclude_visit(completed)
\tsale_panel.visible = false''',"departure")
    return s

def patch_crew(s):
    start=s.find("\tvar visitor: String=str(host.current_customer.get(\"name\",\"\"))",s.index("func update_malik() -> void:"))
    end=s.find("\n\nfunc seated_pose(",start)
    if start<0 or end<start:raise AssertionError("Mobile visitor rendering boundary changed")
    # The final already-tested mobile worker avatar behavior above this block
    # is retained exactly. Replace only normal visitor creation/lifetime.
    s=s[:start]+'''\t# All ordinary clients have physical visitor actors; the encounter controller
\t# retains the departing model after the current order has been cleared.
\tif host.customer_encounters!=null and host.customer_encounters.available():
\t\thost.customer_encounters.ensure_visible_guest()
\telif malik_visitor!=null:malik_visitor.hide()'''+s[end:]
    return s

def apply_entries(entries):
    output=[]
    seen=set()
    for path,data,flags in entries:
        if path=="scripts/main.gd":
            data=patch_main(data.decode("utf-8")).encode("utf-8")
            seen.add(path)
        elif path=="scripts/crew_phone.gd":
            data=patch_crew(data.decode("utf-8")).encode("utf-8")
            seen.add(path)
        output.append([path,data,flags])
    assert seen=={"scripts/main.gd","scripts/crew_phone.gd"},seen
    output.append(["scripts/customer_encounters.gd",(HERE/"customer_encounters.gd").read_bytes(),0])
    return output
