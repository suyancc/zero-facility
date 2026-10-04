extends Button
const UI:=preload("res://scripts/ui_theme.gd")
const NAMES:Dictionary={"smoke":"烟雾罐","jammer":"干扰器","pick":"撬锁工具","decoy":"声音诱饵"}
const MODEL_TEXTURES:Dictionary={
"smoke":preload("res://assets/ui/items/smoke-model.png"),
"jammer":preload("res://assets/ui/items/jammer-model.png"),
"pick":preload("res://assets/ui/items/pick-model.png"),
"decoy":preload("res://assets/ui/items/decoy-model.png")}
var catalog:bool=false
var equipped_slot:int=0
var reduced:bool=false
var selection_flash:float=0
var kind:String="smoke"
var count:int=2
var keycap:String=""
var highlighted:bool=false
var cooldown:float=0
func _ready()->void:
	custom_minimum_size=Vector2(108,108);focus_mode=Control.FOCUS_NONE
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	add_theme_stylebox_override("normal",UI.panel(Color(0.025,0.07,0.10,0.94),4,9,Color("395568")))
	add_theme_stylebox_override("hover",UI.panel(Color("153d4b"),4,9,Color("77cbd5")))
	add_theme_stylebox_override("pressed",UI.panel(Color("205369"),4,9,Color("b1edee")))
	mouse_entered.connect(queue_redraw);mouse_exited.connect(queue_redraw)
func configure(value:String,amount:int,shortcut:String,active:bool,lock:float=0)->void:
	if (active and not highlighted) or kind!=value:selection_flash=0 if reduced else 1
	kind=value;count=amount;keycap=shortcut;highlighted=active;cooldown=lock
	tooltip_text=NAMES[kind]+" · "+("已用完" if count==0 else "按 "+shortcut+" 使用" if shortcut!="" else "点击装入选中格子")
	if catalog:tooltip_text=NAMES[kind]+" · 点选后装入当前格子"
	queue_redraw()
func _process(delta:float)->void:
	if selection_flash>0:selection_flash=maxf(0,selection_flash-delta*3);queue_redraw()
static func icon_for(value:String)->Texture2D:
	return MODEL_TEXTURES[value]
func _draw()->void:
	var color:=Color("ffd08b") if highlighted else Color("c2d5dd")
	if count==0:color=Color("5d7181")
	var model_tint:=Color(0.48,0.55,0.60,0.65) if count==0 else Color.WHITE
	draw_texture_rect(icon_for(kind),Rect2(Vector2(size.x/2-32,20),Vector2(64,64)),false,model_tint)
	if highlighted:
		var border:=UI.panel(Color(0.6,0.35,0.1,0.08+selection_flash*0.08),0,9,Color("ffcb83"));border.set_border_width_all(2)
		draw_style_box(border,Rect2(Vector2(1,1),size-Vector2(2,2)))
		for corner in [Vector2(7,7),Vector2(size.x-7,7),Vector2(7,size.y-7),size-Vector2(7,7)]:
			var dx:float=1 if corner.x<size.x/2 else -1;var dy:float=1 if corner.y<size.y/2 else -1
			draw_line(corner,corner+Vector2(9*dx,0),color,2);draw_line(corner,corner+Vector2(0,9*dy),color,2)
	if catalog and equipped_slot>0:draw_line(Vector2(21,13),Vector2(25,17),Color("8be2c0"),2);draw_line(Vector2(25,17),Vector2(32,9),Color("8be2c0"),2)
	draw_string(UI.FONT,Vector2(10,18),keycap,HORIZONTAL_ALIGNMENT_LEFT,-1,13,color)
	draw_string(UI.FONT,Vector2(size.x-35,18),"×%d"%count,HORIZONTAL_ALIGNMENT_LEFT,-1,14,color)
	draw_string(UI.FONT,Vector2(0,99),NAMES[kind],HORIZONTAL_ALIGNMENT_CENTER,size.x,14,color)
	if cooldown>0:draw_rect(Rect2(Vector2(8,size.y-7),Vector2((size.x-16)*clampf(cooldown,0,1),2)),color)

