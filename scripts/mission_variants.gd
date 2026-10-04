extends RefCounted
const TITLES:Array=[ ["多路突破","警戒封锁","双重授权"], ["完整下载","分段取证","双端校验"], ["直接转运","先稳后运","分流交付"] ]
static func variant(d:Dictionary)->int:return int(d.get("variant",0))
static func decorate(d:Dictionary,stage:int,rng:RandomNumberGenerator,pool:Array[Vector2i],used:Array[Vector2i])->void:
	var v:int=0 if stage<=3 else (int((stage-1)/3)%3 if stage<=9 else rng.randi_range(0,2))
	d.variant=v;d.variant_title=TITLES[d.mission][v]
	if d.mission==1 and v==1:
		var c:Vector2i=preload("res://scripts/level_generator.gd")._pick(rng,pool,used)
		d.items[0].name="数据分片甲"
		d.items.append({"at":preload("res://scripts/level_generator.gd").world(c),"kind":"download","name":"数据分片乙","duration":0.65})
	if d.mission==2 and v==2:
		var c:Vector2i=preload("res://scripts/level_generator.gd")._pick(rng,pool,used)
		d.items.append({"at":preload("res://scripts/level_generator.gd").world(c),"kind":"override","name":"静默交付接口","duration":4.0})
	if d.mission==1 and v==2:d.items[1].name="校验控制台"
	if d.mission==2 and v==1:d.items[1].name="核心稳定控制台"
static func brief(d:Dictionary)->String:
	var v:int=variant(d)
	var briefs:Array=[
		["取得门禁卡或操作解封台，再开门撤离。\n可选：装备撬锁可直破出口；控制器打开维修捷径。", "刷卡前须关闭监控；也可用解封台强行突破。\n强解需 8 秒且更响；先用控制器可缩短至 4 秒。", "收集门禁卡并操作解封台，集齐两重授权。\n可选：携带撬锁直接破门；无装备也能完成授权。"],
		["启动终端，等待 10 秒，再返回取走数据。\n期间可离开躲避；控制器关闭监控并打开捷径。", "分别启动甲、乙终端，各下载 5 秒后取回分片。\n两端可同时下载，移动更快但要规划往返路线。", "先操作校验控制台，再到数据终端下载 10 秒。\n校验同时关闭监控 45 秒，利用窗口取回数据。"],
		["搬起核心，到出口交付，再开门撤离。\n不能冲刺；F 可放下探路，控制器开启维修捷径。", "先操作稳定控制台，再搬起核心到出口交付。\n稳定永久有效；监控离线仅 45 秒，搬运须规划。", "搬起核心后选择接口：出口快接或远端静默交付。\n快接 1 秒但引来调查；静默接口 4 秒，交付后仍须撤离。"] ]
	var at:Vector3=d.items[0].at
	var room:String="监控室" if at.x<0 and at.z<0 else "数据机房" if at.x>=0 and at.z<0 else "仓储区" if at.x<0 else "能源舱"
	var direction:Vector3=d.exit_direction
	var side:String="东侧" if direction.x>0.5 else "西侧" if direction.x< -0.5 else "南侧" if direction.z>0.5 else "北侧"
	return "主目标位于"+room+" · 本局出口在"+side+"\n"+str(briefs[d.mission][v])+"\n撤离：完成任务 → 长按 E 开门 → 穿过出口。"

