extends CanvasLayer
const UI := preload("res://scripts/ui_theme.gd")
signal gear_changed(values:Array[String])
signal tracking_pressed
var tracking_button:Button
var model_preview:PanelContainer
var gear_row:HBoxContainer
signal gear_focused(slot:int)
const Tile:=preload("res://scripts/gear_tile.gd")
var backpack:VBoxContainer
var inventory_tiles:Array[Button]=[]
var catalog_tiles:Array[Button]=[]
var chosen:Array[String]=["smoke","pick"]
var editing_slot:int=0
var equipment_enabled:bool=false
var equipment_label:Label
const GEAR_KEYS:Array[String]=["smoke","jammer","pick","decoy"]
signal practice_pressed
signal primary_pressed
signal retry_pressed
signal pause_pressed
signal mute_pressed
signal settings_opened
signal volume_changed(value: float)
signal music_changed(value:float)
signal heartbeat_changed(value:float)
signal edge_changed(value:bool)
signal motion_changed(value: bool)
var root: Control
var timer_label: Label
var stage_label: Label
var status_label: Label
var badge: Label
var overlay: PanelContainer
var heading: Label
var body: Label
var primary: Button
var secondary: Button
var mute_button: Button
var progress: ProgressBar
var ticket_meta: Label
var risk_label: Label
var settings: PanelContainer
var volume_slider: HSlider
var music_slider:HSlider
var heartbeat_slider:HSlider
var edge_toggle:CheckButton
var tension_edge:ColorRect
var motion_toggle: CheckButton
var toast: Label
var flash: ColorRect
var shade: ColorRect
var hints: Label
var guard_count: int = 1
var stage: int = 1
var reduced_motion: bool = false
var modal_tween: Tween
var modal_kind:String="ready"
var stamina_bar:ProgressBar
var stamina_text:Label
var interact_text:Label
var tactics:Label
var target_arrow:Polygon2D
var target_label:Label
var pursued:int=0
var mission_text: String = "送达绿色接收台"

