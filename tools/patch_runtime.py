from pathlib import Path
import struct, hashlib, re, json

SOURCE = Path("index-cloudtest10.pck")
TARGET = Path("index-cloudtest10.pck")
PACK_URL = "index-cloudtest10.pck?build=28"
RELEASE = "0.7.9-beta.19-cloudtest.28"

def align(n, a=32):
    return (n+a-1)//a*a

def parse(path):
    blob=path.read_bytes()
    if blob[:4] != b"GDPC":
        raise SystemExit("not pck")
    fb=struct.unpack_from("<Q",blob,24)[0]
    do=struct.unpack_from("<Q",blob,32)[0]
    count=struct.unpack_from("<I",blob,do)[0]
    pos=do+4
    entries=[]
    for _ in range(count):
        plen=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        name=blob[pos:pos+plen].rstrip(b"\0").decode(); pos+=plen
        off=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        size=struct.unpack_from("<Q",blob,pos)[0]; pos+=8
        md5=blob[pos:pos+16]; pos+=16
        flags=struct.unpack_from("<I",blob,pos)[0]; pos+=4
        data=blob[fb+off:fb+off+size]
        if hashlib.md5(data).digest()!=md5:
            raise SystemExit("md5 mismatch "+name)
        entries.append([name,data,flags])
    return blob,fb,entries

def rebuild(blob,fb,entries):
    out=bytearray(blob[:fb]); cur=0; directory=[]
    for name,data,flags in entries:
        at=align(cur)
        out.extend(b"\0"*(at-cur))
        off=at
        out.extend(data)
        cur=off+len(data)
        directory.append((name,off,len(data),hashlib.md5(data).digest(),flags))
    do=align(len(out))
    out.extend(b"\0"*(do-len(out)))
    struct.pack_into("<Q",out,32,do)
    out.extend(struct.pack("<I",len(directory)))
    for name,off,size,md5,flags in directory:
        raw=name.encode(); plen=(len(raw)+3)//4*4
        out.extend(struct.pack("<I",plen)); out.extend(raw); out.extend(b"\0"*(plen-len(raw)))
        out.extend(struct.pack("<Q",off)); out.extend(struct.pack("<Q",size)); out.extend(md5); out.extend(struct.pack("<I",flags))
    return bytes(out)

blob,fb,entries=parse(SOURCE)

