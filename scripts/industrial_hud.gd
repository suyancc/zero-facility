extends Control
# Static, vector-rendered chrome. No full-screen textures or continuous redraw.
var ready_screen:bool=false
var hud:CanvasLayer
var brand:Label
var subtitle:Label
var operator_label:Label
var showcase:SubViewportContainer
func attach(owner_hud:CanvasLayer)->void:
	hud=owner_hud;mouse_filter=Control.MOUSE_FILTER_IGNORE;set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	brand=preload("res://scripts/ui_theme.gd").text("零号设施",48);add_child(brand);brand.position=Vector2(124,46)
	subtitle=preload("res://scripts/ui_theme.gd").text("战术潜行 / 行动准备",14,Color("ef9b51"));add_child(subtitle);subtitle.position=Vector2(127,111)
	operator_label=preload("res://scripts/ui_theme.gd").text("维修员 01\n现场技术 / 潜入行动",17,Color("bdcbd0"));add_child(operator_label)
	showcase=SubViewportContainer.new();showcase.set_script(preload("res://scripts/worker_showcase.gd"));add_child(showcase)
	resized.connect(layout);layout()
func layout()->void:
	if showcase==null:return
	showcase.position=Vector2(size.x*0.5+70,175);showcase.size=Vector2(maxf(220,size.x*0.5-380),maxf(340,size.y-270))
	operator_label.position=Vector2(size.x*0.5+105,size.y-97)
	if showcase.active:showcase.viewport.render_target_update_mode=SubViewport.UPDATE_ONCE
	queue_redraw()
func set_ready(value:bool)->void:
	if ready_screen==value and brand.visible==value:return
	ready_screen=value;brand.visible=value;subtitle.visible=value;operator_label.visible=value;showcase.set_enabled(value);queue_redraw()
func _draw()->void:
	var orange:=Color("ed9147");var line:=Color(0.4,0.6,0.68,0.3)
	if ready_screen:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.015,0.032,0.05,0.95))
		for x in range(0,int(size.x),48):draw_line(Vector2(x,0),Vector2(x,size.y),Color(0.15,0.3,0.36,0.09))
		for y in range(0,int(size.y),48):draw_line(Vector2(0,y),Vector2(size.x,y),Color(0.15,0.3,0.36,0.09))
		draw_colored_polygon(PackedVector2Array([Vector2(size.x*0.48,150),Vector2(size.x-310,150),Vector2(size.x-310,size.y-30),Vector2(size.x*0.39,size.y-30)]),Color("102531"))
		for sector in range(3):
			var points:=PackedVector2Array()
			for k in range(3):
				var angle:float=(sector*2+k)*TAU/6-PI/2
				points.append(Vector2(78,88)+Vector2(cos(angle),sin(angle))*31)
			draw_polyline(points,orange if sector==1 else Color("c7d4d9"),7,true)
		draw_line(Vector2(48,148),Vector2(size.x-48,148),line,1)
		draw_line(Vector2(48,148),Vector2(176,148),orange,3)
		draw_arc(Vector2(size.x*0.65,size.y*0.57),150,0,TAU,64,line,1,true)
		draw_arc(Vector2(size.x*0.65,size.y*0.57),159,0.3,1.6,24,orange,2,true)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(16,16),Vector2(440,16),Vector2(459,37),Vector2(459,145),Vector2(16,145)]),Color(0.02,0.045,0.065,0.9))
		draw_line(Vector2(16,16),Vector2(168,16),orange,3)
		draw_line(Vector2(16,145),Vector2(459,145),line)
		draw_rect(Rect2(Vector2(size.x-360,16),Vector2(344,59)),Color(0.02,0.045,0.065,0.92))
		draw_rect(Rect2(Vector2(16,size.y-112),Vector2(176,65)),Color(0.02,0.045,0.065,0.9))
		draw_line(Vector2(16,size.y-112),Vector2(92,size.y-112),orange,2)

