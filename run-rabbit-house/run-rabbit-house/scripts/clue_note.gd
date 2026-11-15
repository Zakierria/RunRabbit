extends StaticBody3D

@export_multiline var clue_text: String = "I've tried to leave this house.\n\nEvery door leads me back.\n\nHe hides the truth inside a rusted box.\n\nI found the key once.\n\nHe made sure I forgot where.\n\nHe's watching.\n REMEMBER\n\nFour walls, One door, Three knocks.\n"

@onready var note_ui: CanvasLayer = $NoteUI
@onready var title_label: Label = $NoteUI/PanelContainer/VBoxContainer/TitleLabel
@onready var clue_label: Label = $NoteUI/PanelContainer/VBoxContainer/ClueLabel
@onready var close_button: Button = $NoteUI/PanelContainer/VBoxContainer/CloseButton
@onready var panel: PanelContainer = $NoteUI/PanelContainer

var player_reference: Node3D = null
var note_open: bool = false


func _ready() -> void:
	note_ui.hide()
	close_button.pressed.connect(close_note)

	title_label.text = "PLEASE READ"

	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size = Vector2(350, 0)
	clue_label.text = clue_text

	var paper_style: StyleBoxFlat = StyleBoxFlat.new()
	paper_style.bg_color = Color("#B6A17B")
	paper_style.border_color = Color("#493A2C")
	paper_style.set_border_width_all(5)
	paper_style.set_content_margin_all(24)

	panel.add_theme_stylebox_override("panel", paper_style)

	title_label.add_theme_color_override(
		"font_color", Color("#38271D")
	)
	title_label.add_theme_font_size_override(
		"font_size", 28
	)

	clue_label.add_theme_color_override(
		"font_color", Color("#38271D")
	)
	clue_label.add_theme_font_size_override(
		"font_size", 21
	)

	close_button.text = "Put Note Away"


# Connects to your existing player interaction system.
func interact_with_player(player: Node3D) -> void:

	if note_open:
		return

	player_reference = player
	note_open = true

	clue_label.text = clue_text
	note_ui.show()

	if is_instance_valid(player_reference):
		player_reference.set_physics_process(false)
		player_reference.set_process_unhandled_input(false)

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	close_button.grab_focus()

	print("Clue note opened.")


func close_note() -> void:

	if not note_open:
		return

	note_open = false
	note_ui.hide()

	if is_instance_valid(player_reference):
		player_reference.set_physics_process(true)
		player_reference.set_process_unhandled_input(true)

	player_reference = null

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	print("Clue note closed.")
