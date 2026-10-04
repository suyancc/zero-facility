"""Original looping work-in-progress sounds, distinct from success cues."""
from pathlib import Path
import math,random,struct,wave
root=Path(__file__).resolve().parents[1]/'assets/audio/operations';root.mkdir(parents=True,exist_ok=True)
rate=22050
for index,kind in enumerate(['card','intel','download','control','override','pick','core','deliver']):
 rng=random.Random(641+index);data=[]
 for i in range(rate):
  t=i/rate;p=(t*(3+index%4))%1
  pulse=math.exp(-p*(16 if kind in ['pick','override'] else 8))
  edge=math.sin(math.pi*t)**2
  hz=[880,587,440,164,110,1400,98,196][index]
  tone=math.sin(2*math.pi*hz*t)*.55+math.sin(2*math.pi*hz*2*t)*.17
  noise=(rng.random()*2-1)*(.42 if kind in ['pick','override','control'] else .07)
  signal=(tone*(.25+.75*pulse)+noise*pulse)*edge*.3
  data.append(int(max(-1,min(1,signal))*32767))
 with wave.open(str(root/(kind+'.wav')),'wb') as f:
  f.setparams((1,2,rate,0,'NONE','not compressed'));f.writeframes(struct.pack('<%dh'%rate,*data))
 print(kind)
