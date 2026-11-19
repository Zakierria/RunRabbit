extends Node3D
## Plays a Mixamo animation (e.g. Angry.fbx) on the old man, even though his skeleton is different.
## It runs the Mixamo animation on an invisible copy of the Mixamo skeleton, and every frame
## copies how each bone has turned onto the matching bone of the old man.
## Used by enemy.gd for the catch. Everything happens inside the game - no setup needed while playing.

@export_file("*.fbx", "*.glb", "*.gltf") var source_path: String = "res://models/old_man/Angry.fbx"
@export var loop: bool = true
@export var source_yaw_degrees: float = 180.0  ## Turns the Mixamo skeleton to face the same way as the old man

## Old man bone -> Mixamo bone (Mixamo names without the "mixamorig:" part).
const BONE_MAP := {
	"Hips": "Hips", "Spine": "Spine", "Spine 1": "Spine1", "Chest": "Spine2",
	"Neck": "Neck", "Head": "Head",
	"Shoulder_L": "LeftShoulder", "Upper_Arm_L": "LeftArm", "Lower_Arm_L": "LeftForeArm", "hand_L": "LeftHand",
	"Shoulder_R": "RightShoulder", "Upper_Arm_R": "RightArm", "Lower_Arm_R": "RightForeArm", "hand_R": "RightHand",
	"Upper_Leg_L": "LeftUpLeg", "Lower_Leg_L": "LeftLeg", "Foot_L": "LeftFoot", "Toes_L": "LeftToeBase",
	"Upper_Leg_R": "RightUpLeg", "Lower_Leg_R": "RightLeg", "Foot_R": "RightFoot", "Toes_R": "RightToeBase",
	"Thumb_L": "LeftHandThumb1", "Thumb_1_L": "LeftHandThumb2", "Thumb_2_L": "LeftHandThumb3",
	"Index_L": "LeftHandIndex1", "Index_1_L": "LeftHandIndex2", "Index_2_L": "LeftHandIndex3",
	"Middle_L": "LeftHandMiddle1", "Middle_1_L": "LeftHandMiddle2", "Middle_2_L": "LeftHandMiddle3",
	"Ring_L": "LeftHandRing1", "Ring_1_L": "LeftHandRing2", "Ring_2_L": "LeftHandRing3",
	"Pinky_L": "LeftHandPinky1", "Pinky_1_L": "LeftHandPinky2", "Pinky_2_L": "LeftHandPinky3",
	"Thumb_R": "RightHandThumb1", "Thumb_1_R": "RightHandThumb2", "Thumb_2_R": "RightHandThumb3",
	"Index_R": "RightHandIndex1", "Index_1_R": "RightHandIndex2", "Index_2_R": "RightHandIndex3",
	"Middle_R": "RightHandMiddle1", "Middle_1_R": "RightHandMiddle2", "Middle_2_R": "RightHandMiddle3",
	"Ring_R": "RightHandRing1", "Ring_1_R": "RightHandRing2", "Ring_2_R": "RightHandRing3",
	"Pinky_R": "RightHandPinky1", "Pinky_1_R": "RightHandPinky2", "Pinky_2_R": "RightHandPinky3",
}

var playing: bool = false
var _target: Skeleton3D
var _source: Skeleton3D
var _source_anim: AnimationPlayer
var _anim_name: StringName
var _pairs: Array = []            # [target_bone, source_bone, source_rest_world, target_rest_world]
var _target_world_rest: Array[Quaternion] = []


## Call once with the old man's skeleton. Returns false if the animation couldn't be loaded.
func setup(target: Skeleton3D) -> bool:
	_target = target
	if not ResourceLoader.exists(source_path):
		push_warning("Caught animation: file not found: " + source_path)
		return false
	var scene := load(source_path) as PackedScene
	if scene == null:
		return false
	var root := scene.instantiate() as Node3D
	add_child(root)
	root.visible = false  # only its skeleton is used
	root.rotation.y = deg_to_rad(source_yaw_degrees)

	for node in root.find_children("*", "Skeleton3D", true, false):
		_source = node
		break
	for node in root.find_children("*", "AnimationPlayer", true, false):
		_source_anim = node
		break
	if _source == null or _source_anim == null:
		push_warning("Caught animation: no skeleton or animation inside " + source_path)
		return false
	for anim_name in _source_anim.get_animation_list():
		if anim_name != &"RESET":
			_anim_name = anim_name
			break
	if _anim_name == &"":
		return false
	_source_anim.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if loop:
		_source_anim.get_animation(_anim_name).loop_mode = Animation.LOOP_LINEAR

	# Pair up bones by name (ignoring the "mixamorig:" / "mixamorig_" prefix).
	var source_index := {}
	for i in _source.get_bone_count():
		source_index[_clean(_source.get_bone_name(i))] = i
	for target_name in BONE_MAP:
		var t := _target.find_bone(target_name)
		var s: int = source_index.get(_clean(BONE_MAP[target_name]), -1)
		if t >= 0 and s >= 0:
			_pairs.append([t, s,
				_world_rot(_source, _source.get_bone_global_rest(s)),
				_world_rot(_target, _target.get_bone_global_rest(t))])
	print("Caught animation '", _anim_name, "' ready: ", _pairs.size(), " bones matched")
	return _pairs.size() > 10


func play() -> void:
	if _source_anim == null:
		return
	_source_anim.play(_anim_name)
	_source_anim.seek(0.0, true)
	playing = true


func stop() -> void:
	playing = false
	if _source_anim:
		_source_anim.stop()


func _process(delta: float) -> void:
	if not playing:
		return
	_source_anim.advance(delta)
	_source.force_update_all_bone_transforms()

	# Desired world rotation for each matched old-man bone:
	#   (how the Mixamo bone turned from its rest pose) applied to the old-man bone's rest pose.
	var desired := {}
	for pair in _pairs:
		var source_now := _world_rot(_source, _source.get_bone_global_pose(pair[1]))
		var turn: Quaternion = source_now * (pair[2] as Quaternion).inverse()
		desired[pair[0]] = turn * (pair[3] as Quaternion)

	# Turn world rotations into each bone's own (local) rotation, parents first.
	var skel_rot := _target.global_basis.get_rotation_quaternion()
	var world := {}
	for i in _target.get_bone_count():
		var parent := _target.get_bone_parent(i)
		var parent_world: Quaternion = world.get(parent, skel_rot) if parent >= 0 else skel_rot
		if parent >= 0 and not world.has(parent):
			parent_world = skel_rot * _target.get_bone_global_pose(parent).basis.get_rotation_quaternion()
		var local: Quaternion
		if desired.has(i):
			local = parent_world.inverse() * (desired[i] as Quaternion)
			_target.set_bone_pose_rotation(i, local)
		else:
			local = _target.get_bone_pose_rotation(i)
		world[i] = parent_world * local


func _world_rot(skeleton: Skeleton3D, bone_global: Transform3D) -> Quaternion:
	return (skeleton.global_basis.get_rotation_quaternion() * bone_global.basis.get_rotation_quaternion()).normalized()


func _clean(bone_name: String) -> String:
	var n := bone_name.to_lower()
	var cut := n.find("mixamorig")
	if cut >= 0:
		n = n.substr(cut + "mixamorig".length())
		while n.length() > 0 and (n[0] == ":" or n[0] == "_" or n[0].is_valid_int()):
			n = n.substr(1)
	return n.replace(" ", "").replace("_", "")
