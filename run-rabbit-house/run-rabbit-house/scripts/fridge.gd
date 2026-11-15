extends StaticBody3D

var top_is_open := false
var bottom_is_open := false
var is_animating := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer


func interact(hit_node: Node = null) -> void:

	if is_animating or hit_node == null:
		return

	# Find out which refrigerator door was hit.
	var current_node: Node = hit_node
	var door_name := ""

	while current_node != null and current_node != self:

		if current_node.name == "top_door":
			door_name = "top_door"
			break

		elif current_node.name == "bottom_door":
			door_name = "bottom_door"
			break

		current_node = current_node.get_parent()

	# Stop if we cannot identify a door.
	if door_name == "":
		print("Could not identify fridge door. Hit: ", hit_node.get_path())
		return

	var animation_name := ""

	# Select the correct animation.
	if door_name == "top_door":

		if top_is_open:
			animation_name = "top_door_close"
		else:
			animation_name = "top_door_open"

	elif door_name == "bottom_door":

		if bottom_is_open:
			animation_name = "bottom_door_close"
		else:
			animation_name = "bottom_door_open"

	# Make sure the animation exists.
	if not animation_player.has_animation(animation_name):
		print("Missing fridge animation: ", animation_name)
		return

	# Play the animation.
	is_animating = true

	animation_player.play(animation_name)

	await animation_player.animation_finished

	# Update the door state.
	if door_name == "top_door":
		top_is_open = not top_is_open

	elif door_name == "bottom_door":
		bottom_is_open = not bottom_is_open

	is_animating = false

	print("Fridge door animation finished: ", animation_name)
