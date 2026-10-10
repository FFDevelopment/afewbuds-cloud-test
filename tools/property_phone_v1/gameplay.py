"""Apply shared gameplay fixes after the property phone integration.
Context-checked hunks preserve mobile adapters and fail loudly on source drift.
"""
import json,re
from pathlib import Path
PATCHES=json.loads(Path(__file__).with_name('gameplay.patch.json').read_text())
def apply(source,name):
    lines=PATCHES[name]; i=2
    while i<len(lines):
        assert lines[i].startswith('@@'),(name,lines[i]);i+=1
        old=[];new=[]
        while i<len(lines) and not lines[i].startswith('@@'):
            line=lines[i];i+=1
            if line[0] in ' -':old.append(line[1:])
            if line[0] in ' +':new.append(line[1:])
        before=''.join(old);after=''.join(new)
        assert source.count(before)==1, 'Gameplay source drift: '+name+' '+before[:180]
        source=source.replace(before,after,1)
    return source
