extends CharacterBody3D
## The old man.
## - Starts under the stairs.
## - Wanders between the PatrolPoints in a random order (slow walk), pausing a random
##   moment at each one (idle animation), and never goes straight back to where he just was.
## - Opens unlocked doors on his way; squeezes past locked ones.
## - Makes footstep sounds while walking, so the player can hear where he is.
## - Sees the player up to 5 m away (in front of him, not through walls), then follows a bit faster
##   with chase music. Loses the player after 4 seconds out of sight and checks where he last saw them.
## - Catches the player when close: player frozen, view locked on his face, Mixamo catch
##   animation (caught_animation.gd), fade to black, level restarts.
## - Sits on the stairs for the escape ending (escape_ending.gd calls sit_for_ending).
##
## Needs in the level: a NavigationRegion3D with nav_bake.gd, a "PatrolPoints" node with Marker3D children,
## and the player node (Player Path).

enum State { PATROL, WAIT, INVESTIGATE, CHASE, CATCH, CUTSCENE }

@export_group("Patrol")
@export_node_path("Node3D") var patrol_group: NodePath = ^"../PatrolPoints"  ## Marker3D children = the spots he wanders between
@export var speed: float = 1.1                  ## Walking speed while patrolling (slow)
@export var chase_speed: float = 1.8            ## Walking speed once he has seen you (a bit faster, still walking)
@export var turn_speed: float = 8.0             ## How quickly he turns
@export var wait_time_min: float = 1.0          ## Shortest pause at a patrol point
@export var wait_time_max: float = 4.0          ## Longest pause at a patrol point
@export var stuck_time: float = 3.0             ## Gives up on a point if blocked this long

@export_group("Spotting & catching")
@export_node_path("CharacterBody3D") var player_path: NodePath = ^"../player"
@export var sight_range: float = 5.0            ## How far he can see
@export_range(0.0, 180.0) var sight_angle: float = 70.0  ## Half-width of his view cone, in degrees
@export var eye_height: float = 1.65            ## Height of his eyes (for line of sight)
@export var forget_time: float = 4.0            ## Seconds out of sight before he gives up the chase
@export var catch_distance: float = 1.3         ## How close he must get to grab you
@export_file("*.fbx", "*.glb", "*.gltf") var catch_animation_file: String = "res://models/old_man/Angry.fbx"  ## Mixamo animation played when he catches you
@export var catch_duration: float = 2.5         ## Seconds of the catch scene before the screen fades

@export_group("Doors")
@export var door_open_distance: float = 1.6     ## Opens a closed (unlocked) door when this close to it

@export_group("Chase music")
@export var music_volume_db: float = -4.0       ## The track is the one in res://sounds/music
@export var music_fade_in: float = 0.4          ## Seconds to fade in when he spots you
@export var music_fade_out: float = 2.5         ## Seconds to fade out after he loses you

@export_group("Animation & sound")
@export var idle_animation: String = "old_man_idle"
@export var walk_animation: String = "man_walk_in_place"
@export var walk_speed_at_normal_rate: float = 1.85  ## Walking speed that matches the walk animation at normal speed
@export var steps_per_walk_cycle: int = 2

@onready var agent: NavigationAgent3D = $NavigationAgent3D
@onready var model: Node3D = $Model
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var collision: CollisionShape3D = $CollisionShape3D

var state: State = State.WAIT
var anim: AnimationPlayer
var player: CharacterBody3D
var patrol_points: Array[Node3D] = []
var _index: int = 0
var _timer: float = 0.0
var _stuck_timer: float = 0.0
var _best_distance: float = INF
var _step_timer: float = 0.0
var _squeeze_timer: float = 0.0
var _unreachable_in_a_row: int = 0
var _lost_timer: float = 0.0
var _repath_timer: float = 0.0
var _previous_index: int = -1
var _sight_ray := PhysicsRayQueryParameters3D.new()
var _spawn_transform: Transform3D
var _doors: Array[Node] = []
var _caught: Node3D   # plays the Mixamo catch animation on his skeleton
var _music: AudioStreamPlayer
var _music_tween: Tween
var _started: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")


