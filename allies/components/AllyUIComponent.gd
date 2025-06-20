extends Node3D
class_name AllyUIComponent

# References
var ally_ref: Node3D
var health_component: Node
var name_label: Label3D
var health_bar_background: MeshInstance3D
var health_bar_fill: MeshInstance3D
var health_text_label: Label3D

# Configuration
@export var ui_height_offset: float = 2.5
@export var name_height_offset: float = 2.8
@export var health_bar_width: float = 1.0
@export var health_bar_height: float = 0.1
@export var always_face_camera: bool = true

# Health bar colors
var health_color_full = Color.GREEN
var health_color_medium = Color.YELLOW
var health_color_low = Color.RED

func _ready():
	# Set up the UI components
	_create_name_label()
	_create_health_bar()
	_create_health_text()

func setup_for_ally(ally: Node3D):
	"""Initialize this UI component for a specific ally"""
	ally_ref = ally
	# Find the health component (try multiple possible node names)
	health_component = ally.get_node_or_null("AllyHealth")
	if not health_component:
		health_component = ally.get_node_or_null("HealthComponent")
	if not health_component:
		health_component = ally.get_node_or_null("health_component")
	if not health_component:
		health_component = ally.get_node_or_null("ally_health")
	if health_component:
		# Connect to health changes
		if health_component.has_signal("health_changed"):
			health_component.health_changed.connect(_on_health_changed)
	# Set the ally's name
	_update_name_display()
	_update_health_display()

func _create_name_label():
	"""Create the 3D label for the ally's name"""
	name_label = Label3D.new()
	# Position label above and slightly in front of the ally
	name_label.position = Vector3(0, name_height_offset, 0.25)
	name_label.font_size = 32
	name_label.outline_size = 2
	name_label.outline_modulate = Color.BLACK
	name_label.modulate = Color(1, 1, 0.95, 1) # Bright yellowish
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(name_label)

func _create_health_bar():
	"""Create a 3D health bar using mesh instances"""
	# Background bar
	health_bar_background = MeshInstance3D.new()
	var bg_mesh = BoxMesh.new()
	bg_mesh.size = Vector3(health_bar_width, health_bar_height, 0.02)
	health_bar_background.mesh = bg_mesh
	
	var bg_material = StandardMaterial3D.new()
	bg_material.albedo_color = Color(0.2, 0.2, 0.2, 0.8)
	bg_material.flags_unshaded = true
	bg_material.no_depth_test = true
	health_bar_background.material_override = bg_material
	
	health_bar_background.position = Vector3(0, ui_height_offset, 0)
	add_child(health_bar_background)
	
	# Fill bar (health)
	health_bar_fill = MeshInstance3D.new()
	var fill_mesh = BoxMesh.new()
	fill_mesh.size = Vector3(health_bar_width, health_bar_height, 0.01)
	health_bar_fill.mesh = fill_mesh
	
	var fill_material = StandardMaterial3D.new()
	fill_material.albedo_color = health_color_full
	fill_material.flags_unshaded = true
	fill_material.no_depth_test = true
	health_bar_fill.material_override = fill_material
	
	health_bar_fill.position = Vector3(0, ui_height_offset, 0.01)
	add_child(health_bar_fill)

func _create_health_text():
	"""Create text showing current/max health"""
	health_text_label = Label3D.new()
	health_text_label.position = Vector3(0, ui_height_offset - 0.3, 0)
	health_text_label.font_size = 16
	health_text_label.outline_size = 1
	health_text_label.outline_modulate = Color.BLACK
	health_text_label.modulate = Color.WHITE
	health_text_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(health_text_label)

func _update_name_display():
	"""Update the displayed name and ensure label is visible and billboarded"""
	if not name_label or not ally_ref:
		return
	var display_name = ""
	if ally_ref.has_meta("display_name"):
		display_name = str(ally_ref.get_meta("display_name"))
	elif ally_ref.has_method("get_name") and ally_ref.name:
		display_name = str(ally_ref.name)
	else:
		display_name = "Unnamed Ally"
	name_label.text = display_name
	# Debug info
	print("[AllyUIComponent] Display name set to:", display_name)
	print("[AllyUIComponent] name_label position:", name_label.position)
	print("[AllyUIComponent] name_label billboard:", name_label.billboard)
	print("[AllyUIComponent] name_label modulate:", name_label.modulate)
	if not name_label.visible:
		print("[AllyUIComponent] WARNING: name_label is not visible!")

func _update_health_display():
	"""Update health bar and text"""
	if not health_component or not ally_ref:
		return
	var current_health = 0
	var max_health = 100
	# Get health values
	if health_component.has_method("get_health"):
		current_health = health_component.get_health()
		max_health = health_component.get_max_health()
	elif "current_health" in health_component and "max_health" in health_component:
		current_health = health_component.current_health
		max_health = health_component.max_health
	# Update health bar fill
	if health_bar_fill and max_health > 0:
		var health_percentage = float(current_health) / float(max_health)
		health_percentage = clamp(health_percentage, 0.0, 1.0)
		# Scale the health bar
		var bar_scale = health_bar_fill.scale
		bar_scale.x = health_percentage
		health_bar_fill.scale = bar_scale
		# Adjust position so it shrinks from the right
		var offset = (1.0 - health_percentage) * health_bar_width * 0.5
		health_bar_fill.position.x = -offset
		# Update color based on health percentage
		var color = _get_health_color(health_percentage)
		if health_bar_fill.material_override:
			health_bar_fill.material_override.albedo_color = color
	# Update health text
	if health_text_label:
		health_text_label.text = "%d/%d" % [current_health, max_health]

func _get_health_color(health_percentage: float) -> Color:
	"""Get color based on health percentage"""
	if health_percentage > 0.6:
		return health_color_full
	elif health_percentage > 0.3:
		return health_color_medium
	else:
		return health_color_low

func _on_health_changed(_current: int, _maximum: int):
	"""Called when ally's health changes"""
	_update_health_display()

func _process(_delta):
	"""Update UI every frame"""
	if always_face_camera:
		_face_camera()

func _face_camera():
	"""Make UI elements face the camera"""
	var camera = get_viewport().get_camera_3d()
	if camera:
		# Make the entire UI component face the camera
		look_at(camera.global_position, Vector3.UP)
		# Rotate 180 degrees so text isn't backwards
		rotation_degrees.y += 180

# Clean up when ally is removed
func _exit_tree():
	if health_component and health_component.has_signal("health_changed"):
		if health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.disconnect(_on_health_changed)
