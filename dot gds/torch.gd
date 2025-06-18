extends StaticBody3D

@export var torch_light_energy: float = 2.0
@export var torch_light_color: Color = Color(1.0, 0.7, 0.3)

var flame: Node3D
var light: OmniLight3D
var flame_anim_time: float = 0.0

func _ready():
	# Create and configure the OmniLight3D
	light = OmniLight3D.new()
	light.light_energy = torch_light_energy
	light.light_color = torch_light_color
	light.range = 8.0
	add_child(light)

	# Create a simple flame visual (e.g., a small MeshInstance3D or Sprite3D)
	flame = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.1
	flame.mesh = mesh
	flame.material_override = StandardMaterial3D.new()
	flame.material_override.albedo_color = torch_light_color
	flame.translation = Vector3(0, 0.5, 0)
	add_child(flame)

func _process(delta):
	# Animate the flame with a simple sin/cos movement
	flame_anim_time += delta
	var offset = Vector3(
		0.05 * sin(flame_anim_time * 3.0),
		0.05 * abs(sin(flame_anim_time * 2.0)),
		0.05 * cos(flame_anim_time * 2.5)
	)
	flame.translation = Vector3(0, 0.5, 0) + offset

	# Flicker the light energy slightly
	light.light_energy = torch_light_energy + 0.2 * sin(flame_anim_time * 8.0)

func _set_torch_light_energy(value):
	torch_light_energy = value
	if light:
		light.light_energy = value

func _set_torch_light_color(value):
	torch_light_color = value
	if light:
		light.light_color = value
	if flame:
		flame.material_override.albedo_color = value
