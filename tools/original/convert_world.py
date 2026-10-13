"""Convert original BFH 1.105 scenery into native iPhone geometry.

No invented replacement art. ZIP local entries are CRC checked because two
archives in the preserved installer end before their central directories.
"""
import argparse, hashlib, io, json, math, re, struct, sys, zlib, zipfile
from pathlib import Path
import numpy as np
from PIL import Image
from bf2.bf2_mesh import BF2Mesh

class Archive:
    def __init__(self, path):
        self.path=Path(path); self.entries={}; self.data=self.path.read_bytes()
        p=0
        while self.data[p:p+4]==b'PK\x03\x04':
            h=struct.unpack_from('<IHHHHHIIIHH',self.data,p)
            crc,cs,us,nl,el=h[6:]; name=self.data[p+30:p+30+nl].decode('utf8')
            start=p+30+nl+el
            if start+cs>len(self.data): break
            if h[2]&8: raise ValueError('Streaming ZIP entry unsupported')
            self.entries[name.lower()]=(name,start,cs,us,crc,h[3]); p=start+cs
    def read(self,name):
        _,start,cs,us,crc,method=self.entries[name.replace('\\','/').lower()]
        d=self.data[start:start+cs]
        if method==8: d=zlib.decompress(d,-15)
        elif method!=0: raise ValueError('Unsupported ZIP compression')
        assert len(d)==us and zlib.crc32(d)&0xffffffff==crc, name
        return d

def placements(text):
    result=[]; item=None
    for line in text.splitlines():
        bits=line.strip().split()
        if not bits: continue
        if bits[0].lower()=='object.create':
            item={'name':bits[1].lower(),'rotation':[0,0,0]}; result.append(item)
        elif item is not None and bits[0].lower() in ['object.absoluteposition','object.rotation']:
            item['position' if bits[0].lower().endswith('position') else 'rotation']=[float(v) for v in bits[1].split('/')]
    return [x for x in result if 'position' in x]

