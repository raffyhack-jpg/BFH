"""Inspect original customization definitions before implementing their schema."""
import sys,re,json
from pathlib import Path
from convert_world import Archive
base=Path(sys.argv[1]);items=Archive(base/'Objects/Items_server.zip')
names=list(items.entries)
print('Original customization XML:',[n for n in names if n.endswith('.xml')][:30])
for name in [n for n in names if n.endswith('.xml') and any(s in n for s in ['items','kitparts','weapons'])][:4]:
    text=items.read(name).decode('utf8',errors='replace')
    print('CUSTOMIZATION SOURCE',name,text[:4500])
samples=[n for n in names if n.endswith('.con') and any(s in n for s in ['bri_m_head001_head001','bri_m_body001_shirt001','ger_m_head001','bri_m_legs001'])]
for name in samples[:8]: print('ORIGINAL ITEM DEFINITION',name,items.read(name).decode('latin1')[:2500])
client=Archive(base/'Objects/Items_client.zip')
print('ORIGINAL CLOTHING SAMPLE FILES',[n for n in client.entries if any(s in n for s in ['bri_m_head001','bri_m_body001','ctf_royalflag'])][:45])
soldiers=Archive(base/'Objects/Soldiers_server.zip')
print('ORIGINAL JUMP CLIPS',[n for n in soldiers.entries if 'jump' in n and n.endswith('.baf')][:30])
