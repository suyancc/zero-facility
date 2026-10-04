"""Verify the checked-in Web release. --stage copies a fresh local export.
Pages deploys this verified export; it does not silently rebuild with another Godot.
"""
import hashlib,json,shutil,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
WEB=ROOT/'web'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def source_sha(path):
    data=path.read_bytes()
    if path.suffix.lower() in {'.gd','.tscn','.tres','.svg','.json','.txt','.csv','.md','.cfg','.godot','.gdshader'}:
        data=data.replace(b'\r\n',b'\n')
    return hashlib.sha256(data).hexdigest()
def sources():
    files=[ROOT/'project.godot']
    for name in ('scripts','scenes','assets','resources'):
        folder=ROOT/name
        if folder.exists():files.extend(p for p in folder.rglob('*') if p.is_file() and not p.name.endswith(('.import','.uid')))
    return {p.relative_to(ROOT).as_posix():source_sha(p) for p in sorted(files)}
if '--stage' in sys.argv:
    export=ROOT/'exports/web'
    if not (export/'index.wasm').is_file():raise SystemExit('Build exports/web first.')
    if WEB.exists():shutil.rmtree(WEB)
    shutil.copytree(export,WEB,ignore=shutil.ignore_patterns('*.gz','*.br','*.import','*.uid','parcel.svg'))
    (WEB/'.nojekyll').write_text('',encoding='utf-8')
    (WEB/'.gdignore').write_text('',encoding='utf-8')
    report={'game_version':'0.6.10','engine_version':'4.7.2.stable','source_files':sources(),
            'web_files':{p.relative_to(WEB).as_posix():sha(p) for p in sorted(WEB.rglob('*')) if p.is_file()}}
    (WEB/'release-manifest.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
manifest=json.loads((WEB/'release-manifest.json').read_text(encoding='utf-8'))
if sources()!=manifest['source_files']:raise SystemExit('Runtime sources changed: rebuild the Web export and run python tools/verify_web_release.py --stage.')
for name,expected in manifest['web_files'].items():
    path=WEB/name
    if not path.is_file() or sha(path)!=expected:raise SystemExit('Export mismatch: '+name)
for required in ('index.html','index.js','index.wasm','index.pck'):
    if required not in manifest['web_files']:raise SystemExit('Missing runtime: '+required)
print('Verified source fingerprint and',len(manifest['web_files']),'Web release files.')

