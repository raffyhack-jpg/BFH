"""Convert original clothing definitions, skins, icons and jump clips without replacing art."""
import sys,re,json,io,hashlib,csv
from pathlib import Path
import numpy as np
from PIL import Image
from convert_world import Archive
from bf2.bf2_mesh import BF2Mesh
from bf2.bf2_animation import BF2Animation
import xml.etree.ElementTree as ET

def main():
    base=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
    for folder in ['meshes','textures','icons']: (out/folder).mkdir(exist_ok=True)
    server=Archive(base/'Objects/Items_server.zip');client=Archive(base/'Objects/Items_client.zip');menu=Archive(base/'Menu_client.zip')
    templates={};sources=[];mesh_paths={Path(n).stem:n for n in client.entries if n.endswith('.skinnedmesh')}
    def record(archive,name,data): sources.append({'archive':str(archive.path.relative_to(base)),'entry':name,'sha256':hashlib.sha256(data).hexdigest()})
    def png(archive,name,folder):
        raw=archive.read(name);record(archive,name,raw);im=Image.open(io.BytesIO(raw)).convert('RGBA');file=folder+'/'+hashlib.sha256(raw).hexdigest()[:20]+'.png'
        if not (out/file).exists(): im.save(out/file,compress_level=6)
        return file,list(im.size)
    def value(text,key):
        m=re.search(r'^\s*'+re.escape(key)+r'\s+([^\r\n]+)',text,re.I|re.M);return m[1].strip().strip('"') if m else None
    def mesh(name,kind):
        raw=client.read(mesh_paths[name]);record(client,mesh_paths[name],raw);temp=out/'temp.skinnedmesh';temp.write_bytes(raw);model=BF2Mesh.load(str(temp));temp.unlink()
        candidates=[g.lods[0] for g in model.geoms if g.lods and any(r.bones for r in g.lods[0].rigs)]
        if not candidates:raise ValueError('No weighted render geometry: '+name)
        lod=max(candidates,key=lambda l:sum(len(m.vertices) for m,r in zip(l.materials,l.rigs) if r.bones));parts=[]
        for mat,rig in zip(lod.materials,lod.rigs):
            if not mat.vertices or not mat.faces or not rig.bones:continue
            part={'positions':[],'normals':[],'uv':[],'weights':[],'indices':[],'faces':[],'boneIDs':[b.id for b in rig.bones],'inverseBind':[],'materialType':kind}
            for v in mat.vertices:
                p=v.position;n=v.normal;uv=v.texcoord0;w=max(0,min(1,v.blendweight[0])) if v.blendweight else 1
                part['positions']+= [p[0],p[1],-p[2]];part['normals'] += [n[0],n[1],-n[2]];part['uv'] += [uv[0],1-uv[1]]
                weights=[w,1-w];indices=list(v.blendindices[:2]) if v.blendindices else [0,0]
                for i in range(2):
                    if weights[i]<0.000001:indices[i]=0
                part['weights'] += weights;part['indices'] += indices
            for f in mat.faces:part['faces'] += [f[0],f[2],f[1]]
            for b in rig.bones:
                # BFH stores Direct3D row-vector inverse bind matrices. The same
                # flat row ordering becomes SceneKit's column-vector transpose.
                m=np.array(b.matrix.m);s=np.diag([1,1,-1,1]);part['inverseBind'].append((s@m@s).flatten().tolist())
            assert all(0<=b<74 for b in part['boneIDs']),name
            assert max(part['indices'])<len(part['boneIDs']),str((name,max(part['indices']),part['boneIDs']))
            parts.append(part)
        assert parts,name
        file='meshes/'+name+'.json';(out/file).write_text(json.dumps(parts,separators=(',',':')));return file
    for name in server.entries:
        if not name.endswith('.con'):continue
        text=server.read(name).decode('latin1');create=value(text,'GeometryTemplate.create');kind=value(text,'geometryTemplate.itemType')
        if not create or not kind:continue
        bits=create.split();key=Path(name).stem.lower();kind=kind.lower()
        if bits[0].lower()=='soldiermeshitem' and key in mesh_paths:
            try:converted=mesh(key,kind)
            except ValueError as error:
                print('Unusable original clothing geometry',key,str(error));continue
            templates[key]={'kind':'mesh','materialType':kind,'mesh':converted,'texture':None,'coordinate':[0,0],'size':[0,0]}
        elif bits[0].lower()=='soldiertextureitem':
            file=value(text,'geometryTemplate.fileName');coord=value(text,'geometryTemplate.setCoordinate') or '0/0'
            if not file:continue
            file=file.lower().replace('\\','/').replace('objects/items/','')
            if file not in client.entries:continue
            image,size=png(client,file,'textures');match=re.search(r'(-?\d+)\s*/\s*(-?\d+)',coord);coordinate=[int(match[1]),int(match[2])] if match else [0,0];templates[key]={'kind':'texture','materialType':kind,'mesh':None,'texture':image,'coordinate':coordinate,'size':size}
    print('Converted original clothing templates:',len(templates),flush=True)
    localization={};local=base/'Localization/strings.csv'
    if local.exists():
        data=local.read_bytes();text=data.decode('utf16' if data[:2] in [b'\xff\xfe',b'\xfe\xff'] else 'utf-8-sig',errors='replace');rows=list(csv.reader(io.StringIO(text),delimiter='\t'))
        print('Loaded original localization rows:',len(rows))
        english=next((i for i,h in enumerate(rows[0]) if h.lower() in ['english','en','en_us','en-us','eng_us']),1)
        for row in rows[1:]:
            if len(row)>english:localization[row[0].strip().lower()]=row[english].strip()
    icon_paths={Path(n).stem.lower():n for n in menu.entries if '/images/items/' in n and n.endswith(('.dds','.png','.tga'))}
    def title(id,fallback):return localization.get('west_custom_item_'+str(id),fallback)
    def icon(id):
        path=icon_paths.get('item'+str(id)) or icon_paths.get(str(id))
        return png(menu,path,'icons')[0] if path else None
    def commerce(item):
        # Preserve explicit source fields only; backend prices were not bundled in every client.
        def integer(*keys):
            for key in keys:
                raw=item.get(key) or item.findtext(key)
                if raw and raw.strip().isdigit():return int(raw)
            return None
        return {'minimumLevel':integer('minimumLevel','minLevel','requiredLevel','level'),
                'valorPrice':integer('valorPrice','vpPrice'),
                'fundsPrice':integer('fundsPrice','bfPrice')}
    items=[];unresolved=[]
    for item in ET.fromstring(server.read('items.xml')).findall('.//item'):
        id=int(item.get('id'));refs=[];missing=[]
        for t in item.findall('template'):
            key=(t.text or '').strip().lower()
            if key in templates:refs.append({'name':key,'layer':int(t.get('layer','0'))})
            elif key:missing.append(key)
        if missing:unresolved.append({'id':id,'templates':missing})
        if refs and not missing:items.append({'id':id,'name':title(id,item.findtext('displayName') or str(id)),'faction':int(item.findtext('faction','0')),'kits':int(item.findtext('kits','7')),'slot':int(item.findtext('slot','0')),'templates':refs,'icon':icon(id),**commerce(item)})
    defaults={}
    for team in ET.fromstring(server.read('defaultcustomization.xml')).findall('.//team'):
        # Engine team 2=Royal, team 1=National; item faction 1=Royal,2=National.
        faction=1 if team.get('id')=='2' else 2
        for kit in team.findall('kit'):
            if int(kit.get('id'))>2:continue
            defaults[str(faction)+'-'+kit.get('id')]={'appearance':[int(x) for x in kit.findtext('appearance','').split(';') if x],'equipment':[int(x) for x in kit.findtext('equipment','').split(';') if x]}
    colors=[]
    for group in ET.fromstring(server.read('colors.xml')):
        for color in group.findall('c'):
            colors.append({'id':int(color.get('id')),'name':group.tag+' '+color.get('id'),'kind':group.tag,'rgb':[int(v) for v in color.text.split()]})
    # Preserve the weapon database separately from gameplay ratings.
    world=json.loads(Path("Assets/OriginalWorld/world.json").read_text());weapons=[];ws=Archive(base/'Objects/Weapons_server.zip');weapondefs={}
    for name in ws.entries:
        if not name.endswith('.con'):continue
        text=ws.read(name).decode('latin1');aid=value(text,'ObjectTemplate.assetId');geometry=value(text,'ObjectTemplate.geometry')
        if not aid or not aid.isdigit() or not geometry:continue
        animation=value(text,'ObjectTemplate.AnimationSystem3p') or '';match=re.search(r'animations[/\\]([^/\\]+)',animation,re.I);pose=match[1].lower() if match else 'smg'
        weapondefs[int(aid)]={'weaponType':value(text,'ObjectTemplate.weaponsItemType'),'pose':pose,'model':geometry.lower(),'rpm':float(value(text,'ObjectTemplate.fire.roundsPerMinute') or 300),'magazine':int(value(text,'ObjectTemplate.ammo.magSize') or 30),'reload':float(value(text,'ObjectTemplate.ammo.reloadTime') or 2)}
    for item in ET.fromstring(server.read('weapons.xml')).findall('.//item'):
        id=int(item.get('id'));d=weapondefs.get(id)
        if not d or d["model"] not in world["meshAssets"]:continue
        weapons.append({'id':id,'name':title(id,item.findtext('displayName') or str(id)),'faction':int(item.findtext('faction','0')),'kits':int(item.findtext('kits','7')),'weaponClass':int(item.findtext('class','0')),'icon':icon(id),**d,**commerce(item)})
    catalog={'items':items,'templates':templates,'defaults':defaults,'colors':colors,'weapons':weapons}
    (out/'catalog.json').write_text(json.dumps(catalog,separators=(',',':')))
    soldiers=Archive(base/'Objects/Soldiers_server.zip')
    def clip(source):
        raw=soldiers.read(source);record(soldiers,source,raw);temp=out/'temp.baf';temp.write_bytes(raw);anim=BF2Animation(str(temp));temp.unlink()
        tracks={str(bone):[[f.pos.x,f.pos.y,-f.pos.z,-f.rot.x,-f.rot.y,f.rot.z,f.rot.w] for f in frames] for bone,frames in anim.bones.items()}
        return {'frames':anim.frame_num,'fps':30,'tracks':tracks}
    for faction,prefix in [('royal','british_male_soldier'),('national','german_male_soldier')]:
        path=Path('Assets/Characters')/(faction+'-rig.json');rig=json.loads(path.read_text())
        for key,filename in [('jumpStart','stilljumpstart.baf'),('jumpLoop','stilljumploop.baf'),('jumpEnd','stilljumpend.baf')]:
            source=prefix+'/animations/common/'+filename
            if source not in soldiers.entries:continue
            rig['clips'][key]=clip(source)
        groups=sorted(set(w['pose'] for w in weapons));aliases={};seen={}
        for group in groups:
            names=[n for n in soldiers.entries if n.startswith(prefix+'/animations/'+group+'/') and n.endswith('.baf')]
            inc=prefix+'/animations/'+group+'/animationsystem3p.inc'
            if inc in soldiers.entries:
                text=soldiers.read(inc).decode('latin1')
                for reference in re.findall(r'animationSystem.createAnimation\s+(\S+\.baf)',text,re.I):
                    reference=reference.lower().replace('\\','/').removeprefix('objects/soldiers/')
                    if reference in soldiers.entries and '/common/' not in reference:names.append(reference)
            for logical,suffixes in [('Idle',['_idle1.baf','_idle.baf','_stand.baf']),('Run',['_runforward.baf']),('Fire',['_standfire.baf','_fire.baf']),('Reload',['_standreload.baf','_reload.baf'])]:
                source=next((n for suffix in suffixes for n in names if n.endswith(suffix)),None)
                if source:
                    if source not in seen:
                        name='original-'+hashlib.sha256(source.encode()).hexdigest()[:16];seen[source]=name;rig['clips'][name]=clip(source)
                    aliases[group+logical]=seen[source]
        rig['clipAliases']=aliases
        path.write_text(json.dumps(rig,separators=(',',':')))
    (out/'provenance.json').write_text(json.dumps({'client':'Battlefield Heroes 1.105','sources':sources,'unresolved':unresolved},indent=2))
    print('Original wardrobe converted:',len(items),'items,',len(templates),'templates,',len(weapons),'weapons. Unresolved clothing:',len(unresolved))
if __name__=='__main__':main()
