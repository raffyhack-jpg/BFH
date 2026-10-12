import json,struct,sys
from pathlib import Path
from PIL import Image
root=Path(sys.argv[1]);world=json.loads((root/'world.json').read_text())
assert len(world['instances'])>500
assert len(world['weapons'])==6
assert any(i['mesh']=='townhousesmall_e_01' for i in world['instances']), 'Original village buildings missing'
assert any(i['mesh']=='townhousemedium_e_02' for i in world['instances']), 'Original village buildings missing'
assert (root/world['heightFile']).stat().st_size==257*257*4
for name,mesh in world['meshAssets'].items():
    data=(root/mesh['file']).read_bytes()
    for part in mesh['parts']:
        assert part['vertexOffset']+part['vertexCount']*32<=len(data)
        assert part['indexOffset']+part['indexCount']*4<=len(data)
        indices=struct.unpack_from('<'+'I'*part['indexCount'],data,part['indexOffset'])
        assert max(indices)<part['vertexCount']
        if part['texture']: Image.open(root/part['texture']).verify()
print('Original village geometry, terrain, materials and all six weapons verified')
