"""Fetch verified preserved client with bounded parallel HTTP range requests."""
import concurrent.futures,hashlib,os,sys,urllib.request
from pathlib import Path
target=Path(sys.argv[1]);partial=target.with_suffix('.partial');target.parent.mkdir(parents=True,exist_ok=True)
size=1203733068;chunk=8*1024*1024
url='https://archive.org/download/battlefield-heroes-setup/Battlefield%20Heroes%20Setup.rar'
fd=os.open(partial,os.O_CREAT|os.O_RDWR|os.O_TRUNC,0o600);os.ftruncate(fd,size)
def fetch(start):
    end=min(size,start+chunk)-1
    for attempt in range(3):
        try:
            request=urllib.request.Request(url,headers={'Range':f'bytes={start}-{end}'})
            with urllib.request.urlopen(request,timeout=90) as response:
                if response.status!=206: raise ValueError('Range request was not honored')
                data=response.read(end-start+2)
            if len(data)!=end-start+1: raise ValueError('Wrong range length')
            written=0
            while written<len(data): written+=os.pwrite(fd,data[written:],start+written)
            return len(data)
        except Exception:
            if attempt==2: raise
try:
    completed=0
    with concurrent.futures.ThreadPoolExecutor(max_workers=16) as pool:
        for future in concurrent.futures.as_completed([pool.submit(fetch,start) for start in range(0,size,chunk)]):
            previous=completed;completed+=future.result()
            if completed//(64*1024*1024)!=previous//(64*1024*1024): print(f'Downloaded {completed//(1024*1024)} / {size//(1024*1024)} MiB',flush=True)
finally: os.close(fd)
h=hashlib.sha1()
with partial.open('rb') as stream:
    for data in iter(lambda:stream.read(4*1024*1024),b''): h.update(data)
assert h.hexdigest()=='7b77439053f6e79ebf5a9020b22aff85e49195e6','Source checksum mismatch'
partial.replace(target)
print('Original client download verified',flush=True)
