"""Restore Reeves favors and in-person check-ins after a fully paid arrangement.

Applied after reward_contact_v1; exact anchors prevent silent baseline drift.
"""

def once(source: str, old: str, new: str, label: str) -> str:
    count = source.count(old)
    if count != 1:
        raise AssertionError(f"{label}: expected one anchor, found {count}")
    return source.replace(old, new, 1)


def patch_main(s: str) -> str:
    # A paid-in-full contact remains friendly; merely walking away does not
    # grant the same post-settlement relationship benefit.
    s = once(s, "func _reeves_remaining_balance() -> int:",
'''func _reeves_is_friendly() -> bool:
\treturn reeves_met and reeves_arrangement_ended and not reeves_arrangement_active and reeves_total_paid >= REEVES_TOTAL_OBLIGATION and reeves_relationship >= 25

func _reeves_remaining_balance() -> int:''', "friendly helper")

    s = once(s,
        'if not reeves_met or not corrupt_contact_unlocked or heat < HEAT_CONTACT_MINIMUM:',
        'if not reeves_met or reeves_arrangement_active or not (corrupt_contact_unlocked or _reeves_is_friendly()) or heat <= 0.0 or (heat < HEAT_CONTACT_MINIMUM and not _reeves_is_friendly()):',
        "contact eligibility")

    s = once(s,
        '''func _open_reeves_visit() -> void:
\tif customer_patience_timer != null:
\t\tcustomer_patience_timer.stop()
\tcustomer_answered = true
\tknock_banner.visible = false
\tsale_panel.visible = true
\tif sale_customer_art != null:
\t\tsale_customer_art.visible = false
\t_clear_substitutes()
''',
        '''func _open_reeves_visit() -> void:
\tif customer_patience_timer != null:
\t\tcustomer_patience_timer.stop()
\tcustomer_answered = true
\tknock_banner.visible = false
\tsale_panel.visible = true
\tif sale_customer_art != null:
\t\tsale_customer_art.visible = false
\t_clear_substitutes()
\tif reeves_visit_reason == "friendly_checkin" and _reeves_is_friendly():
\t\tsale_title.text = "AGENT REEVES - PRIVATE CHECK-IN"
\t\tsale_body.text = "We are square on the $8,000 protection arrangement. No new debt or scheduled payments. If there is heat on you, I can make some calls for $%d to reduce it by up to %d. Or we can just talk." % [_heat_contact_cost(), int(HEAT_CONTACT_REDUCTION)]
\t\t_set_sale_action_labels("PAY $%d - REDUCE HEAT" % _heat_contact_cost(), "JUST TALK", "NOT NOW")
\t\tif sale_primary_button != null:
\t\t\tsale_primary_button.disabled = heat <= 0.0 or cash < _heat_contact_cost()
\t\t_save_game()
\t\treturn
\tif sale_primary_button != null:
\t\tsale_primary_button.disabled = false
''', "friendly visit dialogue")

    s = once(s,
        '''func _reeves_primary_action() -> void:
\t_reeves_pay_half(false)''',
        '''func _reeves_primary_action() -> void:
\tif reeves_visit_reason == "friendly_checkin":
\t\tvar prior_calls: int = corrupt_contact_calls
\t\t_use_heat_contact()
\t\tif corrupt_contact_calls > prior_calls:
\t\t\t_end_reeves_visit()
\t\treturn
\t_reeves_pay_half(false)''', "friendly favor interaction")

    s = once(s,
        '''func _reeves_secondary_action() -> void:
\t_reeves_pay_full(false)''',
        '''func _reeves_secondary_action() -> void:
\tif reeves_visit_reason == "friendly_checkin":
\t\t_end_reeves_visit()
\t\treturn
\t_reeves_pay_full(false)''', "friendly talk interaction")

    s = once(s,
        'func _reeves_decline_action() -> void:\n',
        'func _reeves_decline_action() -> void:\n\tif reeves_visit_reason == "friendly_checkin":\n\t\t_end_reeves_visit()\n\t\treturn\n',
        "friendly decline")

    # Old careers retain their already-settled obligation; no migration,
    # renewed automatic collection, or fake retroactive milestone credits.
    return s


def patch_crew(s: str) -> str:
    s = once(s,
        'var can_help:bool=host.reeves_met and not host.reeves_arrangement_active and (host.corrupt_contact_unlocked or host.heat_peak>=50.0) and host.heat>=host.HEAT_CONTACT_MINIMUM and host.cash>=host._heat_contact_cost()',
        'var can_help:bool=host.reeves_met and not host.reeves_arrangement_active and (not host.reeves_arrangement_ended or host._reeves_is_friendly()) and (host.corrupt_contact_unlocked or host._reeves_is_friendly() or host.heat_peak>=50.0) and (host.heat>=host.HEAT_CONTACT_MINIMUM or (host._reeves_is_friendly() and host.heat>0.0)) and host.cash>=host._heat_contact_cost()',
        "paid favor availability")
    s = once(s,
        '''\tif not host.reeves_arrangement_ended:
\t\tbutton(host.phone_list,"ASK REEVES TO REDUCE HEAT · $%d" % host._heat_contact_cost(),reeves_message.bind("help"),not can_help)''',
        '''\tbutton(host.phone_list,"ASK REEVES TO REDUCE HEAT · $%d" % host._heat_contact_cost(),reeves_message.bind("help"),not can_help)''',
        "settled contact button")
    s = once(s,
        '''\t\t"meeting":
\t\t\toutgoing(who,"Can we talk?")
\t\t\tsend(who,"We can talk when I'm at your door. A message won't start or erase a protection agreement.")''',
        '''\t\t"meeting":
\t\t\toutgoing(who,"Can we talk?")
\t\t\tif host._reeves_is_friendly():
\t\t\t\tif host.customer_waiting or host.reeves_visit_pending:
\t\t\t\t\tsend(who,"Someone's already at your door or I have a visit lined up. Text again later.")
\t\t\t\telse:
\t\t\t\t\thost.reeves_visit_pending=true
\t\t\t\t\thost.reeves_visit_reason="friendly_checkin"
\t\t\t\t\tsend(who,"We are square. I can stop by your place for a private chat. No new protection bill.")
\t\t\t\t\thost._save_game()
\t\t\telse:
\t\t\t\tsend(who,"We can talk when I'm at your door. A message won't start or erase a protection agreement.")''',
        "scheduled post-payoff visit")
    s = once(s,
        '''\t\t"help":
\t\t\tif not host.reeves_met or host.reeves_arrangement_active or host.reeves_arrangement_ended or not (host.corrupt_contact_unlocked or host.heat_peak>=50.0) or host.heat<host.HEAT_CONTACT_MINIMUM or host.cash<host._heat_contact_cost():return''',
        '''\t\t"help":
\t\t\tif not host.reeves_met or host.reeves_arrangement_active or (host.reeves_arrangement_ended and not host._reeves_is_friendly()) or not (host.corrupt_contact_unlocked or host._reeves_is_friendly() or host.heat_peak>=50.0) or (host.heat<host.HEAT_CONTACT_MINIMUM and not (host._reeves_is_friendly() and host.heat>0.0)) or host.cash<host._heat_contact_cost():return''',
        "paid favor message gate")
    s = once(s,
        'label(host.phone_list,"The protection arrangement is settled.")',
        'label(host.phone_list,"The protection arrangement is settled. Paid-in-full relationships retain optional favors and private visits." if host._reeves_is_friendly() else "The protection arrangement is settled.")',
        "settled relationship explanation")
    return s
