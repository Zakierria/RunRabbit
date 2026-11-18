extends Control

@export_file("*.tscn") var game_scene: String
@export_file("*.tscn") var main_menu_scene: String

@onready var play_again_button: Button = $CenterContainer/VBoxContainer/PlayAgainButton
@onready var main_menu_button: Button = $CenterContainer/VBoxContainer/MainMenuButton
@onready var quit_button: Button = $CenterContainer/VBoxContainer/QuitButton

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	play_again_button.pressed.connect(_on_play_again)
	main_menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)

func _on_play_again() -> void:
	if not game_scene.is_empty():
		get_tree().change_scene_to_file(game_scene)

func _on_main_menu() -> void:
	if not main_menu_scene.is_empty():
		get_tree().change_scene_to_file(main_menu_scene)

func _on_quit() -> void:
	get_tree().quit()
