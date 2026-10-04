"""Fit transparent Godot renders into a common square without stretching."""
from pathlib import Path
from PIL import Image
root=Path(__file__).resolve().parents[1]/'assets/ui/items'
for kind in ['smoke','jammer','pick','decoy']:
 image=Image.open(root/(kind+'.png')).convert('RGBA')
 box=image.getchannel('A').getbbox()
 if not box:raise RuntimeError('Empty model: '+kind)
 image=image.crop(box);image.thumbnail((116,116),Image.Resampling.LANCZOS)
 result=Image.new('RGBA',(128,128))
 result.alpha_composite(image,((128-image.width)//2,(128-image.height)//2))
 result.save(root/(kind+'-model.png'))
 print(kind,box,image.size)
