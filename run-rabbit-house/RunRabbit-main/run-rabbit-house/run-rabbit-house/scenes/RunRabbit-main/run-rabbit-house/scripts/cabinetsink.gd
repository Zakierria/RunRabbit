extends StaticBody3D


var left_is_open := false
var right_is_open:= false
var is_animating := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
#@onready var cabinet_collision: CollisionShape3D = $cabinet_collision

func interact(hit_node: Node = null) -> void:
	if is_animating or hit_node == null: 
		return
		
	var door_side := ""
	var current_node: Node = hit_node
	
	while current_node != null and current_node != self:
		var node_name := current_node.name.to_lower()
		
		if node_name.contains("left"):
			door_side = "left"
			break
		elif node_name.contains("right"):
			door_side = "right"
			break
			
		current_node = current_node.get_parent()
	
	if door_side == "":
		print("Could not identify cabinet door: ", hit_node.name)
		return
		
	var animation_name: String

	if door_side == "left":
		if left_is_open:
			animation_name = "left_cabinet_close"
		else:
			animation_name = "left_cabinet_open"

	else:
		if right_is_open:
			animation_name = "right_cabinet_close"
		else:
			animation_name = "right_cabinet_open"
			
	if not animation_player.has_animation(animation_name):
		print("Missing cabinet animation: ", animation_name)
		return
		
	is_animating = true
	animation_player.play(animation_name)
	
	await animation_player.animation_finished
	
	if door_side == "left":
		left_is_open = not left_is_open
	else:
		right_is_open = not right_is_open

	is_animating = false

	print(door_side, " cabinet is now open: ",
		left_is_open if door_side == "left" else right_is_open)

	
