extends StaticBody3D

@export var torch_light_energy: float = 6.0
@export var torch_light_color: Color = Color(1.0, 0.55, 0.18) # Warmer orange

var light: OmniLight3D
var soft_glow_light: OmniLight3D
var flame_anim_time: float = 0.0

func _ready():
	# Get reference to existing OmniLight3D from scene
	light = get_node("OmniLight3D")
	light.light_energy = torch_light_energy
	light.light_color = torch_light_color

	# Add a secondary, softer OmniLight for gentle glow
	soft_glow_light = OmniLight3D.new()
	soft_glow_light.light_energy = torch_light_energy * 0.25
	soft_glow_light.light_color = Color(1.0, 0.7, 0.3, 0.5) # Softer, semi-transparent
	soft_glow_light.omni_range = 12.0 # Use a fixed value for range
	soft_glow_light.shadow_enabled = false
	add_child(soft_glow_light)

func _process(delta):
	# Flicker the light energy more dynamically
	flame_anim_time += delta
	var flicker = 0.45 * sin(flame_anim_time * 10.0 + randf() * 2.0) + 0.15 * sin(flame_anim_time * 23.0)
	light.light_energy = torch_light_energy + flicker
	soft_glow_light.light_energy = (torch_light_energy * 0.25) + (flicker * 0.15)

func _set_torch_light_energy(value):
	torch_light_energy = value
	if light:
		light.light_energy = value
	if soft_glow_light:
		soft_glow_light.light_energy = value * 0.25

func _set_torch_light_color(value):
	torch_light_color = value
	if light:
		light.light_color = value
	if soft_glow_light:
		soft_glow_light.light_color = Color(value.r, value.g, value.b, 0.5)
