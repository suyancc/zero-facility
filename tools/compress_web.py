"""Precompress generated Web binaries; never modify source assets."""
from pathlib import Path
import gzip
root=Path('exports/web')
raw_total=packed_total=0
for p in sorted(root.iterdir()):
    if p.suffix not in {'.wasm','.pck','.js','.html'}: continue
    data=p.read_bytes()
    compressed=gzip.compress(data,compresslevel=6,mtime=0)
    p.with_suffix(p.suffix+'.gz').write_bytes(compressed)
    raw_total+=len(data);packed_total+=len(compressed)
    print(p.name,len(data),'->',len(compressed),flush=True)
print('COMPRESSED_TOTAL',packed_total,'RAW_TOTAL',raw_total,flush=True)
