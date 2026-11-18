extends StaticBody3D

@onready var animation_player: AnimationPlayer = find_child(
	"AnimationPlayer",
	true,
	false
)

# assigns one Area3D for every independently interactive part.
@export var interaction_areas: Array[Area3D] = []

# arrays gotta follow the same name, make sure they match 
@export var open_animations: Array[StringName] = []
@export var close_animations: Array[StringName] = []

# tracks each individual part independently
var part_states: Array[bool] = []

var is_animating := false


func _ready() -> void:

	part_states.resize(interaction_areas.size())
	part_states.fill(false)

	if animation_player == null:
		push_error("AnimationPlayer is missing on " + name)
		return

	if interaction_areas.size() != open_animations.size():
		push_error("Interaction areas and open animations do not match on " + name)

	if interaction_areas.size() != close_animations.size():
		push_error("Interaction areas and close animations do not match on " + name)



func interact(hit_node: Node = null) -> void:

	if is_animating:
		return

	if hit_node == null:
		print("No furniture part was hit.")
		return

	if animation_player == null:
		print("ERROR: AnimationPlayer not found on ", name)
		return

	print("Furniture: ", name)
	print("Assigned interaction areas: ", interaction_areas.size())

	for area in interaction_areas:
		if area != null:
			print("Assigned Area: ", area.get_path())
		else:
			print("WARNING: An interaction area is empty.")

	#identfies the exact Area3D that was hit.
	var part_index := find_part(hit_node)

	if part_index == -1:
		print("Could not identify interactive part.")
		print("Ray hit: ", hit_node.get_path())
		print("Furniture: ", name)
		return

	if part_index >= open_animations.size():
		print("Missing open animation assignment.")
		return

	if part_index >= close_animations.size():
		print("Missing close animation assignment.")
		return

	var currently_open := part_states[part_index]

	var animation_name: StringName

	if currently_open:
		animation_name = close_animations[part_index]
	else:
		animation_name = open_animations[part_index]

	if not animation_player.has_animation(animation_name):
		print("MISSING ANIMATION: ", animation_name)
		print("Available animations: ", animation_player.get_animation_list())
		return

	is_animating = true

	animation_player.play(animation_name)

	print("Playing: ", animation_name)

	var finished_animation: StringName = await animation_player.animation_finished

	if finished_animation == animation_name:
		part_states[part_index] = not currently_open

		print(
			interaction_areas[part_index].name,
			" is now open: ",
			part_states[part_index]
		)

	is_animating = false



func find_part(hit_node: Node) -> int:

	var current_node: Node = hit_node

	# search the hit node and its parents.
	while current_node != null:

		#comapre the hit node against every assigned Area3D, just to make sure the node is reacting properly
		for i in range(interaction_areas.size()):

			var area := interaction_areas[i]

			if area == null:
				continue

			if current_node == area or area.is_ancestor_of(current_node):
				print("Identified furniture part: ", area.get_path())
				print("Part index: ", i)
				return i

		if current_node == self:
			break
			
		current_node = current_node.get_parent()
		
	print("No matching Area3D found.")
	return -1