func _ready() -> void:
	add_to_group("enemy")
	_spawn_transform = global_transform
	_find_doors.call_deferred(get_tree().current_scene)
	_setup_music()
	_fix_materials(model)

	anim = model.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if anim:
		for anim_name in [idle_animation, walk_animation]:
			if anim.has_animation(anim_name):
				anim.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
	else:
		push_warning("Old man: no AnimationPlayer found in the model.")
	_play(idle_animation)
	_setup_catch_animation()

	player = get_node_or_null(player_path) as CharacterBody3D
	if player == null:
		push_warning("Old man can't find the player (set Player Path), so he can't catch anyone.")

	if has_node(patrol_group):
		for child in get_node(patrol_group).get_children():
			if child is Node3D:
				patrol_points.append(child)
	if patrol_points.is_empty():
		push_warning("Old man has no patrol points, so he will stand still.")
		return

	# Wait for the navigation map to be ready before asking for a path.
	var map := get_world_3d().navigation_map
	for i in 900:  # up to ~15 seconds
		await get_tree().physics_frame
		if NavigationServer3D.map_get_iteration_id(map) > 0 and NavigationServer3D.map_get_closest_point(map, global_position) != Vector3.ZERO:
			break
	_started = true
	_index = 0  # he spawns at the first patrol point, so he heads for the next one straight away
	_wait(0.0)


func _physics_process(delta: float) -> void:
	if not _started:
		return
	if state == State.CATCH:
		_lock_player_view(delta)
		return
	if state == State.CUTSCENE:
		return

	# Safety net: if he ever falls through the floor, put him back where he started.
	if global_position.y < _spawn_transform.origin.y - 8.0:
		global_transform = _spawn_transform
		velocity = Vector3.ZERO
		_wait(1.0)
		return
	if not is_on_floor() and _squeeze_timer <= 0.0:
		velocity.y -= _gravity * delta

	_open_nearby_doors()
	if _squeeze_timer <= 0.0:
		collision.disabled = false  # never stay "ghosted" outside of a squeeze
	_look_for_player(delta)

	if state == State.WAIT:
		_stop()
		_play(idle_animation)
		_timer -= delta
		if _timer <= 0.0:
			_go_to_point(_next_point())
	else:
		_follow_path(delta)

	move_and_slide()


# ---------- Walking ----------

## Picks a random patrol point - never the one he's at, and not the one he just came from.
func _next_point() -> int:
	var choices: Array[int] = []
	for i in patrol_points.size():
		if i != _index and i != _previous_index:
			choices.append(i)
	if choices.is_empty():  # only one or two points
		for i in patrol_points.size():
			if i != _index:
				choices.append(i)
	if choices.is_empty():
		return _index
	return choices.pick_random()


func _current_speed() -> float:
	return chase_speed if state == State.CHASE else speed


func _go_to_point(i: int) -> void:
	if i != _index:
		_previous_index = _index
	_index = i
	_walk_to(patrol_points[_index].global_position, State.PATROL)


func _walk_to(target: Vector3, new_state: State) -> void:
	state = new_state
	agent.target_position = target
	_stuck_timer = 0.0
	_best_distance = INF


func _follow_path(delta: float) -> void:
	if agent.is_navigation_finished():
		_arrived()
		return

	var distance: float = agent.distance_to_target()
	if distance < _best_distance - 0.1:
		_best_distance = distance
		_stuck_timer = 0.0
	else:
		_stuck_timer += delta
		if _stuck_timer >= stuck_time:
			_arrived()
			return

	var direction: Vector3 = agent.get_next_path_position() - global_position
	direction.y = 0.0
	if direction.length() < 0.01:
		return
	direction = direction.normalized()
	var rate := _current_speed() / walk_speed_at_normal_rate

	# Caught on a door frame (or anything else)? Squeeze through: for a moment he ignores
	# collisions and slides straight along his path, which always stays on walkable floor.
	if _stuck_timer > 0.5 and _squeeze_timer <= 0.0:
		_squeeze_timer = 0.6
	if _squeeze_timer > 0.0:
		_squeeze_timer -= delta
		collision.disabled = true
		var step: Vector3 = agent.get_next_path_position() - global_position
		global_position += step.limit_length(_current_speed() * delta)
		velocity = Vector3.ZERO
	else:
		collision.disabled = false
		velocity.x = direction.x * _current_speed()
		velocity.z = direction.z * _current_speed()

	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), turn_speed * delta)
	_play(walk_animation, rate)
	_footsteps(delta, rate)


func _footsteps(delta: float, rate: float) -> void:
	_step_timer -= delta
	if _step_timer > 0.0:
		return
	var cycle := 1.0
	if anim and anim.has_animation(walk_animation):
		cycle = anim.get_animation(walk_animation).length
	_step_timer = cycle / steps_per_walk_cycle / rate
	footsteps.pitch_scale = randf_range(0.9, 1.1)
	footsteps.play()


