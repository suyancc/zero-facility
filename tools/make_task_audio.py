"""Original event cues: deterministic additive synthesis; no third-party samples."""
from pathlib import Path
import math, wave, struct
ROOT=Path(__file__).resolve().parents[1]/'assets/audio/tasks'
RATE=22050
# (seconds, start, duration, Hz); identity, rhythm and duration vary by task.
CUES={
 'card':(.72,[(0,.12,660),(.15,.22,990),(.40,.12,1320)]),
 'power':(1.0,[(0,.30,130.81),(.17,.30,261.63),(.40,.35,523.25)]),
 'intel':(1.75,[(0,.23,392),(.19,.28,493.88),(.42,.36,587.33),(.82,.52,783.99)]),
 'download_start':(1.15,[(0,.12,330),(.15,.12,440),(.30,.16,660),(.54,.30,880)]),
 'download_ready':(2.65,[(0,.42,523.25),(.23,.48,659.25),(.50,.55,783.99),(.95,.92,1046.5)]),
 'download_collect':(1.10,[(0,.17,1046.5),(.20,.21,783.99),(.46,.35,659.25)]),
 'control':(1.30,[(0,.22,440),(.25,.24,293.66),(.53,.43,196)]),
 'override':(1.65,[(0,.18,196),(.25,.18,246.94),(.50,.18,293.66),(.86,.48,392)]),
 'core':(1.45,[(0,.40,98),(.23,.45,196),(.59,.52,392)]),
 'core_drop':(.5,[(0,.15,196),(.14,.19,130.81)]),
 'deliver':(2.9,[(0,.52,130.81),(.27,.62,261.63),(.64,.64,329.63),(1.03,.83,392),(1.42,.83,523.25)]),
 'door':(.65,[(0,.16,220),(.22,.20,330)]),
 'pick':(.82,[(0,.05,1100),(.13,.05,1400),(.28,.10,880),(.44,.20,587.33)]),
 'breach':(1.65,[(0,.22,196),(.32,.22,261.63),(.70,.56,392)]),
 'mission':(3.5,[(0,.55,261.63),(.25,.62,329.63),(.51,.68,392),(1.0,1.05,523.25),(1.50,1.1,659.25)]),
 'escape':(1.7,[(0,.35,523.25),(.35,.39,392),(.78,.53,261.63)]),
 'captured':(1.25,[(0,.35,196),(.28,.40,155.56),(.61,.42,110)]),
}
def save(name,duration,notes):
    samples=[0.] * int(RATE*duration)
    for start,length,hz in notes:
        for i in range(int(length*RATE)):
            t=i/RATE; pos=int(start*RATE)+i
            if pos>=len(samples):break
            env=min(1,t/.018)*max(0,1-t/length)**1.6
            tone=math.sin(2*math.pi*hz*t)*.72+math.sin(2*math.pi*hz*2*t)*.16+math.sin(2*math.pi*hz*.5*t)*.12
            samples[pos]+=tone*env*.27
    # Finite three-tap room tail, not a gameplay loop.
    dry=samples.copy()
    for delay,gain in [(.10,.15),(.21,.09),(.34,.045)]:
        shift=int(RATE*delay)
        for i in range(shift,len(samples)):samples[i]+=dry[i-shift]*gain
    with wave.open(str(ROOT/(name+'.wav')),'wb') as f:
        f.setparams((1,2,RATE,0,'NONE','not compressed'))
        f.writeframes(struct.pack('<%dh'%len(samples),*(int(max(-.95,min(.95,s))*32767) for s in samples)))
    return duration
ROOT.mkdir(parents=True,exist_ok=True)
for name,(duration,notes) in CUES.items():save(name,duration,notes)
# Seamless one-second loop: integer frequencies, smooth beat, zero boundary envelope.
samples=[]
for i in range(RATE):
    t=i/RATE;env=math.sin(math.pi*t)**2
    samples.append(int((math.sin(2*math.pi*110*t)*.65+math.sin(2*math.pi*220*t)*.20)*env*.055*32767))
with wave.open(str(ROOT/'download_loop.wav'),'wb') as f:
    f.setparams((1,2,RATE,0,'NONE','not compressed'));f.writeframes(struct.pack('<%dh'%RATE,*samples))
print('Generated',len(CUES)+1,'original WAV files')
