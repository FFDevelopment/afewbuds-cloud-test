"""Apply shared gameplay fixes after the property phone integration.
Context-checked hunks preserve mobile adapters and fail loudly on source drift.
"""
import json,re
from pathlib import Path
PATCHES=json.loads(Path(__file__).with_name('visuals.patch.json').read_text())
def apply(source,name):
    if name=="main.gd":source=source.replace('\t_add_phone_dock_button(dock, "PAUSE", "pause")\n','')
    lines=PATCHES[name]; i=2
    while i<len(lines):
        assert lines[i].startswith('@@'),(name,lines[i]);i+=1
        old=[];new=[]
        while i<len(lines) and not lines[i].startswith('@@'):
            line=lines[i];i+=1
            if line[0] in ' -':old.append(line[1:])
            if line[0] in ' +':new.append(line[1:])
        before=''.join(old);after=''.join(new)
        assert source.count(before)==1, 'Phone visual source drift: '+name+' '+before[:180]
        source=source.replace(before,after,1)
    if name=="main.gd":source=source.replace('\t_add_phone_dock_button(dock, "?", "help")','\t_add_phone_dock_button(dock, "?", "help")\n\t_add_phone_dock_button(dock, "Ⅱ", "pause")')
    return source
