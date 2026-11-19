extends Node
## Lets the player and the old man walk up steps (stairs, small ledges) instead of being blocked by them.
## When a character walks into something low enough to step onto, it gets lifted up onto it.
## Add this node to a level; it finds every CharacterBody3D by itself.

@export var search_root: NodePath = ^".."
@export var step_height: float = 0.35   ## Tallest step they can walk up (the house's stairs are 0.25)
@export var step_reach: float = 0.2     ## How far ahead to look for the top of the step
@export_range(0.1, 1.0) var stair_speed: float = 0.45  ## Walking speed on stairs compared to normal (0.45 = a bit under half)

var _bodies: Array[CharacterBody3D] = []
var _last_pos: Dictionary = {}    # body -> position last frame


func _ready() -> void:
	process_physics_priority = 100  # run after the characters have moved this frame
	await get_tree().process_frame
	_scan(get_node(search_root))


func _scan(node: Node) -> void:
	if node is CharacterBody3D:
		_bodies.append(node)
	for child in node.get_children():
		_scan(child)


func _physics_process(_delta: float) -> void:
	for body in _bodies:
		if not is_instance_valid(body) or not body.is_physics_processing():
			_last_pos.erase(body)
			continue
		var stepped := _try_step_up(body)
		_slow_on_stairs(body, stepped)
		_last_pos[body] = body.global_position


# On stairs (stepping up, or dropping down a step), only keep part of this frame's
# forward movement, so going up and down feels like real stairs instead of a sprint.
func _slow_on_stairs(body: CharacterBody3D, stepped: bool) -> void:
	if not _last_pos.has(body):
		return
	var last: Vector3 = _last_pos[body]
	var moved := body.global_position - last
	var going_down_step := moved.y < -0.05 and moved.y > -0.5 and body.is_on_floor()
	if not (stepped or going_down_step):
		return
	var flat := Vector3(moved.x, 0.0, moved.z)
	body.global_position -= flat * (1.0 - stair_speed)


func _try_step_up(body: CharacterBody3D) -> bool:
	if not body.is_on_wall():
		return false  # not walking into anything
	var into := -body.get_wall_normal()
	into.y = 0.0
	if into.length() < 0.5:
		return false
	var forward := into.normalized() * step_reach
	var up := Vector3.UP * step_height

	# Room above to lift up?
	if body.test_move(body.global_transform, up):
		return false
	var raised := body.global_transform.translated(up)
	# Still blocked when lifted? Then it's a wall, not a step.
	if body.test_move(raised, forward):
		return false
	# Drop back down onto the top of the step.
	var ahead := raised.translated(forward)
	var hit := KinematicCollision3D.new()
	if not body.test_move(ahead, -up, hit):
		return false  # nothing to stand on
	if hit.get_normal().y < 0.7:
		return false  # too steep to stand on
	body.global_position = ahead.origin + hit.get_travel()
	return true
