"""Original 128 BPM synchronized cinematic stems. No third-party recordings."""
import numpy as np,soundfile as sf
from pathlib import Path
R=22050;D=15.;N=int(R*D);t=np.arange(N)/R;rng=np.random.default_rng(665)
root=Path(__file__).resolve().parents[1]/'assets/audio/tension';root.mkdir(parents=True,exist_ok=True)
def note(a,at,length,hz,gain,kind=0):
 i=int(at*R);n=min(int(length*R),len(a)-i)
 if n<=0:return
 x=np.arange(n)/R
 if kind==1: env=np.exp(-x*16);v=np.sin(2*np.pi*(55*x+2*(1-np.exp(-x*22))))
 elif kind==2:env=np.exp(-x*35);v=rng.normal(0,0.35,n)+np.sin(2*np.pi*170*x)*.3
 else:env=(1-np.exp(-x*50))*np.exp(-x*3/max(length,.1));v=np.sin(2*np.pi*hz*x)+.2*np.sin(2*np.pi*hz*2*x)
 env*=np.minimum(1,(length-x)*50)
 a[i:i+n]+=v*env*gain
base=(np.sin(2*np.pi*55*t)*.045+np.sin(2*np.pi*82.4069*t)*.025+np.sin(2*np.pi*110*t)*.02)*(0.8+.2*np.sin(2*np.pi*t/D))
sus=np.zeros(N);chase=np.zeros(N);recovery=np.zeros(N)
beat=60/128
for i in range(32):
 hz=[220,261.6256,293.6648,207.6523][(i//8)%4]
 if i%2==0:note(sus,i*beat,.65,hz,.07)
 note(chase,i*beat,.23,55,.23,1)
 if i%2:note(chase,i*beat,.16,170,.055,2)
 note(chase,(i+.5)*beat,.12,880,.026,2)
 if i%2==0:note(chase,i*beat,.36,hz/2,.065)
 if i%8==0:note(recovery,i*beat,3.0,hz,.085);note(base,i*beat,2.4,hz/2,.035)
for name,a in [('calm',base),('suspicion',sus),('chase',chase),('recovery',recovery)]:
 fade=int(.04*R);a[:fade]*=np.linspace(0,1,fade);a[-fade:]*=np.linspace(1,0,fade)
 assert np.max(np.abs(a))<.95
 sf.write(root/(name+'.ogg'),a,R,format='OGG',subtype='VORBIS')
# Two close thuds are one beat, timed to the shared director's 0/.12s visual envelope.
h=np.zeros(int(.34*R));note(h,0,.17,55,.62,1);note(h,.12,.15,55,.39,1)
sf.write(root/'heartbeat.wav',h,R,subtype='PCM_16')
a=np.zeros(int(.7*R));note(a,0,.7,82.4069,.25);note(a,0,.3,164.8138,.11)
sf.write(root/'exposed.wav',a,R,subtype='PCM_16')
print('4 synchronized 15-second stems + heartbeat + exposure accent')
