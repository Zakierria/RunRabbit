extends StaticBody3D

@export var correct_code: String = "413"

var is_unlocked: bool = false
var player_reference: Node3D = null
var puzzle_open: bool = false

@onready var puzzle_ui: CanvasLayer = $PuzzleUI
@onready var code_input: LineEdit = $PuzzleUI/PanelContainer/VBoxContainer/CodeInput
@onready var result_label: Label = $PuzzleUI/PanelContainer/VBoxContainer/ResultLabel
@onready var unlock_button: Button = $PuzzleUI/PanelContainer/VBoxContainer/UnlockButton
@onready var close_button: Button = $PuzzleUI/PanelContainer/VBoxContainer/CloseButton

@onready var hidden_key: StaticBody3D = $HiddenKey
@onready var box_mesh: MeshInstance3D = $MeshInstance3D
@onready var box_collision: CollisionShape3D = $CollisionShape3D


func _ready() -> void:

	puzzle_ui.hide()

	# Hide the key until the correct code is entered.
	hidden_key.hide()
	hidden_key.process_mode = Node.PROCESS_MODE_DISABLED

	set_key_collision(false)

	unlock_button.pressed.connect(check_code)
	close_button.pressed.connect(close_puzzle)
	code_input.text_submitted.connect(_on_code_submitted)

	code_input.max_length = 3
	code_input.placeholder_text = "Enter combination"


# makes sure it is compatible with player script
func interact_with_player(player: Node3D) -> void:

	if is_unlocked or puzzle_open:
		return

	player_reference = player
	puzzle_open = true

	result_label.text = ""
	code_input.text = ""

	puzzle_ui.show()

	if is_instance_valid(player_reference):
		player_reference.set_physics_process(false)
		player_reference.set_process_unhandled_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	code_input.grab_focus()

	print("Combination box opened.")


func _on_code_submitted(_text: String) -> void:
	check_code()


func check_code() -> void:

	if not puzzle_open:
		return

	var entered_code: String = code_input.text.strip_edges()

	if entered_code == correct_code:

		is_unlocked = true

		print("Combination box unlocked!")
		result_label.text = "Unlocked!"

		reveal_key()
		close_puzzle()

	else:

		result_label.text = "Incorrect code. Try again."
		code_input.grab_focus()

		print("Incorrect combination entered.")


func reveal_key() -> void:

	box_mesh.hide()
	box_collision.set_deferred("disabled", true)

	hidden_key.show()
	hidden_key.process_mode = Node.PROCESS_MODE_INHERIT

	set_key_collision(true)

	print("A key was revealed inside the box!")


# disable or enable the key's collision shapes.
func set_key_collision(enabled: bool) -> void:

	var collision_nodes = hidden_key.find_children(
		"*",
		"CollisionShape3D",
		true,
		false
	)

	for collision in collision_nodes:
		collision.set_deferred("disabled", not enabled)


func close_puzzle() -> void:

	puzzle_open = false
	puzzle_ui.hide()

	if is_instance_valid(player_reference):
		player_reference.set_physics_process(true)
		player_reference.set_process_unhandled_input(true)

	player_reference = null

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	print("Combination box closed.")
