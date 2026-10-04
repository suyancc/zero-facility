"""Generate the original subtle cloth weave; no downloaded texture source."""
from pathlib import Path
from PIL import Image
import random
ROOT=Path(__file__).resolve().parents[1]
rng=random.Random(610)
pixels=[]
for y in range(128):
    for x in range(128):
        value=241+(4 if x%4<2 else -4)+(3 if y%4<2 else -3)+rng.randrange(-3,4)
        value=max(0,min(255,value));pixels.append((value,value,value))
image=Image.new('RGB',(128,128));image.putdata(pixels)
path=ROOT/'assets/materials/workwear-weave.png';path.parent.mkdir(parents=True,exist_ok=True)
image.save(path)
print(path.relative_to(ROOT))
