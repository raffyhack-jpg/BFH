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
for name in ['defaultcustomization.xml','colors.xml','weapongear.xml']:
    print('CUSTOMIZATION DEFAULTS',name,items.read(name).decode('utf8',errors='replace')[:6000])
from bf2.bf2_mesh import BF2Mesh
from PIL import Image
import io,numpy as np
for stem in ['bri_m_head001','bri_m_body001','bri_m_legs001','bri_m_feet001','ger_m_head001']:
    name=next(n for n in client.entries if n.endswith('/'+stem+'.skinnedmesh'))
    path=Path('build')/(stem+'.skinnedmesh');path.write_bytes(client.read(name));mesh=BF2Mesh.load(str(path))
    for g in mesh.geoms[:1]:
        for mat,rig in zip(g.lods[0].materials,g.lods[0].rigs):
            uv=np.array([v.texcoord0 for v in mat.vertices]);print('ITEM MESH FORMAT',stem,len(mat.vertices),mat.maps,'UV',uv.min(0).tolist(),uv.max(0).tolist(),'bones',[b.id for b in rig.bones][:15])
for name in ['british/bri_m_head001_head001/bri_m_head001_head001.tga','british/bri_m_body001_shirt001/bri_m_body001_shirt001.tga']:
    image=Image.open(io.BytesIO(client.read(name)));print('ITEM TEXTURE FORMAT',name,image.size,image.mode)
import xml.etree.ElementTree as ET,math,subprocess
root=ET.fromstring(items.read('items.xml'))
for item in root.findall('.//item'):
    if int(item.get('id')) in [4,936,935,29,10,980,978,56,36,444]: print('DEFAULT ITEM RECORD',ET.tostring(item,encoding='unicode'))
extents={}
for name in items.entries:
    if not name.endswith('.con'):continue
    text=items.read(name).decode('latin1')
    if 'SoldierTextureItem' not in text:continue
    kind=re.search(r'geometryTemplate.itemType\s+(\S+)',text,re.I)
    file=re.search(r'geometryTemplate.fileName\s+(\S+)',text,re.I)
    coord=re.search(r'geometryTemplate.setCoordinate\s+(\d+)/(\d+)',text,re.I)
    if not kind or not file:continue
    path=file[1].lower().replace('objects/items/','').strip('"');x,y=(int(coord[1]),int(coord[2])) if coord else (0,0)
    try:
        image=Image.open(io.BytesIO(client.read(path)));size=extents.setdefault(kind[1],[0,0]);size[0]=max(size[0],x+image.width);size[1]=max(size[1],y+image.height)
    except KeyError:pass
print('ORIGINAL MATERIAL CANVAS EXTENTS',extents)
for name in ['british_male_soldier/british_male_soldier.con','british_male_soldier/british_male_soldier.tweak']:
    print('SOLDIER MATERIAL CONFIG',name,'\n'.join(l for l in soldiers.read(name).decode('latin1').splitlines() if any(s in l.lower() for s in ['texture','custom','skin','color','item','material']))[:6000])
weapons=Archive(base/'Objects/Weapons_server.zip')
for name in weapons.entries:
    if not name.endswith(('.con','.tweak')):continue
    text=weapons.read(name).decode('latin1')
    if re.search(r'\b3011\b',text):print('WEAPON MODEL ID MAPPING',name,text[:4500])
listing=subprocess.run(['innoextract','--list','build/original-client/setup.exe'],capture_output=True,text=True).stdout
print('ORIGINAL LOCALIZATION FILES',[l.strip() for l in listing.splitlines() if any(s in l.lower() for s in ['localization','english','.utxt'])][:35])

for name in items.entries:
    if Path(name).stem in ['bri_m_body001_body001','bri_m_body002_jacket014','bri_m_legs002_trousers015','bri_m_feet002_boots001','bri_m_head001_head001'] and name.endswith('.con'):
        text=items.read(name).decode('latin1');print('ATLAS DEFAULT TEMPLATE',name,text)
        match=re.search(r'geometryTemplate.fileName\s+(\S+)',text,re.I)
        if match:
            im=Image.open(io.BytesIO(client.read(match[1].strip(chr(34)).lower().replace('objects/items/',''))));print('ATLAS DEFAULT IMAGE',im.size)
for stem in ['bri_m_body002','bri_m_legs002','bri_m_feet002']:
    name=next(n for n in client.entries if n.endswith('/'+stem+'.skinnedmesh'));path=Path('build')/(stem+'.skinnedmesh');path.write_bytes(client.read(name));mesh=BF2Mesh.load(str(path))
    for mat,rig in zip(mesh.geoms[0].lods[0].materials,mesh.geoms[0].lods[0].rigs): print('ATLAS MESH DETAILS',stem,mat.technique,mat.fxfile,mat.vertices[0].blendweight,mat.vertices[0].blendindices,rig.bones[0].matrix.m)
local=base/'Localization/strings.csv';print('LOCALIZATION SAMPLE',local.read_bytes()[:1800])
print('CUSTOMIZATION INIT CONFIG','\n'.join(l for l in (base/'Init.con').read_text(errors='replace').splitlines() if any(t in l.lower() for t in ['custom','texture','item','soldier','color'])))
shader=Archive(base/'Shaders_client.zip')
print('SHADER FILES',list(shader.entries))
for name in shader.entries:
    if 'soldier' in name or 'skinned' in name:
        text=shader.read(name).decode('latin1');print('CUSTOM SHADER DEFINITIONS',name,'\n'.join(l for l in text.splitlines() if any(t in l.lower() for t in ['texcoord','color','skin','custom','sampler','texture','atlas'])))
