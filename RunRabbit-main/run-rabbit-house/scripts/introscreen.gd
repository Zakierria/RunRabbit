extends Control

@onready var start_button = $Background/MainContainer/StartButton
@onready var quit_button = $Background/MainContainer/QuitButton

func _ready():
	start_button.pressed.connect(_on_start_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	
func _on_start_pressed():
	get_tree().change_scene_to_file("res://scenes/house_test.tscn")
	
func _on_quit_pressed():
	get_tree().quit()
