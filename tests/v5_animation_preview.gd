extends SceneTree
const UI:=preload("res://scripts/ui_theme.gd")
func _initialize()->void:call_deferred("run")
func run()->void:
	var game=load("res://scenes/main.tscn").instantiate();game.test_mode=true;root.add_child(game)
	await process_frame
	game.set_process(false);game.level.playing=false;game.hud.root.hide()
	var p=game.level.player;p.set_active(true);p.set_process(false);p.facing=-2.6;p.rig.rotation.y=-2.6
	for child in p.get_children():
		if child is Label3D:child.hide()
	game.camera.size=2.7;game.camera.position=p.position+Vector3(3,3,4);game.camera.look_at(p.position+Vector3.UP*0.8)
	var layer:=CanvasLayer.new();root.add_child(layer)
	var label:=UI.text("步行",30,Color("d2edf3"));label.theme=UI.theme();label.position=Vector2(35,30);layer.add_child(label)
	DirAccess.make_dir_recursive_absolute("res://exports/evidence/animation")
	for frame in range(48):
		p.running=frame>=24;p.sneaking=false;p.velocity=Vector3(4.2 if p.running else 2.4,0,0)
		label.text="奔跑" if p.running else "步行"
		p._process(1.0/12)
		await RenderingServer.frame_post_draw
		var image:=root.get_texture().get_image();image.resize(640,400,Image.INTERPOLATE_LANCZOS)
		image.save_png("res://exports/evidence/animation/frame%02d.png"%frame)
		await process_frame
	game.queue_free();layer.queue_free();await process_frame;quit()
