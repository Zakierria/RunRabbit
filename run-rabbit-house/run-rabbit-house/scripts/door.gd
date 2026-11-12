extends StaticBody3D

var is_open := false
var is_animating := false

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var door_collision: CollisionShape3D = $door_collision


func interact(_hit_node: Node = null) -> void:
	if is_animating: 
		return
		
		is_animating = true
		
	if is_open:
		animation_player.play("door_close")
	else:
		animation_player.play("door_open")
		
	await animation_player.animation_finished
		
	is_open = not is_open
	
	door_collision.set_deferred("disabled", is_open)
	
func _on_animation_finished(anim_name: StringName):
	if anim_name == "door_open":
		door_collision.set_deferred("disabled", true)

	elif anim_name == "door_closed":
		door_collision.set_deferred("disabled", false)
		
	await animation_player.animation_finished
	is_animating = false


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	pass # Replace with function body.
