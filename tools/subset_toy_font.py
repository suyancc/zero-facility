from pathlib import Path
import sys
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from fontTools import subset
r=Path('.')
text=''.join(p.read_text() for p in (r/'scripts').glob('*.gd'))+''.join(chr(x) for x in range(32,127))+'重力快递玩具工厂开始扫描签收失败保护奖章暂停'
f=TTFont(sys.argv[1])
f=instantiateVariableFont(f,{'wght':500},inplace=True)
opts=subset.Options();opts.name_IDs=['*'];opts.name_legacy=True;opts.name_languages=['*']
s=subset.Subsetter(options=opts);s.populate(text=text);s.subset(f)
for record in f['name'].names:
 if record.nameID in [1,4,6,16,17]:
  value={1:'Toy Sans SC',4:'Toy Sans SC Medium',6:'ToySansSC-Medium',16:'Toy Sans SC',17:'Medium'}[record.nameID]
  record.string=value.encode(record.getEncoding())
f.save('assets/fonts/ToySansSC.ttf')
print('Toy font saved')

