
extends StaticBody3D

@export var requires_key: bool = false
@export var required_item: String = "room_key"
@export var consume_key: bool = false

var is_open := false
var is_animating := false
var is_unlocked := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var door_collision: CollisionShape3D = $door_collision


func interact_with_player(player) -> void:

	# Check if this door requires a key
	if requires_key and not is_unlocked:

		# Check if the player has the required key
		if not player.has_item(required_item):

			# Show an on-screen message
			if player.has_method("show_interaction_message"):
				if required_item == "front_door_key":
					player.show_interaction_message("You need Front Door Key.")
				else:
					player.show_interaction_message("You need the Key.")
			else:
				print("This door is locked.")

			return

		# Unlock the door
		is_unlocked = true
		print("Door unlocked!")

		# Only remove the key if this option is enabled
		if consume_key:
			if player.has_method("remove_item"):
				player.remove_item(required_item)

	# Open or close the door
	interact()


func interact(_hit_node: Node = null) -> void:

	if is_animating:
		return

	if animation_player == null:
		print("ERROR: AnimationPlayer missing on ", name)
		return

	var animation_name: StringName

	if is_open:
		animation_name = "door_close"
	else:
		animation_name = "door_open"

	if not animation_player.has_animation(animation_name):
		print("Missing animation: ", animation_name)
		return

	is_animating = true

	animation_player.play(animation_name)

	var finished_animation: StringName = await animation_player.animation_finished

	if finished_animation == animation_name:
		is_open = not is_open
		door_collision.set_deferred("disabled", is_open)

	is_animating = false