func _ready() -> void:
	root=Control.new()
	root.theme=UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(root)
	tension_edge=ColorRect.new();tension_edge.set_script(preload("res://scripts/tension_overlay.gd"));root.add_child(tension_edge)
	var left:=VBoxContainer.new()
	left.position=Vector2(30,24)
	left.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	stage_label=UI.text("零号设施 / 区域 001",24)
	left.add_child(stage_label)
	status_label=UI.text("送达绿色接收台",17,UI.MINT)
	left.add_child(status_label)
	badge=UI.text("",14,UI.ORANGE)
	left.add_child(badge)
	tactics=UI.text("",14,UI.INK)
	left.add_child(tactics)
	target_arrow=Polygon2D.new()
	target_arrow.polygon=PackedVector2Array([Vector2(14,0),Vector2(-8,-7),Vector2(-4,0),Vector2(-8,7)])
	target_arrow.color=UI.ORANGE
	root.add_child(target_arrow)
	target_label=UI.text("目标方向",14,UI.ORANGE)
	root.add_child(target_label)
	var right:=HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left=-350
	right.offset_right=-24
	right.offset_top=26
	right.add_theme_constant_override("separation",10)
	root.add_child(right)
	timer_label=UI.text("00:00.0",23)
	timer_label.custom_minimum_size.x=105
	right.add_child(timer_label)
	right.add_child(UI.button("暂停",func():pause_pressed.emit()))
	right.add_child(UI.button("设置",func():settings_opened.emit();settings.visible=true))
	mute_button=UI.button("声音开",func():mute_pressed.emit())
	right.add_child(mute_button)
	hints=UI.text("WASD 移动   Shift 奔跑   Ctrl 潜行   E 交互   1 / 2 装备   T 切换目标   F 放下核心   Tab 地图",14,UI.INK)
	hints.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hints.offset_top=-40
	hints.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(hints)
	progress=ProgressBar.new()
	progress.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	progress.offset_left=-95
	progress.offset_right=95
	progress.offset_top=-86
	progress.offset_bottom=-80
	progress.max_value=1.0
	progress.show_percentage=false
	progress.add_theme_stylebox_override("background",UI.panel(Color("243f4c"),0,3))
	progress.add_theme_stylebox_override("fill",UI.panel(UI.MINT,0,3))
	root.add_child(progress)
	interact_text=UI.text("",18,UI.ORANGE)
	interact_text.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	interact_text.offset_top=-122
	interact_text.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(interact_text)
	var endurance:=VBoxContainer.new()
	endurance.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	endurance.offset_left=28;endurance.offset_top=-100;endurance.offset_right=170;endurance.offset_bottom=-55
	root.add_child(endurance)
	stamina_text=UI.text("体力 100",14,UI.MUTED);endurance.add_child(stamina_text)
	stamina_bar=ProgressBar.new();stamina_bar.max_value=100;stamina_bar.value=100
	stamina_bar.custom_minimum_size=Vector2(140,7);stamina_bar.show_percentage=false
	stamina_bar.add_theme_stylebox_override("background",UI.panel(Color("243f4c"),0,3))
	stamina_bar.add_theme_stylebox_override("fill",UI.panel(UI.MINT,0,3));endurance.add_child(stamina_bar)
	equipment_label=UI.text("",16,UI.ORANGE)
	equipment_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	equipment_label.offset_left=-480;equipment_label.offset_top=-88;equipment_label.offset_right=-25
	root.add_child(equipment_label)
	shade=ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color=Color(0.035,0.07,0.10,0.30)
	shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(shade)
	_build_ticket()
	_build_settings()
	model_preview=PanelContainer.new();model_preview.set_script(preload("res://scripts/equipment_preview.gd"));root.add_child(model_preview)
	model_preview.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	model_preview.offset_left=-308;model_preview.offset_right=-24;model_preview.offset_top=165;model_preview.offset_bottom=565

	tracking_button=UI.button("T · 切换跟踪目标",func():tracking_pressed.emit())
	tracking_button.position=Vector2(24,442);tracking_button.custom_minimum_size=Vector2(228,36)
	tracking_button.add_theme_font_size_override("font_size",13)
	tracking_button.tooltip_text="切换方案或支线的指引，不改变主任务条件。"
	root.add_child(tracking_button)
	backpack=VBoxContainer.new();backpack.position=Vector2(24,170);backpack.add_theme_constant_override("separation",8);root.add_child(backpack)
	backpack.add_child(UI.text("装备 / 两格",13,UI.MUTED))
	for slot in range(2):
		var tile:=Button.new();tile.set_script(Tile);backpack.add_child(tile);inventory_tiles.append(tile)
		tile.pressed.connect(func():editing_slot=slot;gear_focused.emit(slot);_refresh_gear())

	flash=ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter=Control.MOUSE_FILTER_IGNORE
	flash.color=Color(1,0.2,0.3,0)
	root.add_child(flash)
	toast=UI.text("",19,UI.MINT)
	toast.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	toast.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toast.offset_top=105
	root.add_child(toast)

func _build_ticket() -> void:
	overlay=PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	overlay.offset_left=-305
	overlay.offset_right=305
	overlay.offset_top=-505
	overlay.offset_bottom=-68
	overlay.add_theme_stylebox_override("panel",UI.panel(Color(0.05,0.13,0.18,0.94),22,18,Color("668e94")))
	root.add_child(overlay)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",9)
	overlay.add_child(stack)
	ticket_meta=UI.text("封锁区域",12,UI.MUTED)
	stack.add_child(ticket_meta)
	heading=UI.text("开工啦！",30,UI.INK)
	stack.add_child(heading)
	body=UI.text("",16,UI.INK)
	body.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size=Vector2(440,42)
	stack.add_child(body)
	risk_label=UI.text("",13,UI.ORANGE)
	stack.add_child(risk_label)
	gear_row=HBoxContainer.new();gear_row.add_theme_constant_override("separation",12);stack.add_child(gear_row)
	for kind in GEAR_KEYS:
		var tile:=Button.new();tile.set_script(Tile);tile.catalog=true;gear_row.add_child(tile)
		tile.configure(kind,1 if kind=="jammer" else 2,"",false)
		tile.pressed.connect(func():_choose_gear(kind));catalog_tiles.append(tile)
	var row:=HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	stack.add_child(row)
	primary=UI.button("空格开始",func():primary_pressed.emit(),true)
	primary.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	row.add_child(primary)
	secondary=UI.button("再玩一次",_secondary_action)
	row.add_child(secondary)

