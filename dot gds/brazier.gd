# brazier.gd
extends StaticBody3D

@export var brazier_light_energy: float = 3.5
@export var brazier_light_color: Color = Color(1.0, 0.4, 0.1)  # Orange-red flame
@export var flicker_intensity: float = 0.8
@export var flicker_speed: float = 6.0

var light: OmniLight3D
var flame_anim_time: float = 0.0

func _ready():
	light = get_node("OmniLight3D")
	light.light_energy = brazier_light_energy
	light.light_color = brazier_light_color
	light.omni_range = 12.0  # Larger range than torch

func _process(delta):
	# Stronger flicker than torch
	flame_anim_time += delta
	var flicker = flicker_intensity * sin(flame_anim_time * flicker_speed) * 0.3
	light.light_energy = brazier_light_energy + flicker
	
	# Add color variation
	var color_flicker = 0.1 * sin(flame_anim_time * flicker_speed * 1.3)
	light.light_color = brazier_light_color + Color(color_flicker, 0, 0)
