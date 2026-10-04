extends RefCounted
# Keep the legacy application data path; upgrading the game must not erase progress.
const PATH:="user://gravity_progress.cfg"
static func clean_records(raw:Variant)->Dictionary:
	var clean:Dictionary={}
	if not raw is Dictionary:return clean
	for key in raw:
		if not str(key).is_valid_int():continue
		var row=raw[key]
		if not row is Dictionary:continue
		var seconds=row.get("seconds",0)
		if not (seconds is float or seconds is int) or seconds<=0 or seconds>86400:continue
		var stars=row.get("stars",1);var intel=row.get("intel",0)
		if not stars is int or not intel is int:continue
		clean[str(key)]={"seconds":float(seconds),"stars":clampi(stars,1,3),"intel":clampi(intel,0,3)}
	var keys:Array=clean.keys();keys.sort_custom(func(a:Variant,b:Variant):return int(a)<int(b))
	while keys.size()>128:clean.erase(keys.pop_front())
	return clean
static func read()->Dictionary:
	var result:Dictionary={"stage":1,"volume":0.65,"muted":false,"reduced":false,"records":{},"music_volume":0.8,"heartbeat_volume":0.75,"edge_heartbeat":true}
	var config:=ConfigFile.new()
	if config.load(PATH)!=OK:return result
	var stage=config.get_value("progress","stage",1)
	if stage is int:result.stage=clampi(stage,1,1000000000)
	var volume=config.get_value("settings","volume",0.65)
	if volume is float or volume is int:result.volume=clampf(float(volume),0,1)
	for key in ["muted","reduced"]:
		var value=config.get_value("settings",key,false)
		if value is bool:result[key]=value
	for key in ["music_volume","heartbeat_volume"]:
		var value=config.get_value("settings",key,result[key])
		if value is float or value is int:
			if is_finite(float(value)):result[key]=clampf(float(value),0,1)
	var edge=config.get_value("settings","edge_heartbeat",true)
	if edge is bool:result.edge_heartbeat=edge
	result.records=clean_records(config.get_value("tactical","records",{}))
	return result
static func write(data:Dictionary)->Error:
	var config:=ConfigFile.new()
	config.load(PATH) # Preserve old escape records and any unrelated settings.
	config.set_value("progress","stage",data.stage)
	for key in ["volume","muted","reduced"]:config.set_value("settings",key,data[key])
	for key in ["music_volume","heartbeat_volume","edge_heartbeat"]:
		if data.has(key):config.set_value("settings",key,data[key])
	config.set_value("tactical","records",clean_records(data.get("records",{})))
	return config.save(PATH)