for row in entries:
    if row[0]!="scripts/main.gd":
        continue
    text=row[1].decode("utf-8","replace").rstrip(" \n\0")

    # Persist partial real-time quiet-day progress across pause sessions.
    quiet_var="var reeves_quiet_days: int = 0\n"
    if quiet_var not in text:
        raise SystemExit("reeves_quiet_days declaration missing")
    text=text.replace(quiet_var, quiet_var+"var reeves_quiet_pause_seconds: float = 0.0\n", 1)

    # Heat cools by 100 points over 72 real minutes while paused/away.
    helper = '''func _apply_paused_heat_and_quiet_time(elapsed_seconds: float) -> void:
\tif elapsed_seconds <= 0.0:
\t\treturn
\tvar paused_heat_rate: float = 100.0 / (72.0 * 60.0)
\t_reduce_heat(paused_heat_rate * elapsed_seconds, "Heat cooled while paused", true)
\tif reeves_arrangement_active and lay_low_active and not business_open:
\t\treeves_quiet_pause_seconds += elapsed_seconds
\t\tvar quiet_day_seconds: float = 24.0 * 60.0
\t\tvar earned_days: int = int(floor(reeves_quiet_pause_seconds / quiet_day_seconds))
\t\tif earned_days > 0:
\t\t\treeves_quiet_days = mini(REEVES_QUIET_EXIT_DAYS, reeves_quiet_days + earned_days)
\t\t\treeves_quiet_pause_seconds -= float(earned_days) * quiet_day_seconds

'''
    plant_marker="func _plant_clock_snapshot() -> Dictionary:\n"
    if plant_marker not in text:
        raise SystemExit("plant clock marker missing")
    if "func _apply_paused_heat_and_quiet_time(" not in text:
        text=text.replace(plant_marker,helper+plant_marker,1)

    # Apply offline/closed time on load using the existing saved clock timestamp.
    restore_pat=re.compile(r'^func _restore_plant_clock\(data: Dictionary, now_unix: float = -1.0\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    rm=restore_pat.search(text)
    if not rm:
        raise SystemExit("restore plant clock function missing")
    rf=rm.group(0)
    stamp_line='\t\tvar stamp: float = float(clock.get("snapshot_unix", now))\n'
    if stamp_line not in rf:
        raise SystemExit("plant clock stamp line missing")
    rf=rf.replace(stamp_line, stamp_line+'\t\tif is_finite(stamp) and stamp > 0.0:\n\t\t\t_apply_paused_heat_and_quiet_time(maxf(0.0, now - stamp))\n',1)
    text=text[:rm.start()]+rf.rstrip()+"\n\n"+text[rm.end():]

    # Apply the same catch-up when resuming from an in-session pause.
    resume_pat=re.compile(r'^func _resume_gameplay\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    rm=resume_pat.search(text)
    if not rm:
        raise SystemExit("resume function missing")
    resume=rm.group(0)
    settle='\t_settle_away_plants()\n'
    if settle not in resume:
        raise SystemExit("resume settle call missing")
    resume=resume.replace(settle,'\tif away_started_unix > 0.0:\n\t\tvar paused_now: float = Time.get_unix_time_from_system()\n\t\t_apply_paused_heat_and_quiet_time(maxf(0.0, paused_now - away_started_unix))\n'+settle,1)
    text=text[:rm.start()]+resume.rstrip()+"\n\n"+text[rm.end():]

    # Keep partial quiet progress consistent with normal in-game quiet days.
    day_pat=re.compile(r'^func _process_reeves_day_transition\(closing_day: int\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    dm=day_pat.search(text)
    if not dm:
        raise SystemExit("Reeves day transition missing")
    dayfn=dm.group(0)
    old_day='\tif not business_open and dealer_sales_today <= 0 and heat <= 25.0:\n\t\treeves_quiet_days += 1\n\telse:\n\t\treeves_quiet_days = 0\n'
    new_day='\tif not business_open and dealer_sales_today <= 0 and heat <= 25.0:\n\t\treeves_quiet_days = mini(REEVES_QUIET_EXIT_DAYS, reeves_quiet_days + 1)\n\t\treeves_quiet_pause_seconds = 0.0\n\telse:\n\t\treeves_quiet_days = 0\n\t\treeves_quiet_pause_seconds = 0.0\n'
    if old_day not in dayfn:
        raise SystemExit("quiet-day transition block missing")
    dayfn=dayfn.replace(old_day,new_day,1)
    text=text[:dm.start()]+dayfn.rstrip()+"\n\n"+text[dm.end():]

    # Starting/stopping Lay Low resets only the partial real-time fraction.
    start_pat=re.compile(r'^func _start_lay_low\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    sm=start_pat.search(text)
    if not sm:
        raise SystemExit("start lay low function missing")
    startfn=sm.group(0)
    if "\tlay_low_active = true\n" not in startfn:
        raise SystemExit("lay low activation line missing")
    startfn=startfn.replace("\tlay_low_active = true\n","\tlay_low_active = true\n\treeves_quiet_pause_seconds = 0.0\n",1)
    text=text[:sm.start()]+startfn.rstrip()+"\n\n"+text[sm.end():]

    stop_pat=re.compile(r'^func _stop_lay_low_and_reopen\(\) -> void:\n.*?(?=^func |\Z)',re.M|re.S)
    xm=stop_pat.search(text)
    if not xm:
        raise SystemExit("stop lay low function missing")
    stopfn=xm.group(0)
    if "\tlay_low_active = false\n" not in stopfn:
        raise SystemExit("lay low stop line missing")
    stopfn=stopfn.replace("\tlay_low_active = false\n","\tlay_low_active = false\n\treeves_quiet_pause_seconds = 0.0\n",1)
    text=text[:xm.start()]+stopfn.rstrip()+"\n\n"+text[xm.end():]

    # Save/load the partial paused quiet-day fraction.
    save_key='\t\t"reeves_quiet_days": reeves_quiet_days,\n'
    if save_key not in text:
        raise SystemExit("save reeves_quiet_days key missing")
    text=text.replace(save_key,save_key+'\t\t"reeves_quiet_pause_seconds": reeves_quiet_pause_seconds,\n',1)
    load_line='\treeves_quiet_days = maxi(0, int(data.get("reeves_quiet_days", reeves_quiet_days)))\n'
    if load_line not in text:
        raise SystemExit("load reeves_quiet_days line missing")
    text=text.replace(load_line,load_line+'\treeves_quiet_pause_seconds = maxf(0.0, float(data.get("reeves_quiet_pause_seconds", 0.0)))\n',1)

    # Tell the player what continues while paused.
    pause_line='\t\tpause_message.text = "%s\\n\\n%s\\n%s\\nDay %d  |  %s" % [reason, crop_copy, _offline_plant_summary(), game_day, _format_game_clock()]\n'
    if pause_line not in text:
        raise SystemExit("pause message line missing")
    text=text.replace(pause_line,'\t\tpause_message.text = "%s\\n\\n%s\\nHeat cools while paused: 100 to 0 in 72 real minutes.\\n%s\\nDay %d  |  %s" % [reason, crop_copy, _offline_plant_summary(), game_day, _format_game_clock()]\n',1)

    # Finish removing visible meta/dev wording in the Heat screen.
    text=text.replace(
        'intro.text = "Heat is an abstract game-pressure meter. Fast sales, dealers, customer traffic and complaints raise it. At higher Heat, Agent Reeves and enforcement-risk events become part of the story. Quiet time still lowers Heat."',
        'intro.text = "Heat measures how much attention your operation is drawing. Fast sales, dealers, customer traffic and complaints raise it. Quiet time lowers it."',
        1
    )
    text=text.replace('contact_title.text = "FICTIONAL CONTACT  |  REEVES"','contact_title.text = "CONTACT  |  REEVES"',1)
    text=text.replace(
        'contact_copy.text = "Before or between formal arrangements, Reeves can sometimes reduce story pressure for a one-off favor. The recurring arrangement begins through an in-person visit."',
        'contact_copy.text = "Before or between formal arrangements, Reeves can sometimes reduce attention for a one-off favor. The recurring arrangement begins through an in-person visit."',
        1
    )

    # Verification.
    checks=[
        "func _apply_paused_heat_and_quiet_time(",
        "100.0 / (72.0 * 60.0)",
        "24.0 * 60.0",
        '_apply_paused_heat_and_quiet_time(maxf(0.0, now - stamp))',
        '_apply_paused_heat_and_quiet_time(maxf(0.0, paused_now - away_started_unix))',
        '"reeves_quiet_pause_seconds": reeves_quiet_pause_seconds',
        '"Heat cools while paused: 100 to 0 in 72 real minutes."',
    ]
    for needle in checks:
        if needle not in text:
            raise SystemExit("paused Heat verification failed: "+needle)
    if "FICTIONAL CONTACT" in text or "abstract game-pressure meter" in text or "story pressure for a one-off favor" in text:
        raise SystemExit("Heat dev wording still present")
    if "CLOUD TEST" in text:
        raise SystemExit("visible CLOUD TEST wording returned")

    row[1]=text.encode()

packed=rebuild(blob,fb,entries)
TARGET.write_bytes(packed)

idx=Path("index.html")
html=idx.read_text()
html=re.sub(r'const AFB_TEST_RELEASE = "[^"]+";',f'const AFB_TEST_RELEASE = "{RELEASE}";',html,count=1)
html=re.sub(r'"fileSizes":\{[^}]*\}',f'"fileSizes":{{"{PACK_URL}":{len(packed)},"index.wasm":37902138}}',html,count=1)
html=re.sub(r'"mainPack":"[^"]+"',f'"mainPack":"{PACK_URL}"',html,count=1)
idx.write_text(html)

v=Path("version.json")
meta=json.loads(v.read_text())
meta["release_id"]=RELEASE
meta["storefront_control_location"]="BudShop top"
meta["phone_home"]="BudShop, Task, Settings"
meta["task_page"]="Chapter progress, Rewards"
meta["visible_dev_wording"]="removed"
meta["paused_heat_decay"]="100 Heat over 72 real minutes"
meta["paused_lay_low_progress"]="1 Reeves quiet day per 24 real minutes while Lay Low is active"
v.write_text(json.dumps(meta,indent=2)+"\n")

print("Built",RELEASE)
print("Paused Heat decays 100 points over 72 real minutes")
print("Lay Low pause time counts toward Reeves quiet days")
