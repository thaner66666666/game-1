extends StaticBody3D

@export var torch_light_energy: float = 2.0
@export var torch_light_color: Color = Color(1.0, 0.7, 0.3)

var light: OmniLight3D
var flame_anim_time: float = 0.0

func _ready():
	# Get reference to existing OmniLight3D from scene
	light = get_node("OmniLight3D")
	light.light_energy = torch_light_energy
	light.light_color = torch_light_color

func _process(delta):
	# Flicker the light energy slightly
	flame_anim_time += delta
	light.light_energy = torch_light_energy + 0.2 * sin(flame_anim_time * 8.0)

func _set_torch_light_energy(value):
	torch_light_energy = value
	if light:
		light.light_energy = value

func _set_torch_light_color(value):
	torch_light_color = value
	if light:
		light.light_color = value
