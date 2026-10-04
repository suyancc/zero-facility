"""Original 8-bar toy-factory loop, synthesized without third-party recordings."""
from pathlib import Path
import numpy as np
import soundfile as sf
rate=24000
beat=0.625
seconds=32*beat
n=int(rate*seconds)
music=np.zeros((n,2));rng=np.random.default_rng(8124)
def add(at,duration,frequency,gain=0.1,pan=0.0,kind='bell'):
 t=np.arange(int(duration*rate))/rate
 if kind=='bell':
  a=(np.sin(2*np.pi*frequency*t)*np.exp(-t*5)+0.25*np.sin(2*np.pi*frequency*3*t)*np.exp(-t*12))*(1-np.exp(-t*180))
 elif kind=='bass':a=np.sin(2*np.pi*frequency*t)*np.sin(np.pi*np.minimum(t/duration,1))**0.4
 elif kind=='hat':a=rng.normal(0,1,len(t))*np.exp(-t*55)*(1-np.exp(-t*300))
 else:a=np.sin(2*np.pi*(55*t+3*(1-np.exp(-t*40))))*np.exp(-t*16)
 idx=(int(at*rate)+np.arange(len(t)))%n
 music[idx,0]+=a*gain*np.sqrt((1-pan)/2)
 music[idx,1]+=a*gain*np.sqrt((1+pan)/2)
def hz(midi):return 440*2**((midi-69)/12)
chords=[[57,60,64,67],[53,57,60,64],[48,52,55,59],[55,59,62,65]]
for bar in range(8):
 chord=chords[bar%4]
 for j,degree in enumerate([0,2,1,3,2,1]):add((bar*4+[0,0.75,1.5,2,2.75,3.5][j])*beat,1.0,hz(chord[degree]+12),0.09,(-1)**j*0.32)
 for offset in [0,2]:add((bar*4+offset)*beat,0.9,hz(chord[0]-12),0.12,kind='bass');add((bar*4+offset)*beat,0.2,55,0.09,kind='kick')
 for off in np.arange(0.5,4,0.5):add((bar*4+off)*beat,0.11,0,0.017,0.25,kind='hat')
# Tiny periodic echo; circular construction preserves loop continuity.
music+=np.roll(music,int(beat*0.75*rate),axis=0)*0.17
music=np.tanh(music*1.6)
p=Path('assets/audio');p.mkdir(parents=True,exist_ok=True)
music*=0.82/np.max(np.abs(music))
sf.write(p/'toy-shift.ogg',music,rate,format='OGG',subtype='VORBIS')
t=np.arange(n)/rate
# Periodic motor harmonics + filtered ventilation, with endpoint crossfade.
noise=rng.normal(0,1,n)
from scipy.signal import butter,sosfilt
noise=sosfilt(butter(2,450,fs=rate,output='sos'),noise)
a=0.045*np.sin(2*np.pi*60*t)+0.017*np.sin(2*np.pi*120*t)+noise*0.045
fade=int(rate*0.15);a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
a*=0.65/np.max(np.abs(a))
sf.write(p/'factory-room.ogg',np.stack([a,np.roll(a,150)],axis=1),rate,format='OGG',subtype='VORBIS')
for f in ['toy-shift.ogg','factory-room.ogg']:
 x,sr=sf.read(p/f);print(f,'seconds',len(x)/sr,'peak',float(abs(x).max()),'bytes',(p/f).stat().st_size)

