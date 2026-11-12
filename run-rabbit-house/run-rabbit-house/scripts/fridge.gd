extends StaticBody3D

var top_is_open := false
var bottom_is_open := false
var is_animating := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer

func interact(hit_node: Node = null) -> void:
	if is_animating or hit_node == null: 
		return
		
	var door_name := hit_node.name
	var animation_name: String = ""
	
	#determines which door the player is trying to open
	if door_name == "Area3D":
		if hit_node.get_parent() != null:
			door_name = hit_node.get_parent().name
			
		
		if door_name == "top_door":
			if top_is_open:
				animation_name = "top_door_close"
			else:
				animation_name = "top_door_open"
				
		elif door_name == "bottom_door":
			if  bottom_is_open:
				animation_name  = "bottom_door_close"
			else:
				animation_name = "bottom_door_open"
			
		else:
			print("girl that door not there: ", door_name)
			return
			
		if not animation_player.has_animation(animation_name):
			print("missin animation: ", animation_name)
			return
		
	is_animating = true
	
	animation_player.play(animation_name)
	
	
	if door_name =="top_door":
		top_is_open = not top_is_open
	elif door_name == "bottom_door":
		bottom_is_open = not bottom_is_open
	
	await animation_player.animation_finished
	
	is_animating = false
