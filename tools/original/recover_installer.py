"""Extract the stored installer entries from the SHA-1 verified RAR4 source."""
import hashlib, shutil, struct, sys
from pathlib import Path
source=Path(sys.argv[1]); out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=True)
h=hashlib.sha1()
with source.open('rb') as stream:
    for data in iter(lambda:stream.read(4*1024*1024),b''): h.update(data)
assert h.hexdigest()=='7b77439053f6e79ebf5a9020b22aff85e49195e6','Original archive hash mismatch'
found=set()
with source.open('rb') as stream:
    assert stream.read(7)==b'Rar!\x1a\x07\x00'
    while True:
        header=stream.read(7)
        if len(header)<7:break
        _,kind,flags,size=struct.unpack('<HBHH',header);extra=stream.read(size-7)
        packed=struct.unpack_from('<I',extra)[0] if flags&0x8000 else 0
        if kind==0x74:
            packed,unpacked,_,_,_,_,method,nl,_=struct.unpack_from('<IIBIIBBHI',extra)
            name=extra[25:25+nl].decode().replace('\\','/').split('/')[-1]
            if name in ['setup.exe','setup-1.bin']:
                assert method==0x30 and packed==unpacked,'Installer entries must be stored'
                with (out/name).open('wb') as dest:
                    remaining=packed
                    while remaining:
                        data=stream.read(min(4*1024*1024,remaining));assert data
                        dest.write(data);remaining-=len(data)
                found.add(name);continue
        stream.seek(packed,1)
assert found=={'setup.exe','setup-1.bin'}
print('Verified source archive and recovered installer')
