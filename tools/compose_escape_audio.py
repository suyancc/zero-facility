"""Original 24-second minor-key facility pulse, generated without sampled recordings."""
from pathlib import Path
import numpy as np
import soundfile as sf
rate=24000;beat=.75;n=int(32*beat*rate)
y=np.zeros((n,2))
def note(start,duration,midi,gain,pan=0,pad=False):
 t=np.arange(int(duration*rate))/rate;f=440*2**((midi-69)/12)
 if pad:
  env=np.sin(np.pi*t/duration)**2
  a=(np.sin(2*np.pi*f*t)+.25*np.sin(2*np.pi*(f*2.002)*t))*env
 else:
  env=(1-np.exp(-t*80))*np.exp(-t*4)
  a=(np.sin(2*np.pi*f*t)+.18*np.sin(2*np.pi*f*3*t))*env
 idx=(int(start*rate)+np.arange(len(t)))%n
 y[idx,0]+=a*gain*np.sqrt((1-pan)/2);y[idx,1]+=a*gain*np.sqrt((1+pan)/2)
chords=[[50,53,57,60],[46,50,53,57],[48,52,55,58],[45,48,52,55]]
for bar in range(8):
 chord=chords[(bar//2)%4]
 for j,m in enumerate(chord):note(bar*4*beat,4.6*beat,m,.07,(-1)**j*.4,True)
 for off in [0,1.5,2.75]:note((bar*4+off)*beat,.8,chord[0]-12,.18)
 for off,m in [(1,chord[2]+12),(3,chord[1]+12)]:note((bar*4+off)*beat,1.2,m,.04,.35)
y+=np.roll(y,int(beat*rate),axis=0)*.23
y*=.78/np.max(np.abs(y))
p=Path('assets/audio/escape-pulse.ogg');sf.write(p,y,rate,format='OGG',subtype='VORBIS')
x,sr=sf.read(p);print('escape-pulse.ogg',len(x)/sr,'seconds','peak',abs(x).max(),'bytes',p.stat().st_size)
