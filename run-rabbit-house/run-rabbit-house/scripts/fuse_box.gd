extends StaticBody3D

@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_activated: bool = false
var is_animating: bool = false



func _ready() -> void:
	var house_lights = get_tree().get_nodes_in_group("house_lights")
	
	for light in house_lights:
		if light is Light3D:
			
			# keep lights on and dimmed
			light.visible = true
			light.light_energy = 0.35
			
			# giving lights a color before power
			light.light_color = Color("715229ff")
			
			#light.visible = false
			
#'_'player -> tell godot that its intentially unused 
func interact_with_player(_player: CharacterBody3D) -> void:
	
	#prevents player from pulling lever again
	if is_activated or is_animating:
		print("Whew the power is on.")
		return
		
	print("Fuse box activated")
	
	is_animating = true
	is_activated = true
	
	#plays lever animation
	animation_player.play("lever_pull")
	await animation_player.animation_finished
	
	# turn on house lights 
	turn_on_house_lights() 
	
	is_animating = false
	
func turn_on_house_lights() -> void:
	
	var house_lights = get_tree().get_nodes_in_group("house_lights")
	
	for light in house_lights:
		if light is Light3D:
			
			#gradually brightens
			var tween = create_tween()
			
			tween.tween_property(
				light, "light_energy",
				1.4, 1.5
			)
			
			#light gradually gets bright
			tween.parallel().tween_property(
				light, "light_color",
				Color("956f3aff"), 1.5
			)
			#light.visible = true
			
	print("House power restored")
	
