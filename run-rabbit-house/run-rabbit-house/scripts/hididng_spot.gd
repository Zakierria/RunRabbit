extends Node3D

@export var require_crouch_to_enter: bool = false
@export var crouch_when_hidden: bool = false

@onready var area: Area3D = $HidingArea
@onready var hide_position: Marker3D = $HidePosition
@onready var exit_position: Marker3D = $ExitPosition


func _ready() -> void:
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	# only detects player 
	if not body.has_method("set_nearby_hiding_spot"):
		return
		
	#for debugging
	#print("entered hiding spot: ", get_path())
	#print("hide marker: ", hide_position.global_position)

	print("Player entered hiding area!!")
	body.set_nearby_hiding_spot(self)
	
func _on_body_exited(body: Node3D) -> void:
#only respond when player leave
	if not body.has_method("clear_nearby_hiding_spot"):
		return
		
	if body.is_hiding:
		return
		
	print("Player left hiding area")
	body.clear_nearby_hiding_spot(self)


func get_hide_position() -> Vector3:
	return hide_position.global_position


func get_exit_position() -> Vector3:
	return exit_position.global_position
	
func needs_crouching() -> bool:
	return require_crouch_to_enter
	
func should_crouch_when_hidden() -> bool:
	return crouch_when_hidden
