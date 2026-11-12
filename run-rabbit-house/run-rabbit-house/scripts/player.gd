extends CharacterBody3D

@export var speed: float = 4.0
@export var mouse_sensitivity: float = 0.002

@onready var interaction_ray: RayCast3D = $head/RayCast3D
@onready var head: Node3D = $head

var gravity: float = 9.8

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(
		head.rotation.x, -1.4, 1.4
		)
	
	if event.is_action_pressed("cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		
	if event is InputEventMouseButton:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			
	if event.is_action_pressed("interact"):
		interaction_ray.force_raycast_update()
		
		if interaction_ray.is_colliding():
			var hit_node: Node = interaction_ray.get_collider() as Node
			print("Ray hit: ", hit_node.get_path())
			
			var target: Node = hit_node
			#searches the detected object and parent nodes
			while target != null:
				print("checking node: ", target.name)
				
				if target.has_method("interact"):
					print("found interact function on: ", target.name)
					target.interact(hit_node)
					return
					
				target = target.get_parent()
			print("no interact func found")
		else:
			print("raycast hit nothing")
	
	
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	var input_dir := Input.get_vector(
		"move_left", 
		"move_right",
		"move_backward",
		"move_forward"
	)
	
	var direction := (
		transform.basis * Vector3(input_dir.x, 0, input_dir.y)
	).normalized()
		
		
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed)
		velocity.z = move_toward(velocity.z, 0.0, speed)
		
	move_and_slide()
		
		
