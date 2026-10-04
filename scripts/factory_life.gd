extends Node3D
var belt_boxes:Array[Node3D]=[]
var clock:float=0
func _process(delta:float) -> void:
	clock+=delta
	for i in range(belt_boxes.size()):
		belt_boxes[i].position.x=-4.8+fmod(clock*0.45+i*2.0,9.6)

