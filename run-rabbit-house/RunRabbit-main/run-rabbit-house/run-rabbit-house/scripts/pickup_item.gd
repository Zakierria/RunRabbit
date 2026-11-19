extends StaticBody3D

@export var item_id: String = "garage_key"
@export var item_display_name: String = "Garage Key"

var is_collected: bool = false


func interact_with_player(player: Node) -> void:
	if is_collected:
		return

	if player == null:
		return

	if not player.has_method("add_item"):
		print("Player does not have an inventory system!")
		return

	var successfully_added: bool = player.add_item(item_id)

	if successfully_added:
		is_collected = true

		print("Picked up: ", item_display_name)

		queue_free()
	else:
		print("Could not pick up: ", item_display_name)