func _arrived() -> void:
	_stop()
	# Couldn't actually get there (blocked, or the spot isn't reachable)? Don't stand there
	# staring at a wall - turn around and head straight for the next patrol point instead.
	if state == State.PATROL and global_position.distance_to(agent.target_position) > 1.5:
		_unreachable_in_a_row += 1
		if _unreachable_in_a_row <= patrol_points.size():
			rotation.y += PI
			_go_to_point(_next_point())
			return
	_unreachable_in_a_row = 0
	match state:
		State.INVESTIGATE:
			_wait(3.0)  # looks around where he last saw you, then goes back to patrolling
		State.CHASE:
			_walk_to(player.global_position, State.CHASE)  # keep going
		_:
			_wait(randf_range(wait_time_min, wait_time_max))


func _wait(seconds: float) -> void:
	state = State.WAIT
	_timer = seconds
	_squeeze_timer = 0.0
	collision.disabled = false


# ---------- Spotting, chasing, catching ----------

func _can_see_player() -> bool:
	if player == null:
		return false
	var eye := global_position + Vector3.UP * eye_height
	var target := player.global_position + Vector3.UP * 0.4
	var to_player := target - eye
	if to_player.length() > sight_range:
		return false
	var forward := -global_basis.z
	var flat := Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() > 0.5 and rad_to_deg(forward.angle_to(flat.normalized())) > sight_angle:
		return false
	# Line of sight: is a wall in the way?
	_sight_ray.from = eye
	_sight_ray.to = target
	var ignore: Array[RID] = [get_rid(), player.get_rid()]
	_sight_ray.exclude = ignore
	return get_world_3d().direct_space_state.intersect_ray(_sight_ray).is_empty()


func _look_for_player(delta: float) -> void:
	if player == null:
		return
	var sees := _can_see_player()

	if state != State.CHASE:
		if sees:
			_music_on()
			_lost_timer = 0.0
			_walk_to(player.global_position, State.CHASE)
		return

	# Chasing
	if sees:
		_lost_timer = 0.0
		_repath_timer -= delta
		if _repath_timer <= 0.0:
			_repath_timer = 0.25
			agent.target_position = player.global_position
	else:
		_lost_timer += delta
		if _lost_timer >= forget_time:
			_music_off(music_fade_out)
			_walk_to(agent.target_position, State.INVESTIGATE)  # check where he last saw you
			return

	var flat := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
	if flat.length() <= catch_distance and absf(player.global_position.y - global_position.y) < 1.5:
		_catch()


func _catch() -> void:
	state = State.CATCH
	_stop()
	velocity = Vector3.ZERO
	_music_off(catch_duration)
	footsteps.stop()

	# Freeze the player completely (no moving, no looking around).
	player.velocity = Vector3.ZERO
	player.set_physics_process(false)
	player.set_process(false)
	player.set_process_input(false)
	player.set_process_unhandled_input(false)

	# He turns to face the player; the player's view locks onto his face (see _lock_player_view).
	var to_player := player.global_position - global_position
	rotation.y = atan2(-to_player.x, -to_player.z)

	if _caught:
		# Switch his own animations off completely, so only the catch animation moves him.
		anim.stop()
		anim.active = false
		_caught.play()
	else:
		_play(idle_animation)

	await get_tree().create_timer(catch_duration).timeout
	await _fade_to_black(0.8)
	get_tree().reload_current_scene()


func _setup_catch_animation() -> void:
	var skeleton := model.find_children("*", "Skeleton3D", true, false)
	if skeleton.is_empty():
		return
	var caught := preload("res://caught_animation.gd").new() as Node3D
	caught.source_path = catch_animation_file
	model.add_child(caught)
	if caught.setup(skeleton[0]):
		_caught = caught
	else:
		caught.queue_free()


## While catching: every frame, turn the player's body and head so they stare at his face.
func _lock_player_view(delta: float) -> void:
	if player == null:
		return
	var face := global_position + Vector3.UP * eye_height
	var to_me := face - player.global_position
	player.rotation.y = lerp_angle(player.rotation.y, atan2(-to_me.x, -to_me.z), minf(1.0, 12.0 * delta))
	var head := player.get_node_or_null("head") as Node3D
	if head:
		var from_eyes := face - head.global_position
		var pitch := atan2(from_eyes.y, Vector2(from_eyes.x, from_eyes.z).length())
		head.rotation.x = lerp_angle(head.rotation.x, pitch, minf(1.0, 12.0 * delta))