def main():
    ap=argparse.ArgumentParser(); ap.add_argument('client'); ap.add_argument('output'); args=ap.parse_args()
    base=Path(args.client); out=Path(args.output); out.mkdir(parents=True,exist_ok=True)
    (out/'textures').mkdir(exist_ok=True); (out/'meshes').mkdir(exist_ok=True)
    archives={name:Archive(base/f'Objects/{name}_client.zip') for name in ['StaticObjects','Vegitation','Weapons','Vehicles','Common','Items']}
    gamecommon=Archive(base/'Common_client.zip')
    menu=Archive(base/'Menu_client.zip')
    server=Archive(base/'Objects/StaticObjects_server.zip')
    level=Archive(base/'Levels/heat/server.zip'); levelclient=Archive(base/'Levels/heat/client.zip')
    sources=[]; textures={}; meshes={}; failures=[]
    def record(archive,name,data):
        sources.append({'archive':str(archive.path.relative_to(base)),'entry':name,'sha256':hashlib.sha256(data).hexdigest()})
    def texture(archive,name):
        name=name.replace('\\','/').lower().lstrip('/')
        # Original references have a game-root prefix; archive paths do not.
        relative=name
        if name.startswith('objects/'):
            _,category,relative=name.split('/',2)
            archive=next(a for key,a in archives.items() if key.lower()==category)
        elif name.startswith('common/'): archive=gamecommon;relative=name[len('common/'):]
        key=(str(archive.path),relative)
        if key in textures: return textures[key]
        data=archive.read(relative); record(archive,relative,data)
        image=Image.open(io.BytesIO(data)).convert('RGBA')
        # Color-map alpha is often gloss, not transparency.
        if archive is not archives['Vegitation']: image.putalpha(255)
        file='textures/'+hashlib.sha256(data).hexdigest()[:16]+'.png'; image.save(out/file,optimize=True)
        textures[key]=file; return file
    def export_mesh(archive,name,identifier,geom=0):
        if identifier in meshes: return identifier
        data=archive.read(name); record(archive,name,data)
        temp=out/('temp'+Path(name).suffix);temp.write_bytes(data)
        model=BF2Mesh.load(str(temp)); temp.unlink()
        lod=model.geoms[min(geom,len(model.geoms)-1)].lods[0]
        blob=bytearray(); parts=[]; allpos=[]
        for mat in lod.materials:
            if not mat.faces or not mat.vertices: continue
            tex=texture(archive,mat.maps[0]) if mat.maps else None
            packed=[]
            for v in mat.vertices:
                p=v.position; n=v.normal or (0,1,0); uv=v.texcoord0 or (0,0)
                packed.extend([p[0],p[1],-p[2],n[0],n[1],-n[2],uv[0],1-uv[1]])
                allpos.append([p[0],p[1],-p[2]])
            vo=len(blob); blob.extend(struct.pack('<'+'f'*len(packed),*packed))
            indices=[i for f in mat.faces for i in [f[0],f[2],f[1]]]
            io_=len(blob); blob.extend(struct.pack('<'+'I'*len(indices),*indices))
            parts.append({'vertexOffset':vo,'vertexCount':len(mat.vertices),'indexOffset':io_,'indexCount':len(indices),'texture':tex,'alpha':'alpha' in mat.technique.lower() or archive is archives['Vegitation']})
        if not parts: raise ValueError('Empty original model '+name)
        file='meshes/'+identifier+'.bin'; (out/file).write_bytes(blob)
        points=np.array(allpos); lower=points[points[:,1]<points[:,1].min()+2]
        meshes[identifier]={'file':file,'parts':parts,'min':points.min(axis=0).tolist(),'max':points.max(axis=0).tolist(),'footMin':lower.min(axis=0).tolist(),'footMax':lower.max(axis=0).tolist()}
        return identifier
    geometry={}
    for name in server.entries:
        if name.endswith('.con'):
            text=server.read(name).decode('latin1')
            match=re.search(r'ObjectTemplate\.geometry\s+(\S+)',text,re.I)
            if match: geometry[Path(name).stem]=match[1].lower()
    instances=[]; collision=[]
    for item in placements(level.read('StaticObjects.con').decode('latin1')):
        name=geometry.get(item['name'],item['name'])
        found=None
        for an in ['StaticObjects','Vegitation']:
            archive=archives[an]
            found=next((k for k in archive.entries if Path(k).stem==name and k.endswith(('.staticmesh','.bundledmesh'))),None)
            if found: break
        if not found:
            failures.append(item['name']);continue
        try: export_mesh(archive,found,name)
        except (KeyError,ValueError) as e: failures.append(str(e));continue
        p=item['position']; r=item['rotation']; yaw=-math.radians(r[0])
        instances.append({'mesh':name,'position':[p[0],p[1],-p[2]],'rotation':[math.radians(r[1]),yaw,-math.radians(r[2])]})
        # Rotated footprint for path finding; decorative elevated lights are not walls.
        bounds=meshes[name]; mn=np.array(bounds['min']); mx=np.array(bounds['max'])
        if name.startswith('mt_'): mn=np.array(bounds['footMin']);mx=np.array(bounds['footMax'])
        if mx[1]-mn[1]>0.7 and not any(s in name for s in ['light','bridge','window','backdrop','chimney']):
            center=(mn+mx)/2; half=(mx-mn)/2
            c,s=math.cos(yaw),math.sin(yaw)
            collision.append({'center':[p[0]+center[0]*c+center[2]*s,-p[2]-center[0]*s+center[2]*c], 'half':[half[0],half[2]],'angle':yaw})
    weapons={}
    for faction,names in [('royal',['bri_smg_sten','bri_mg_lewis','bri_sniperrifle_leeenfield']),('national',['ger_smg_mp40','ger_mg_mg40','ger_sniperrifle_gewehr43'])]:
        for kind,name in zip(['soldier','heavy','scout'],names):
            archive=archives['Weapons']; path=next(k for k in archive.entries if Path(k).stem==name and k.endswith('.bundledmesh'))
            weapons[faction+'-'+kind]=export_mesh(archive,path,name,geom=1)
    flags={}
    for key,name in [('pole','flagpole'),('royal','flag_ra'),('national','flag_na'),('neutral','flag_neutral'),('ctf-royal','ctf_stationaryroyal'),('ctf-national','ctf_stationarynational')]:
        archive=archives['Common'];path=next(k for k in archive.entries if Path(k).stem==name and k.endswith(('.bundledmesh','.staticmesh','.skinnedmesh')))
        flags[key]=export_mesh(archive,path,name)
    sky=export_mesh(gamecommon,'sky/skydome/meshes/skydomevillage.staticmesh','original-sky')
    skytexture=texture(gamecommon,'common/textures/sky/sky_heat.dds')
    for part in meshes[sky]['parts']: part['texture']=skytexture
    ui=out.parent/'UI';ui.mkdir(exist_ok=True)
    for source,destination in [('External/FlashMenu/images/background/logo.png','logo.png'),('External/FlashMenu/images/background/bg_menu.png','menu.png')]:
        data=menu.read(source);record(menu,source,data);(ui/destination).write_bytes(data)
    # Original terrain grid, 2 metres per sample. Reflect Z consistently with the meshes.
    heights=np.frombuffer(level.read('HeightmapPrimary.raw'),dtype='<u2').reshape(257,257).astype(float)*.0025
    heights=np.flipud(heights).copy(); (out/'height.bin').write_bytes(heights.astype('<f4').tobytes())
    # Preserve original low-detail terrain color tiles, rather than painting generic grass.
    mosaic=Image.new('RGBA',(1024,1024))
    for x in range(2):
        for z in range(2):
            raw=levelclient.read(f'Colormaps/tx{x:02d}x{z:02d}.dds'); record(levelclient,f'Colormaps/tx{x:02d}x{z:02d}.dds',raw)
            tile=Image.open(io.BytesIO(raw)).convert('RGBA').resize((512,512));tile.putalpha(255)
            mosaic.paste(tile,(x*512,z*512))
    mosaic.save(out/'terrain.png',optimize=True)
    minimap=Image.open(io.BytesIO(levelclient.read('Hud/Minimap/ingameMap.dds'))).convert('RGBA');minimap.save(out/'minimap.png')
    vertices=[];indices=[]
    for z in range(257):
        for x in range(257):
            dx=heights[z,min(256,x+1)]-heights[z,max(0,x-1)];dz=heights[min(256,z+1),x]-heights[max(0,z-1),x]
            n=np.array([-dx,4,-dz]);n=n/np.linalg.norm(n)
            vertices.extend([x*2-256,heights[z,x],z*2-256,*n,x/256,z/256])
    for z in range(256):
        for x in range(256):
            a=z*257+x;indices.extend([a,a+257,a+1,a+1,a+257,a+258])
    vo=struct.pack('<'+'f'*len(vertices),*vertices);io_=struct.pack('<'+'I'*len(indices),*indices)
    (out/'meshes/terrain.bin').write_bytes(vo+io_)
    meshes['terrain']={'file':'meshes/terrain.bin','parts':[{'vertexOffset':0,'vertexCount':66049,'indexOffset':len(vo),'indexCount':len(indices),'texture':'terrain.png','alpha':False}],'min':[-256,float(heights.min()),-256],'max':[256,float(heights.max()),256]}
    gameplay=level.read('GameModes/gpm_tdm/16/GamePlayObjects.con');record(level,'GameModes/gpm_tdm/16/GamePlayObjects.con',gameplay)
    controlpoints={p['name']:p['position'] for p in placements(gameplay.decode('latin1'))}
    objectives=[[controlpoints[n][0],-controlpoints[n][2]] for n in ['market','boulevard','toll_house','square']]
    world={'name':'Original BFH heat map','meshAssets':meshes,'instances':instances,'weapons':weapons,'flags':flags,'sky':sky,'blocks':collision,'bases':[[78.722,105.957],[-72.195,-73.048]],'objectives':objectives,'size':257,'spacing':2,'origin':-256,'waterHeight':19,'heightFile':'height.bin'}
    (out/'world.json').write_text(json.dumps(world,separators=(',',':')))
    (out/'provenance.json').write_text(json.dumps({'source':'https://archive.org/details/battlefield-heroes-setup','archiveSHA1':'7b77439053f6e79ebf5a9020b22aff85e49195e6','clientVersion':'1.105','reader':'https://github.com/marekzajac97/bf2-blender','convertedSources':sources,'unresolvedObjects':sorted(set(failures))},indent=2))
    print(f'Converted {len(instances)} original placements, {len(meshes)} meshes, {len(textures)} textures and {len(weapons)} weapons; unresolved: {sorted(set(failures))}')
    assert len(instances)>150 and len(weapons)==6

if __name__=='__main__': main()
