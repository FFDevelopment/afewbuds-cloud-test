"""Admit approved character appearances without altering contact/save identities."""
from pathlib import Path
NAMES = ('Rod','Kobi','Malik','Diddy','Jeremias','Marcuss','Tyler','Mahto','Mike')
def patch_crew(source):
    assert 'const FriendCharacters' not in source
    source=source.replace('extends RefCounted','extends RefCounted\nconst FriendCharacters = preload("res://scripts/friend_characters.gd")',1)
    source=source.replace('name not in ["Malik","Rod","Kobi"]','not FriendCharacters.has_character(name)').replace('name in ["Malik","Rod","Kobi"]','FriendCharacters.has_character(name)').replace('visitor in ["Malik","Rod","Kobi"]','FriendCharacters.has_character(visitor)')
    begin=source.index('\t\tvar texture_image:=Image.new()',source.index('func character_instance'))
    end=source.index('\t\tscene=PackedScene.new()',begin)
    return source[:begin]+'\t\t# Embedded materials preserve each approved friend outfit and face.\n'+source[end:]
def apply_entries(entries,root):
    payload={f'assets/characters/{name}.glb':(root/'assets/characters/friends'/f'{name}.glb').read_bytes() for name in NAMES}
    payload['scripts/friend_characters.gd']=(Path(__file__).parent/'friend_characters.gd').read_bytes()
    seen=set();result=[]
    for name,data,flags in entries:
        result.append([name,payload.get(name,data),flags]);seen.add(name)
    result.extend([name,data,0] for name,data in payload.items() if name not in seen)
    return result
