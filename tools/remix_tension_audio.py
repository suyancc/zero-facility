"""0.6.7: normalize source loudness, add small-speaker harmonics; retain headroom."""
from pathlib import Path
import numpy as np,soundfile as sf,json
root=Path(__file__).resolve().parents[1];src=root/'assets/audio/tension';dst=root/'assets/audio/tension_mix';dst.mkdir(parents=True,exist_ok=True)
report={}
for name in ['calm','suspicion','chase','recovery','heartbeat','exposed']:
 suffix='.ogg' if name in ['calm','suspicion','chase','recovery'] else '.wav'
 x,rate=sf.read(src/(name+suffix));t=np.arange(len(x))/rate
 if name=='calm':x=x+.021*np.sin(2*np.pi*164.8138*t)+.014*np.sin(2*np.pi*220*t)
 if name=='heartbeat':
  env=np.exp(-t*22)+np.where(t>=.12,.55*np.exp(-np.maximum(0,t-.12)*28),0)
  x=x+.12*env*np.sin(2*np.pi*130*t)+.06*env*np.sin(2*np.pi*260*t)
 target=.18 if suffix=='.wav' else .10
 ceiling=.65 if name=='heartbeat' else .50
 gain=min(target/max(np.sqrt(np.mean(x*x)),1e-8),ceiling/max(np.max(np.abs(x)),1e-8))
 x*=gain
 fade=min(int(.008*rate),len(x)//10);x[:fade]*=np.linspace(0,1,fade);x[-fade:]*=np.linspace(1,0,fade)
 sf.write(dst/(name+suffix),x,rate,subtype='VORBIS' if suffix=='.ogg' else 'PCM_16')
 y,_=sf.read(dst/(name+suffix));report[name]={'rms_dbfs':float(20*np.log10(np.sqrt(np.mean(y*y)))),'peak_dbfs':float(20*np.log10(np.max(np.abs(y))))}
rate=22050;t=np.arange(int(rate*.42))/rate
x=(np.sin(2*np.pi*(620*t+240*t*t))+.18*np.sin(2*np.pi*1240*t))*np.minimum(t/.009,1)*np.exp(-t*7)
x*=.48/np.max(np.abs(x));x[-300:]*=np.linspace(1,0,300)
sf.write(dst/'detected.wav',x,rate,subtype='PCM_16')
(root/'docs/0.6.7-源音频响度.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