func _build_settings() -> void:
	settings=PanelContainer.new()
	settings.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	settings.offset_left=-250
	settings.offset_right=250
	settings.offset_top=-300
	settings.offset_bottom=300
	settings.add_theme_stylebox_override("panel",UI.panel(Color("163542"),26,18,UI.MUTED))
	root.add_child(settings)
	var stack:=VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	settings.add_child(stack)
	stack.add_child(UI.text("休息一下",28))
	stack.add_child(UI.text("总音量 · 音乐 / 脚步 / 环境",16,UI.MUTED))
	volume_slider=HSlider.new()
	volume_slider.max_value=1.0
	volume_slider.step=0.01
	volume_slider.value=0.65
	volume_slider.value_changed.connect(func(v:float):volume_changed.emit(v))
	stack.add_child(volume_slider)
	stack.add_child(UI.text("背景音乐 · 随探测与追捕渐变",15,UI.MUTED))
	music_slider=HSlider.new();music_slider.max_value=1;music_slider.step=0.01;music_slider.value=0.8;stack.add_child(music_slider)
	music_slider.value_changed.connect(func(v:float):music_changed.emit(v))
	stack.add_child(UI.text("心跳音量 · 不影响任务提示",15,UI.MUTED))
	heartbeat_slider=HSlider.new();heartbeat_slider.max_value=1;heartbeat_slider.step=0.01;heartbeat_slider.value=0.75;stack.add_child(heartbeat_slider)
	heartbeat_slider.value_changed.connect(func(v:float):heartbeat_changed.emit(v))
	edge_toggle=CheckButton.new();edge_toggle.text="画面边缘心跳";edge_toggle.button_pressed=true;stack.add_child(edge_toggle)
	edge_toggle.toggled.connect(func(v:bool):edge_changed.emit(v))
	motion_toggle=CheckButton.new()
	motion_toggle.text="弱化闪光与镜头反馈"
	motion_toggle.toggled.connect(func(v:bool):reduced_motion=v;motion_changed.emit(v))
	stack.add_child(motion_toggle)
	stack.add_child(UI.text("Shift 奔跑消耗体力，Ctrl 潜行降低脚步声。\n高掩体挡视线，矮箱不保证安全。红色闪烁代表目标确认或追捕。",15,UI.MUTED))
	stack.add_child(UI.text("场景素材 Kenney / 字体 Noto / 原创合成配乐",12,UI.MUTED))
	stack.add_child(UI.button("返回游戏",func():settings.hide();pause_pressed.emit(),true))
	settings.hide()

func set_stage(value:int,title:String,count:int) -> void:
	stage=value
	guard_count=count
	stage_label.text="零号设施 / 区域 %03d · %s"%[value,title]
	ticket_meta.text="封锁区域 · %s"%title

func set_mission(text:String) -> void:
	mission_text=text
	status_label.text=text

func show_message(title:String,message:String,action:String,kind:String="ready") -> void:
	modal_kind=kind
	if gear_row!=null:gear_row.visible=kind=="ready"
	if model_preview!=null:model_preview.set_enabled(kind=="ready" and equipment_enabled)
	heading.text=title
	heading.modulate=Color("ff8b7c") if kind=="lost" else UI.MINT if kind=="won" else UI.INK
	body.text=message
	primary.text=action
	secondary.visible=kind=="won" or (kind=="ready" and stage>1)
	secondary.text="练习首区" if kind=="ready" else "再玩一次"
	risk_label.text="空格确认 · R 重试" if kind!="ready" else "点左侧装备格，再点图标换装 · %d 台巡检"%guard_count
	shade.visible=kind!="ready"
	overlay.show()
	if is_instance_valid(modal_tween):modal_tween.kill()
	if not reduced_motion:
		overlay.modulate.a=0
		modal_tween=create_tween()
		modal_tween.tween_property(overlay,"modulate:a",1.0,0.18)
	else:overlay.modulate.a=1

func hide_message() -> void:
	model_preview.set_enabled(false)
	overlay.hide()
	shade.hide()
	settings.hide()

func feedback(color:Color) -> void:
	if reduced_motion:return
	flash.color=Color(color,0.1)
	create_tween().tween_property(flash,"color:a",0.0,0.28)

