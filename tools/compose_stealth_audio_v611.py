"""Original procedural score and eight continuous interaction cues (no external recordings).
128 BPM / 15 s calm stem stays phase compatible with the existing danger stems.
Run after legacy source generation, never run the old remix over this output.
"""
from pathlib import Path
import numpy as np,soundfile as sf,json
root=Path(__file__).resolve().parents[1];R=22050;D=15.;t=np.arange(int(R*D))/R
rng=np.random.default_rng(6112026);beat=60/128
score=np.zeros(len(t))
def tone(freq,x):return np.sin(2*np.pi*freq*x)+.28*np.sin(2*np.pi*2*freq*x)+.08*np.sin(2*np.pi*3*freq*x)
def add(at,dur,hz,gain,attack=.025,decay=2):
 n=int(dur*R);x=np.arange(n)/R;env=(1-np.exp(-x/attack))*np.exp(-x*decay/dur)*np.clip((dur-x)/.08,0,1)
 v=tone(hz,x)*env*gain
 # periodic write: delay tails wrap, preserving the musical loop.
 np.add.at(score,(np.arange(n)+int(at*R))%len(score),v)
# Harmonically audible low-mid pad, not a sub-bass-only drone.
chords=[[110,164.8138,220],[130.8128,195.9977,233.0819],[146.8324,220,261.6256],[103.8262,155.5635,207.6523]]
for bar,chord in enumerate(chords):
 for h in chord:add(bar*8*beat,4.8,h,.038,attack=.38,decay=.9)
# Sparse cinematic motif and quiet answering echoes. No loud drums in calm play.
notes=[(0,329.6276),(3,246.9417),(6,261.6256),(9,293.6648),(12,391.9954),(16,329.6276),(19,261.6256),(22,293.6648),(25,311.127),(28,246.9417),(30,220)]
for b,h in notes:
 add(b*beat,1.75,h,.033,attack=.045,decay=3)
 add((b+.75)*beat,1.5,h,.010,attack=.05,decay=3)
for b in range(0,32,2):add(b*beat,.7,chords[b//8][0]*2,.013,attack=.045,decay=5)
score+=.016*np.sin(2*np.pi*55*t)*(.85+.15*np.cos(2*np.pi*t/D))
score*=min(.15/np.sqrt(np.mean(score**2)),.58/max(abs(score)))
# very short edge crossfade avoids a discontinuity without a long inaudible intro
fade=int(.006*R);score[:fade]*=np.linspace(0,1,fade);score[-fade:]*=np.linspace(1,0,fade)
dst=root/'assets/audio/tension_mix';sf.write(dst/'calm.ogg',score,R,subtype='VORBIS')
report={'calm':{'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(score**2)))),'peak_dbfs':float(20*np.log10(max(abs(score))))},'operations':{}}
t=np.arange(R)/R;ops=root/'assets/audio/operations';ops.mkdir(parents=True,exist_ok=True)
for i,name in enumerate(['card','intel','download','control','override','pick','core','deliver']):
 hz=[740,587,440,164,220,1100,146,196][i];speed=[6,4,8,5,7,12,3,4][i]
 phase=(t*speed)%1;tick=np.exp(-phase*(22 if name=='pick' else 13))
 noise=rng.normal(0,.25,R);noise=np.convolve(noise,np.ones(5)/5,mode='same')
 x=tone(hz,t)*(.24+.35*tick)
 if name in ['pick','control','override']:x+=noise*tick*1.7
 if name=='card':x+=.16*np.sin(2*np.pi*1480*t)*(.5+.5*np.sin(2*np.pi*6*t))
 if name in ['core','deliver']:x+=.18*np.sin(2*np.pi*hz*3*t)
 x-=np.mean(x);x*=min(.21/np.sqrt(np.mean(x*x)),.68/max(abs(x)))
 # 2 ms click prevention, not the former half-second fade-in.
 fade=44;x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
 sf.write(ops/(name+'.wav'),x,R,subtype='PCM_16')
 report['operations'][name]={'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(x*x)))),'first_100ms_dbfs':float(20*np.log10(np.sqrt(np.mean(x[:2205]**2)))),'peak_dbfs':float(20*np.log10(max(abs(x))))}
(root/'docs/0.6.11-音频源响度.json').write_text(json.dumps(report,indent=2));print(json.dumps(report,indent=2))
