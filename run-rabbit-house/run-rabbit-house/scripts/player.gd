extends CharacterBody3D

@export var speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var mouse_sensitivity: float = 0.002
@export var crouch_head_offset: float = 0.45

@export var hide_head_offset: float = 0.70

@onready var head: Node3D = $head
@onready var interaction_ray: RayCast3D = $head/RayCast3D
@onready var player_collision: CollisionShape3D = find_child(
	"CollisionShape3D", true, false) as CollisionShape3D
@onready var interaction_label: Label = get_node_or_null("CanvasLayer/InteractionMessage") as Label

@onready var crosshair: Label = get_node_or_null("CanvasLayer/CenterContainer/Crosshair") #as Label

var gravity: float = 9.8
var inventory: Array[String] = []

var nearby_hiding_spot: Node3D = null
var current_hiding_spot: Node3D = null
var is_hiding: bool = false

var standing_head_y: float = 0.0
var interaction_message_id := 0

var interact_waiting_for_release: bool = false
var interaction_cooldown: bool = false

signal inventory_changed


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	standing_head_y = head.position.y

	if interaction_label != null:
		interaction_label.hide()

func _input(event: InputEvent) -> void:
	
	if event is InputEventMouseMotion:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			
			head.rotation.x = clamp(
				head.rotation.x, deg_to_rad(-80), 
				deg_to_rad(80)
			)

# INVENTORY

func add_item(item_id: String) -> bool:
	if inventory.has(item_id):
		print("Already have this item: ", item_id)
		return false

	inventory.append(item_id)

	print("Item added: ", item_id)
	print("Inventory: ", inventory)

	inventory_changed.emit()
	return true


func has_item(item_id: String) -> bool:
	return inventory.has(item_id)


func remove_item(item_id: String) -> bool:
	if not inventory.has(item_id):
		print("Item not found: ", item_id)
		return false

	inventory.erase(item_id)

	print("Item removed: ", item_id)
	print("Inventory: ", inventory)

	inventory_changed.emit()
	return true


func get_inventory() -> Array[String]:
	return inventory


# HIDING

func set_nearby_hiding_spot(spot: Node3D) -> void:
	nearby_hiding_spot = spot
	update_hiding_prompt()


func update_hiding_prompt() -> void:
	if interaction_label == null:
		return

	if is_hiding or nearby_hiding_spot == null:
		return

	if nearby_hiding_spot.needs_crouching():
		if Input.is_action_pressed("crouch"):
			interaction_label.text = "Press E to Hide"
		else:
			interaction_label.text = "Press CTRL to Crouch"
	else:
		interaction_label.text = "Press E to Hide"

	interaction_label.show()


func clear_nearby_hiding_spot(spot: Node3D) -> void:
	if nearby_hiding_spot == spot:
		nearby_hiding_spot = null

		if not is_hiding and interaction_label != null:
			interaction_label.hide()


func enter_hiding() -> void:
	if nearby_hiding_spot == null:
		return

	if nearby_hiding_spot.needs_crouching():
		if not Input.is_action_pressed("crouch"):
			show_interaction_message("You must crouch to hide here!")
			return

	current_hiding_spot = nearby_hiding_spot
	
	# for debugging
	print("selected hiding spot: ", current_hiding_spot.get_path)
	print(" selected marker", current_hiding_spot.get_path)

	print("Player position before hiding: ", global_position)
	print("Hide marker position: ", current_hiding_spot.get_hide_position())

	is_hiding = true
	velocity = Vector3.ZERO

	# move the player to the hiding marker
	global_position = current_hiding_spot.get_hide_position()

	# lower the camera/head while hiding
	if current_hiding_spot.should_crouch_when_hidden():
		head.position.y = standing_head_y - hide_head_offset

	# disable player collision while hiding
	if player_collision != null:
		player_collision.set_deferred("disabled", true)
	else:
		push_error("Player CollisionShape3D was not found")

	if interaction_label != null:
		interaction_label.text = "Press E to Exit"
		interaction_label.show()

	print("HIDE POSITION: ", current_hiding_spot.get_hide_position())
	print("PLAYER POSITION: ", global_position)
	print("You are hiding")