func _fade_to_black(seconds: float) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(rect)
	get_tree().current_scene.add_child(layer)  # removed automatically when the level reloads
	var tween := create_tween()
	tween.tween_property(rect, "color:a", 1.0, seconds)
	await tween.finished


# ---------- Doors ----------

func _find_doors(node: Node) -> void:
	if node.has_method("interact") and "is_open" in node:
		_doors.append(node)
	for child in node.get_children():
		_find_doors(child)


## Opens closed, unlocked doors in front of him (the same way the player does with E).
## Locked doors stay shut - he squeezes past those instead.
func _open_nearby_doors() -> void:
	if velocity.length() < 0.1 and _squeeze_timer <= 0.0:
		return
	for door in _doors:
		if not is_instance_valid(door) or door.is_open or door.get("is_animating"):
			continue
		if door.get("requires_key") and not door.get("is_unlocked"):
			continue
		var door_pos: Vector3 = door.global_position
		var door_collision := door.get_node_or_null("door_collision") as Node3D
		if door_collision:
			door_pos = door_collision.global_position
		if Vector2(door_pos.x - global_position.x, door_pos.z - global_position.z).length() < door_open_distance:
			door.interact()


# ---------- Ending ----------

## Called by escape_ending.gd: stop everything and sit at this spot, already seated.
func sit_for_ending(spot: Transform3D, sit_animation: String) -> void:
	state = State.CUTSCENE
	velocity = Vector3.ZERO
	_squeeze_timer = 0.0
	collision.disabled = true
	footsteps.stop()
	_music_off(1.0)
	global_transform = spot
	if anim and anim.has_animation(sit_animation):
		# Jump to the end of the sit-down so he's already seated, and hold that pose.
		anim.get_animation(sit_animation).loop_mode = Animation.LOOP_NONE
		anim.play(sit_animation, 0.0)
		anim.seek(anim.current_animation_length, true)
		anim.pause()
	# Light him up so he's easy to see in the ending shot.
	var light := OmniLight3D.new()
	light.light_energy = 2.5
	light.omni_range = 4.0
	light.light_color = Color(1.0, 0.92, 0.8)
	add_child(light)
	light.position = Vector3(0, 2.2, 0)


# ---------- Chase music ----------

func _setup_music() -> void:
	var track := _first_track_in("res://sounds/music")
	if track == null:
		return
	# Make it loop, whatever the file type.
	if "loop" in track:
		track.loop = true
	elif track is AudioStreamWAV:
		track.loop_mode = AudioStreamWAV.LOOP_FORWARD
		track.loop_end = int(track.get_length() * track.mix_rate)
	_music = AudioStreamPlayer.new()
	_music.stream = track
	_music.volume_db = -60.0
	add_child(_music)


func _first_track_in(folder: String) -> AudioStream:
	for file in ResourceLoader.list_directory(folder):
		if file.get_extension().to_lower() in ["ogg", "mp3", "wav"]:
			return load(folder.path_join(file)) as AudioStream
	return null


func _music_on() -> void:
	if _music == null:
		return
	if _music_tween:
		_music_tween.kill()
	if not _music.playing:
		_music.play()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", music_volume_db, music_fade_in)


func _music_off(seconds: float) -> void:
	if _music == null or not _music.playing:
		return
	if _music_tween:
		_music_tween.kill()
	_music_tween = create_tween()
	_music_tween.tween_property(_music, "volume_db", -60.0, seconds)
	_music_tween.tween_callback(_music.stop)


# ---------- Helpers ----------

func _play(anim_name: String, rate: float = 1.0) -> void:
	if anim == null or not anim.has_animation(anim_name):
		return
	if anim.current_animation != anim_name:
		anim.play(anim_name, 0.25)
	anim.speed_scale = rate


## The model's textures mark it as metal, which renders black in the Compatibility renderer
## (nothing to reflect). Make every material non-metallic so his real colours show.
func _fix_materials(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.get_surface_override_material_count():
			var mat := mesh_instance.get_active_material(i)
			if mat is BaseMaterial3D:
				var fixed := mat.duplicate() as BaseMaterial3D
				fixed.metallic = 0.0
				fixed.metallic_texture = null
				fixed.metallic_specular = 0.3
				mesh_instance.set_surface_override_material(i, fixed)
	for child in node.get_children():
		_fix_materials(child)


func _stop() -> void:
	velocity.x = 0.0
	velocity.z = 0.0