func update_readout(seconds:float,delivery:float,risk:float,protection:float,state:int) -> void:
	timer_label.text="%02d:%04.1f"%[int(seconds/60.0),fmod(seconds,60.0)]
	progress.value=delivery
	progress.visible=delivery>0 and state==1
	hints.modulate.a=0.48 if seconds>7 and state==1 else 0.95
	status_label.text="正在交互…保持按住 E" if delivery>0 and state==1 else mission_text
	badge.text="起步保护 %.1f"%protection if state==1 and protection>0 else "正在被 %d 台巡检追捕！"%pursued if state==1 and pursued>0 else "目标确认 %d%%"%int(risk*100) if state==1 and risk>0.03 else ""
	badge.visible=not badge.text.is_empty()
	badge.modulate=Color("ff7770") if pursued>0 else UI.ORANGE

func update_escape(stamina:float,count:int,quiet:bool,running:bool,chased:int,intel:int,hint:String)->void:
	pursued=chased
	tactics.text="诱饵 %d/2 · 档案 %d/3 · %s"%[count,intel,"潜行中" if quiet else "奔跑中" if running else "保持警觉"]
	if equipment_enabled:tactics.text="档案 %d/3 · %s"%[intel,"潜行中" if quiet else "奔跑中" if running else "保持警觉"]
	stamina_bar.value=stamina
	stamina_bar.modulate=UI.ORANGE if stamina<25 else Color.WHITE
	stamina_text.text="体力 %d"%int(stamina)
	interact_text.text=hint
	interact_text.visible=not overlay.visible and not settings.visible

func update_target(projected:Vector2,active:bool)->void:
	var size:=get_viewport().get_visible_rect().size
	var bounds:=Rect2(Vector2(154,160),size-Vector2(194,300))
	var visible_area:=Rect2(Vector2(154,125),size-Vector2(179,190))
	var offscreen:bool=not visible_area.has_point(projected)
	target_arrow.visible=active and offscreen
	target_label.visible=active and offscreen
	if not offscreen:return
	target_arrow.position=projected.clamp(bounds.position,bounds.end)
	target_arrow.rotation=(projected-size*0.5).angle()
	target_label.size=Vector2(190,36);target_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	target_label.position=(target_arrow.position+Vector2(-95,16)).clamp(Vector2(154,40),size-Vector2(200,65))

func _secondary_action()->void:
	if modal_kind=="ready":practice_pressed.emit()
	else:retry_pressed.emit()
func show_equipment(enabled:bool,values:Array[String])->void:
	equipment_enabled=enabled;tracking_button.visible=enabled;gear_row.visible=enabled;backpack.visible=enabled;equipment_label.hide();chosen=values.duplicate();model_preview.set_enabled(enabled and overlay.visible and modal_kind=="ready");_refresh_gear()
func _refresh_gear()->void:
	for i in range(2):inventory_tiles[i].configure(chosen[i],1 if chosen[i]=="jammer" else 2,str(i+1),i==editing_slot)
	for tile in catalog_tiles:
		tile.equipped_slot=chosen.find(tile.kind)+1
		tile.configure(tile.kind,1 if tile.kind=="jammer" else 2,str(tile.equipped_slot) if tile.equipped_slot>0 else "",tile.kind==chosen[editing_slot])
	model_preview.set_item(chosen[editing_slot],editing_slot,reduced_motion)
func _choose_gear(kind:String)->void:
	if modal_kind!="ready" or not overlay.visible:return
	var other:int=1-editing_slot
	if chosen[other]==kind:chosen[other]=chosen[editing_slot]
	chosen[editing_slot]=kind;_refresh_gear();gear_changed.emit(chosen.duplicate())
func update_inventory(values:Array[String],amounts:Dictionary,selected:int,cooldown:float,ready:bool)->void:
	if not equipment_enabled:return
	model_preview.reduced=reduced_motion
	for tile in inventory_tiles+catalog_tiles:tile.reduced=reduced_motion
	chosen=values.duplicate()
	for i in range(2):inventory_tiles[i].configure(values[i],int(amounts.get(values[i],0)),str(i+1),i==(editing_slot if ready else selected),cooldown/0.6 if not ready else 0)

func update_tracking(title:String,distance:float,enabled:bool)->void:
	tracking_button.text="T · %s  %dm"%[title,roundi(distance)]
	tracking_button.disabled=not enabled
	target_label.text=title