func exit_hiding() -> void:
	if current_hiding_spot == null:
		return

	# move the player outside the hiding spot
	global_position = current_hiding_spot.get_exit_position()
	velocity = Vector3.ZERO

	# restore player collision
	if player_collision != null:
		player_collision.set_deferred("disabled", false)
	else:
		push_error("Player CollisionShape3D was not found")

	# restore normal head height
	head.position.y = standing_head_y

	is_hiding = false
	current_hiding_spot = null
	nearby_hiding_spot = null

	if interaction_label != null:
		interaction_label.hide()

	print("You stopped hiding.")

#find interactive object

func find_interactable(hit_node: Node) -> Node:
	var target: Node = hit_node

	while target != null:

		if target.has_method("interact_with_player") or target.has_method("interact"):
			return target

		target = target.get_parent()

	return null

# input and interactions 

func _unhandled_input(event: InputEvent) -> void:
	
	#esc release the mouse
	if event.is_action_pressed("cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
		get_viewport().set_input_as_handled()
		return

	# detects when e is released
	if event.is_action_released("interact"):
		interact_waiting_for_release = false
		return

	# will only respond to a fresh e press
	if event.is_action_pressed("interact") and not event.is_echo():

		if interact_waiting_for_release or interaction_cooldown:
			return

		interact_waiting_for_release = true
		interaction_cooldown = true

		get_viewport().set_input_as_handled()

		# prevents another interaction immediately afterward.
		release_interaction_cooldown()

		if is_hiding:
			exit_hiding()
			return

		if nearby_hiding_spot != null:
			enter_hiding()
			return

		interact_with_target()


func release_interaction_cooldown() -> void:
	await get_tree().create_timer(0.3).timeout
	interaction_cooldown = false


func interact_with_target() -> void:
	interaction_ray.force_raycast_update()

	if not interaction_ray.is_colliding():
		print("Raycast hit nothing.")
		return

	var hit_node: Node = interaction_ray.get_collider() as Node

	if hit_node == null:
		return

	print("Ray hit: ", hit_node.get_path())

	var target: Node = find_interactable(hit_node)

	if target == null:
		print("No interaction script found.")
		return

	if target.has_method("interact_with_player"):
		print("Player interaction found on: ", target.name)
		target.interact_with_player(self)

	elif target.has_method("interact"):
		print("Existing interaction found on: ", target.name)
		target.interact(hit_node)


# movement

func _physics_process(delta: float) -> void:

	if is_hiding:
		velocity = Vector3.ZERO
		move_and_slide()
		return

	update_hiding_prompt()

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		if velocity.y < 0.0:
			velocity.y = 0.0

	var is_crouching: bool = Input.is_action_pressed("crouch")
	var current_speed: float = speed

	if is_crouching:
		current_speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		current_speed = sprint_speed

	var target_head_y: float = standing_head_y

	if is_crouching:
		target_head_y -= crouch_head_offset

	head.position.y = move_toward(
		head.position.y,
		target_head_y,
		delta * 3.0
	)

	var input_dir := Input.get_vector(
		"move_left",
		"move_right",
		"move_backward",
		"move_forward"
	)

	var direction := (
		transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	).normalized()

	if direction.length() > 0.0:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, current_speed)
		velocity.z = move_toward(velocity.z, 0.0, current_speed)

	move_and_slide()


# on screen interaction message

func show_interaction_message(message: String) -> void:

	if interaction_label == null:
		print("Interaction message: ", message)
		return

	interaction_message_id += 1
	var current_message_id = interaction_message_id

	interaction_label.text = message
	interaction_label.show()

	await get_tree().create_timer(2.0).timeout

	if current_message_id == interaction_message_id:
		interaction_label.hide()
		
func _process(_delta: float) -> void:

	if crosshair == null:
		return

	var can_interact := false

	if interaction_ray.is_colliding():
		var hit_node: Node = interaction_ray.get_collider() as Node

		if hit_node != null:
			#print("RAY HIT: ", hit_node.name)
			#print("HIT POSITION: ", interaction_ray.get_collision_point())

			var target: Node = find_interactable(hit_node)
			can_interact = target != null

	if can_interact:
		crosshair.modulate = Color("e7b72d")
	else:
		crosshair.modulate = Color.WHITE

#temporarily added
	#if interaction_ray.is_colliding():
		#print("Ray collision point: ", interaction_ray.get_collision_point())
		#print("Ray origin: ", interaction_ray.global_position)
