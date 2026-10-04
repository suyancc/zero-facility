extends RefCounted
var mode:String="calm"
var intensity:float=0
var phase:float=0
var beat_age:float=10
var bpm:float=78
var alarm_hold:float=0
var recovery_hold:float=0
var last:Dictionary={"mode":"calm","intensity":0.0,"pulse":0.0,"beat":false,"entered":false,"bpm":78.0}
func reset()->void:
	mode="calm";intensity=0;phase=0;beat_age=10;bpm=78;alarm_hold=0;recovery_hold=0
	last={"mode":mode,"intensity":0.0,"pulse":0.0,"beat":false,"entered":false,"bpm":bpm}
func tick(delta:float,state:int,confidence:float,chased:bool,searching:bool,alarm:bool)->Dictionary:
	if state==2:
		var frozen:=last.duplicate();frozen.beat=false;frozen.entered=false;return frozen
	if state!=1:reset();return last
	var dt:float=clampf(delta,0,0.1)
	var previous:String=mode
	alarm_hold=maxf(0,alarm_hold-dt);recovery_hold=maxf(0,recovery_hold-dt)
	if alarm:alarm_hold=2.2
	if chased or alarm_hold>0:
		mode="chase";recovery_hold=6.0
	elif confidence>0.12 or (mode=="suspect" and confidence>0.045):mode="suspect"
	elif searching or recovery_hold>0:mode="recovery"
	else:mode="calm"
	var target:float=1.0 if mode=="chase" else lerpf(0.22,0.76,clampf(confidence,0,1)) if mode=="suspect" else 0.32 if mode=="recovery" else 0.0
	intensity=lerpf(intensity,target,1-exp(-dt*(3.5 if target>intensity else 0.6)))
	bpm=lerpf(78,144,intensity)
	beat_age+=dt;var beat:bool=false
	if intensity>0.04:
		phase+=dt*bpm/60.0
		if phase>=1:phase=fmod(phase,1);beat_age=0;beat=true
	else:phase=0;beat_age=10
	var pulse:float=exp(-beat_age*23.0)
	if beat_age>=0.12:pulse+=0.58*exp(-(beat_age-0.12)*30.0)
	last={"mode":mode,"intensity":intensity,"pulse":minf(pulse,1),"beat":beat,"entered":mode=="chase" and previous!="chase","bpm":bpm}
	return last
