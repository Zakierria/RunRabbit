extends StaticBody3D

@export var required_item: String = "Key"

var is_unlocked: bool = false


func interact(player: Node3D) -> void:
	if is_unlocked:
		return

	if player.has_method("has_item") and player.has_item(required_item):
		is_unlocked = true
		print("Door unlocked!")
		queue_free()
	else:
		print("The door is locked. You need a key.")
