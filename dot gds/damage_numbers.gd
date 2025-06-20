# damage_numbers.gd - CRASH FIXED VERSION
extends Node

@export var damage_font_size = 24
@export var float_height = 1.5
@export var fade_duration = 1.0
@export var combine_window := 0.5

const DAMAGE_COLORS = {
	"normal": Color.WHITE,
	"high": Color.YELLOW,
	"critical": Color.ORANGE,
	"massive": Color.RED,
	"heal": Color.GREEN
}

var floating_labels: Dictionary = {}
var label_last_position: Dictionary = {}
var label_timers: Dictionary = {}
var label_fading: Dictionary = {}

# 🔧 FIX: Safer scene and camera references
var current_scene: Node
var camera: Camera3D

func _ready():
	add_to_group("damage_numbers")
	_update_scene_references()
	
	# 🔧 FIX: Listen for scene changes to update references
	if get_tree():
		get_tree().current_scene_changed.connect(_on_scene_changed)

# 🔧 FIX: Update references when scene changes
func _update_scene_references():
	current_scene = get_tree().current_scene if get_tree() else null
	camera = get_viewport().get_camera_3d() if get_viewport() else null

# 🔧 FIX: Handle scene changes
func _on_scene_changed():
	print("🔄 DamageNumbers: Scene changed, updating references")
	_clear_all_labels()
	_update_scene_references()

# 🔧 FIX: Clear all labels safely
func _clear_all_labels():
	for entity in floating_labels.keys():
		var label = floating_labels[entity]
		if is_instance_valid(label):
			label.queue_free()
	floating_labels.clear()
	label_last_position.clear()
	label_timers.clear()
	label_fading.clear()

func _process(_delta):
	var now = Time.get_ticks_msec() / 1000.0
	for entity in floating_labels.keys().duplicate():
		var label = floating_labels[entity] as Label
		if is_instance_valid(entity):
			_update_label_position(label, entity)
			label_last_position[entity] = entity.global_position
		elif is_instance_valid(label):
			if entity in label_last_position:
				var world_pos = label_last_position[entity] + Vector3(0, float_height, 0)
				var screen_pos = _world_to_screen(world_pos)
				if screen_pos != Vector2(-1, -1):
					label.position = screen_pos - (label.size / 2)
					label.visible = true
				else:
					label.visible = false
		else:
			_clear_entity_data(entity)
			continue

		if entity in label_timers and is_instance_valid(label):
			var time_since_last = now - label_timers[entity]
			if not label_fading.get(entity, false) and time_since_last > combine_window:
				label_fading[entity] = true
				_start_fade(label, entity)

func show_damage(damage_amount: int, entity: Node3D, damage_type: String = "normal"):
	_create_or_update_label(entity, str(damage_amount), damage_type)

func show_heal(heal_amount: int, entity: Node3D):
	_create_or_update_label(entity, "+" + str(heal_amount), "heal")

func _create_or_update_label(entity: Node3D, text: String, damage_type: String):
	# 🔧 FIX: Check if scene is valid before proceeding
	if not is_instance_valid(current_scene):
		print("⚠️ DamageNumbers: No valid scene to add labels to")
		_update_scene_references()
		if not is_instance_valid(current_scene):
			return

	var label: Label
	var now = Time.get_ticks_msec() / 1000.0

	if entity in floating_labels:
		label = floating_labels[entity] as Label
		if is_instance_valid(label):
			_update_existing_label(label, text)
			label_timers[entity] = now
			label_fading[entity] = false
			label.modulate.a = 1.0
			return
		else:
			_clear_entity_data(entity)

	label = _create_label(text, damage_type)
	floating_labels[entity] = label
	
	# 🔧 FIX: Safely add child with error handling
	if is_instance_valid(current_scene):
		current_scene.add_child(label)
	else:
		print("⚠️ DamageNumbers: Cannot add label - scene is invalid")
		label.queue_free()
		return
	
	_update_label_position(label, entity)
	label_last_position[entity] = entity.global_position
	label_timers[entity] = now
	label_fading[entity] = false

func _create_label(text: String, damage_type: String) -> Label:
	var label = Label.new()
	label.text = text
	label.size = Vector2(120, 40)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.z_index = 100
	
	label.add_theme_font_size_override("font_size", damage_font_size)
	label.add_theme_color_override("font_color", DAMAGE_COLORS.get(damage_type, DAMAGE_COLORS["normal"]))
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	
	return label

func _update_existing_label(label: Label, new_text: String):
	if is_instance_valid(label):
		var current_value = label.text.to_int()
		var new_value = new_text.to_int() 
		var combined_value = current_value + new_value
		label.text = str(combined_value)

func _update_label_position(label: Label, entity: Node3D):
	if not is_instance_valid(label) or not is_instance_valid(entity):
		return
	
	var world_pos = entity.global_position + Vector3(0, float_height, 0)
	var screen_pos = _world_to_screen(world_pos)
	
	if screen_pos != Vector2(-1, -1):
		label.position = screen_pos - (label.size / 2)
		label.visible = true
	else:
		label.visible = false

func _world_to_screen(world_pos: Vector3) -> Vector2:
	if not is_instance_valid(camera):
		camera = get_viewport().get_camera_3d() if get_viewport() else null
		if not is_instance_valid(camera):
			return Vector2(-1, -1)
	
	var screen_pos = camera.unproject_position(world_pos)
	var viewport_size = get_viewport().get_visible_rect().size
	
	if screen_pos.x < 0 or screen_pos.x > viewport_size.x or screen_pos.y < 0 or screen_pos.y > viewport_size.y:
		return Vector2(-1, -1)
	
	return screen_pos

func _start_fade(label: Label, entity: Node3D):
	if not is_instance_valid(label):
		return
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "modulate:a", 0.0, fade_duration)
	tween.tween_property(label, "position:y", label.position.y - 50, fade_duration)
	tween.tween_callback(_remove_label.bind(entity)).set_delay(fade_duration)

func _remove_label(entity: Node3D):
	_clear_entity_data(entity)

func _clear_entity_data(entity: Node3D):
	if entity in floating_labels:
		var label = floating_labels[entity]
		if is_instance_valid(label):
			label.queue_free()
		floating_labels.erase(entity)
	
	label_last_position.erase(entity)
	label_timers.erase(entity)
	label_fading.erase(entity)