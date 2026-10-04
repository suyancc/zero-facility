"""Install only matching official Web templates using HTTPS byte ranges.
No engine upgrade, no pip dependencies, no overwrite of existing template files.
"""
import io, os, pathlib, urllib.request, zipfile, hashlib
print('Installer started', flush=True)
VERSION = '4.7.2.stable'
URL = 'https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz'
class RemoteZip(io.RawIOBase):
    def __init__(self):
        print('Reading archive metadata', flush=True)
        r = urllib.request.urlopen(urllib.request.Request(URL, method='HEAD'), timeout=20)
        self.size = int(r.headers['Content-Length']); r.close(); self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else (self.pos if whence == 1 else self.size) + offset
        return self.pos
    def read(self, n=-1):
        n = min(self.size-self.pos, n if n >= 0 else self.size-self.pos)
        if n <= 0: return b''
        start=self.pos
        print(f'Range {start} +{n}', flush=True)
        request=urllib.request.Request(URL, headers={'Range':f'bytes={start}-{start+n-1}'})
        with urllib.request.urlopen(request,timeout=40) as r:
            if r.status!=206: raise RuntimeError('Server did not honor Range; refusing full 1.28 GB download')
            if not r.headers.get('Content-Range','').startswith(f'bytes {start}-'):
                raise RuntimeError('Unexpected Content-Range')
            data=r.read(n)
        if len(data)!=n: raise RuntimeError('Incomplete download')
        self.pos += len(data)
        return data
with zipfile.ZipFile(RemoteZip()) as z:
    version=z.read('templates/version.txt').decode().strip()
    if version!=VERSION: raise RuntimeError(f'Unexpected template version: {version}')
    destination=pathlib.Path(os.environ['APPDATA'])/'Godot'/'export_templates'/VERSION
    destination.mkdir(parents=True,exist_ok=True)
    for name in ['web_nothreads_release.zip','web_nothreads_debug.zip','version.txt']:
        target=destination/name
        if target.exists():
            print('EXISTS',name,flush=True);continue
        print('Downloading',name,flush=True)
        data=z.read('templates/'+name) # ZipFile validates member CRC.
        with target.open('xb') as f: f.write(data)
        print('INSTALLED',name,len(data),'sha256='+hashlib.sha256(data).hexdigest(),flush=True)
print('Matching single-thread Web templates installed.',flush=True)
