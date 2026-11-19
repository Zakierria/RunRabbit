extends Node
## Escape ending (like Granny's): when the player opens the front door, the game cuts
## straight to the old man sitting on the living-room couch (the door never actually opens),
## and the camera starts close to him and pulls back until he and the couch fill the shot.
## Then the scene pauses and fades to black.
##
## Move the "EndingSitSpot" marker to change where he sits: it marks where his HIPS go
## (blue arrow = the way he faces). Move "EndingCameraStart" to change where the camera
## starts (it pulls backwards from there).

@export_node_path("Node") var front_door: NodePath = ^"../Navigation/House/furniture/door2"
@export_node_path("CharacterBody3D") var old_man: NodePath = ^"../OldMan"
@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../player"
@export_node_path("Node3D") var sit_spot: NodePath = ^"../EndingSitSpot"
@export_node_path("Node3D") var camera_start: NodePath = ^"../EndingCameraStart"
@export_node_path("Node3D") var frame_target: NodePath = ^"../TrenchbroomPrototype/furniture/couch"  ## The camera pulls back until this (and him) is fully in view
@export var sit_animation: String = "man_sit_start"  ## Its last frame (seated) is held
@export var pull_back_speed: float = 0.6     ## How fast the camera moves back (metres per second)
@export var max_pull_back: float = 15.0      ## Safety limit
@export_range(0.0, 0.3) var screen_margin: float = 0.06  ## Space left around him and the couch when it stops
@export var camera_fov: float = 70.0
@export var hold_before_fade: float = 1.5  ## Seconds the final shot stays before fading
@export var fade_out_time: float = 2.0     ## How long the fade to black takes

var _done: bool = false
var _camera: Camera3D
var _door: Node
var _man: Node3D


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # keeps working after the scene is paused
	_door = get_node_or_null(front_door)
	if _door == null:
		_door = get_tree().get_first_node_in_group("front_door")# added for testinf
		#push_warning("Escape ending: can't find the front door (set Front Door).")
	#added for testing
	if _door == null:
		push_warning("Escape ending: front door not found")
	else:
		print("escape ending found front door: ", _door.get_path())

func _physics_process(_delta: float) -> void:
	if _done or _door == null:
		return
	# The moment the front door starts to open (it only can once it's unlocked), cut to the ending.
	if _door.get("is_animating") or _door.get("is_open"):
		_done = true
		_play_ending()


func _play_ending() -> void:
	# The door doesn't actually open: stop its opening animation where it is.
	var door_anim := _door.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if door_anim:
		door_anim.pause()

	# Freeze the player.
	var player := get_node_or_null(player_path) as CharacterBody3D
	if player:
		player.velocity = Vector3.ZERO
		player.set_physics_process(false)
		player.set_process_unhandled_input(false)
		player.set_process_input(false)

	# Sit the old man on the couch, with his hips on the EndingSitSpot marker.
	_man = get_node_or_null(old_man) as Node3D
	var spot := get_node_or_null(sit_spot) as Node3D
	if _man and spot and _man.has_method("sit_for_ending"):
		_man.sit_for_ending(spot.global_transform, sit_animation)
		_fit_hips_to(spot.global_position)

	# Camera close in front of him.
	var start := get_node_or_null(camera_start) as Node3D
	_camera = Camera3D.new()
	_camera.fov = camera_fov
	get_tree().current_scene.add_child(_camera)
	_camera.global_transform = start.global_transform if start else (_door as Node3D).global_transform
	_camera.make_current()

	# A short beat on the close-up, then pull back until he and the couch are fully on screen.
	await get_tree().create_timer(0.3).timeout
	var moved := 0.0
	while moved < max_pull_back and not _target_fully_visible():
		var step := pull_back_speed * get_physics_process_delta_time()
		_camera.global_position += _camera.global_basis.z * step  # +Z = backwards for a camera
		moved += step
		await get_tree().physics_frame

	# Freeze the whole scene on this shot.
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	# Hold the shot for a moment, then fade to black.
	await get_tree().create_timer(hold_before_fade, true).timeout
	var layer := CanvasLayer.new()
	layer.layer = 100
	var black := ColorRect.new()
	black.color = Color(0, 0, 0, 0)
	black.set_anchors_preset(Control.PRESET_FULL_RECT)
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(black)
	add_child(layer)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # keeps running while the scene is paused
	tween.tween_property(black, "color:a", 1.0, fade_out_time)

# waits for fade out to finish
	await tween.finished
	
	# unpause the game
	get_tree().paused = false
	
	#loads win screen
	get_tree().change_scene_to_file("res://scenes/win_screen.tscn")


## Moves him so his hips land exactly on the sit spot, whatever the couch height is.
func _fit_hips_to(target: Vector3) -> void:
	var skeleton := _skeleton()
	if skeleton == null:
		return
	var hips := skeleton.find_bone("Hips")
	if hips < 0:
		return
	skeleton.force_update_all_bone_transforms()
	var hips_now := skeleton.global_transform * skeleton.get_bone_global_pose(hips).origin
	_man.global_position += target - hips_now


## True when every corner of the couch (plus his head) is on screen, with a small margin.
func _target_fully_visible() -> bool:
	var box := _frame_bounds()
	if box.size == Vector3.ZERO:
		return true
	var view := get_viewport().get_visible_rect().size
	var margin := view * screen_margin
	for i in 8:
		var corner := box.get_endpoint(i)
		if _camera.is_position_behind(corner):
			return false
		var p := _camera.unproject_position(corner)
		if p.x < margin.x or p.y < margin.y or p.x > view.x - margin.x or p.y > view.y - margin.y:
			return false
	return true


func _frame_bounds() -> AABB:
	var result := AABB()
	var first := true
	var target := get_node_or_null(frame_target)
	if target:
		for node in target.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box := mesh.global_transform * mesh.get_aabb()
			result = box if first else result.merge(box)
			first = false
	# Make sure his head is in the shot too.
	var skeleton := _skeleton()
	if skeleton:
		var head := skeleton.find_bone("Head")
		if head >= 0:
			var head_top := skeleton.global_transform * skeleton.get_bone_global_pose(head).origin + Vector3.UP * 0.25
			result = AABB(head_top, Vector3.ZERO) if first else result.expand(head_top)
	return result


func _skeleton() -> Skeleton3D:
	if _man == null:
		return null
	var found := _man.find_children("*", "Skeleton3D", true, false)
	return found[0] as Skeleton3D if not found.is_empty() else null
